#!/usr/bin/env bash
source ./env.sh

function helptext {
    echo 'Usage: format-svdev-mirror.bash device0 device1 [device2 ...]'
    echo
    echo 'Please pass as arguments all the block devices you wish to include in the SLOG.'
    echo 'The provided block devices will be made into ZFS mirrors of each other.'
    echo
    echo 'You can configure this script by editing `env.sh`.'
    echo
    echo 'Warning: This script does not check validity. Make sure your block devices exist and are the same size.'
}

if [[ $# -lt 2 ]]; then
    helptext >&2
    exit 1
fi
