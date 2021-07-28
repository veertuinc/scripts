#!/bin/bash

set -e

SCRIPTS=$(mktemp -d /tmp/scripts.XXX)
PKG=$(mktemp /tmp/pkgXXX)
cp -p "$1" "$SCRIPTS/postinstall"
pkgbuild --nopayload --identifier com.veertu.pkg.temp --scripts "$SCRIPTS" "${PKG}.pkg"
productbuild --package "${PKG}.pkg" "$2"
rm "${PKG}" "${PKG}.pkg"
rm -r "$SCRIPTS"