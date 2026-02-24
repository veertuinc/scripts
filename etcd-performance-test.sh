#!/usr/bin/env bash

set -euo pipefail

CONTAINER_NAME="${CONTAINER_NAME:-etcd-fio-test}"
ETCD_IMAGE="${ETCD_IMAGE:-quay.io/coreos/etcd:v3.5.16}"
HOST_DATA_DIR="${HOST_DATA_DIR:-/tmp/etcd}"
FIO_RUNTIME_SECONDS="${FIO_RUNTIME_SECONDS:-60}"
FIO_SIZE="${FIO_SIZE:-1g}"
FIO_P99_MAX_MS="${FIO_P99_MAX_MS:-10}"
KEEP_CONTAINER_AFTER_TEST="${KEEP_CONTAINER_AFTER_TEST:-false}"

SCRIPT_NAME="$(basename "$0")"

usage() {
	cat <<EOF
Usage: $SCRIPT_NAME [options]

Starts an etcd Docker container, waits for health, and runs:
  fio --name=etcd-fsync --directory=/tmp/etcd \\
    --ioengine=sync --rw=write --bs=4k --size=1g --numjobs=1 \\
    --fdatasync=1 --runtime=60 --time_based=1 --group_reporting

Options:
  --host-data-dir PATH         Host path mounted to /tmp/etcd (default: $HOST_DATA_DIR)
  --container-name NAME        Docker container name (default: $CONTAINER_NAME)
  --etcd-image IMAGE           etcd image (default: $ETCD_IMAGE)
  --runtime-seconds N          fio runtime seconds (default: $FIO_RUNTIME_SECONDS)
  --size SIZE                  fio test size (default: $FIO_SIZE)
  --p99-max-ms MS              max p99 latency in ms to pass (default: $FIO_P99_MAX_MS)
  --keep-container             Keep etcd container after test
  -h, --help                   Show this help

Environment variables can also override defaults:
  CONTAINER_NAME, ETCD_IMAGE, HOST_DATA_DIR, FIO_RUNTIME_SECONDS, FIO_SIZE,
  FIO_P99_MAX_MS, KEEP_CONTAINER_AFTER_TEST
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--host-data-dir)
			HOST_DATA_DIR="$2"
			shift 2
			;;
		--container-name)
			CONTAINER_NAME="$2"
			shift 2
			;;
		--etcd-image)
			ETCD_IMAGE="$2"
			shift 2
			;;
		--runtime-seconds)
			FIO_RUNTIME_SECONDS="$2"
			shift 2
			;;
		--size)
			FIO_SIZE="$2"
			shift 2
			;;
		--p99-max-ms)
			FIO_P99_MAX_MS="$2"
			shift 2
			;;
		--keep-container)
			KEEP_CONTAINER_AFTER_TEST="true"
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown option: $1"
			usage
			exit 1
			;;
	esac
done

need_cmd() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Error: missing required command '$1'"
		exit 1
	fi
}

run() {
	echo "> $*" >&2
	"$@"
}

need_cmd docker
need_cmd fio

run mkdir -p "$HOST_DATA_DIR"

FIO_OUTPUT="$(mktemp)"

cleanup() {
	rm -f "$FIO_OUTPUT"
	if [[ "$KEEP_CONTAINER_AFTER_TEST" != "true" ]]; then
		docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
	fi
}
trap cleanup EXIT

# Ensure no stale container blocks startup.
run docker rm -f "$CONTAINER_NAME" 2>/dev/null || true

echo "Starting etcd container '$CONTAINER_NAME' with data dir '$HOST_DATA_DIR'..."
if ! run docker run -d \
	--name "$CONTAINER_NAME" \
	-v "${HOST_DATA_DIR}:/var/lib/etcd" \
	"$ETCD_IMAGE" \
	/usr/local/bin/etcd \
	--name "etcd-1" \
	--data-dir "${HOST_DATA_DIR}" \
	--listen-client-urls "http://0.0.0.0:2379" \
	--advertise-client-urls "http://127.0.0.1:2379" \
	--listen-peer-urls "http://0.0.0.0:2380" \
	--initial-advertise-peer-urls "http://127.0.0.1:2380" \
	--initial-cluster "etcd-1=http://127.0.0.1:2380" \
	--initial-cluster-state "new" \
	--initial-cluster-token "etcd-fio-test-token" 2>&1; then
	echo "Error: Failed to start etcd container."
	exit 1
fi

echo "Waiting for etcd to become healthy (may take a few minutes)..."
for _ in {1..50}; do
	if docker exec "$CONTAINER_NAME" /usr/local/bin/etcdctl --endpoints=http://127.0.0.1:2379 endpoint health 2>&1 | grep -q "is healthy"; then
		echo "etcd is healthy."
		break
	fi
	sleep 2
done

if ! docker exec "$CONTAINER_NAME" /usr/local/bin/etcdctl --endpoints=http://127.0.0.1:2379 endpoint health 2>&1; then
	echo "Error: etcd did not become healthy in time."
	run docker logs "$CONTAINER_NAME" || true
	exit 1
fi

echo "Running fio latency test on $HOST_DATA_DIR..."
run fio --name=etcd-fsync \
	--directory="$HOST_DATA_DIR" \
	--ioengine=sync \
	--rw=write \
	--bs=4k \
	--size="$FIO_SIZE" \
	--numjobs=1 \
	--fdatasync=1 \
	--runtime="$FIO_RUNTIME_SECONDS" \
	--time_based=1 \
	--group_reporting \
	--output-format=normal,json 2>&1 | tee "$FIO_OUTPUT"

# Extract JSON (fio may output JSON first or after normal; get first complete JSON block)
FIO_JSON="$(awk '/^\{/,/^\}$/' "$FIO_OUTPUT")"
if [[ -z "$FIO_JSON" || "${#FIO_JSON}" -lt 100 ]]; then
	FIO_JSON="$(awk '/^\{/,0' "$FIO_OUTPUT")"
fi

P99_NS="$(echo "$FIO_JSON" | jq -r '
	.jobs[0].write.clat_ns.percentile["99.000000"] // .jobs[0].write.clat_ns.percentile["99.0"] // .jobs[0].write.clat_ns.percentile["99"] //
	.jobs[0].sync.clat_ns.percentile["99.000000"] // empty
' 2>/dev/null)" || P99_NS=""

# Fallback: parse from human-readable output (clat percentiles in nsec or usec)
if [[ -z "$P99_NS" || "$P99_NS" == "null" ]]; then
	P99_LINE="$(grep -o '99\.00th=\[[^]]*\]' "$FIO_OUTPUT" | head -1)"
	P99_VAL="$(echo "$P99_LINE" | grep -oE '[0-9]+')"
	CLAT_UNIT="$(grep -o 'clat percentiles (nsec)\|clat percentiles (usec)' "$FIO_OUTPUT" | head -1)"
	if [[ -n "$P99_VAL" && -n "$CLAT_UNIT" ]]; then
		if [[ "$CLAT_UNIT" == *"nsec"* ]]; then
			P99_NS="$P99_VAL"
		else
			P99_NS="$((P99_VAL * 1000))"
		fi
	fi
fi

if [[ -z "$P99_NS" ]]; then
	echo "Error: could not parse p99 from fio output"
	exit 1
fi

P99_MS="$((P99_NS / 1000000))"
echo ""
echo "--- Latency check (p99 threshold: ${FIO_P99_MAX_MS}ms) ---"
echo "p99 completion latency: ${P99_MS}ms"

if [[ "$P99_MS" -le "$FIO_P99_MAX_MS" ]]; then
	echo "PASS: p99 ${P99_MS}ms <= ${FIO_P99_MAX_MS}ms"
else
	echo "FAIL: p99 ${P99_MS}ms > ${FIO_P99_MAX_MS}ms (risky for etcd)"
	exit 1
fi

if [[ "$KEEP_CONTAINER_AFTER_TEST" == "true" ]]; then
	echo "Container kept running: $CONTAINER_NAME"
fi
