#!/usr/bin/env bash
set -euo pipefail

echo ':: Upgrading firmware...'
apt update
apt install -y fwupd
set +e
fwupdmgr refresh
fwupdmgr get-updates && fwupdmgr update
set -e
echo ':: Done.'
