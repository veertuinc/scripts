# Various scripts for supporting customers


---
## collect-vm-template-files-and-folders.bash

```
❯ oldIFS=$IFS; IFS=$'\n'; for i in $(./collect-vm-template-files-and-folders.bash 10.15.7-xcode11.7-webkit); do echo "test: $i"; done; IFS=$oldIFS 
test: /Users/nathanpierce/Library/Application Support/Veertu/Anka/img_lib/746be7a6103e4f9481f3f9a99756d6fd.ank
test: /Users/nathanpierce/Library/Application Support/Veertu/Anka/img_lib/901212c557b94d9db79e510aaeb3c21c.ank
test: /Users/nathanpierce/Library/Application Support/Veertu/Anka/vm_lib/b1b9d901-2b87-410f-99bf-82411416d0b2
```

Transfer all files and folders with rsync:

```
set -x
REMOTE_USERNAME="administrator"
REMOTE_IP="XXX.XXX.XXX.XXX"
REMOTE_SSH_PRIV_KEY="/Users/administrator/.ssh/perf-test"
COLLECT_RESULTS="$(./collect-vm-template-files-and-folders.bash 11.1.0-xcode12.3-webkit)"
pushd "$(anka config vm_lib_dir)/.." && BASE_PATH=$(pwd)
oldIFS=$IFS;
IFS=$'\n';
for COLLECT_PATH in ${COLLECT_RESULTS[@]}; do
FULL_PATH=$COLLECT_PATH
path=$(echo $COLLECT_PATH | sed "s/$(echo $BASE_PATH | sed 's/\//\\\//g')\///g")
rsyncOpts=""
dest=${FULL_PATH// /\\ }
if [[ -d "$COLLECT_PATH" ]]; then 
	rsyncOpts="--recursive"
	dest="$(echo ${FULL_PATH// /\\ } | rev | cut -d/ -f2-99 | rev)"
fi
ssh -o StrictHostKeyChecking=no -i "$REMOTE_SSH_PRIV_KEY" ${REMOTE_USERNAME}@${REMOTE_IP} "mkdir -p $(echo ${FULL_PATH// /\\ } | rev | cut -d/ -f2-99 | rev)"
rsync -avzP $rsyncOpts -e "ssh -i $REMOTE_SSH_PRIV_KEY -o StrictHostKeyChecking=no" $COLLECT_PATH ${REMOTE_USERNAME}@${REMOTE_IP}:$dest
done; 
IFS=$oldIFS
set +x
popd
```


## registry-vm-template-files-and-folders.bash

```
❯ ./registry-vm-template-files-and-folders.bash /Library/Application\ Support/Veertu/Anka/registry c0847bc9-5d2d-4dbc-ba6a-240f7ff08032
ls: ./images_dir/e559a538ce9248c2ac9be7a5504577ea.ank: No such file or directory
list of orphaned .ank =============================
./vm_dir/c0847bc9-5d2d-4dbc-ba6a-240f7ff08032
./images_dir/775f3ddad39940b0b9c3437c9cf94a03.ank
./images_dir/7e486ddfc5834c8bb9c4c7674280b542.ank
./images_dir/d6f264303bbd4d13bd6abf8ef035fa15.ank
./state_file_dir/7fcfa48104c0471a86c6429d3efbb450.ank
./state_file_dir/a01ec21a367a41818e034cc5fef9baf6.ank
./state_file_dir/e4429baea4444c2f9b8b22b7d179fb8d.ank
./state_file_dir/ee2a81e991a14aeb9b92db312d069ac0.ank
```