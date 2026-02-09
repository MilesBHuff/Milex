#!/bin/sh
echo ':: Upgrading firmware...'
set -e
apt update
apt install -y fwupd
set +e
fwupdmgr refresh
fwupdmgr get-updates && fwupdmgr update
set -e
echo ':: Done.'
