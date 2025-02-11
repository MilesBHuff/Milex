#!/usr/bin/env bash
source ./env.sh

function helptext {
    echo 'Usage: format-data-mirror.bash device0 [device1 ...]'
    echo
    echo 'Please pass as arguments all the block devices you wish to partition.'
    echo 'The provided block devices will all be given the same partition layout.'
    echo 'There will be an SLOG partition and an SVDEV partition.'
    echo
    echo 'You can configure this script by editing `env.sh`.'
    echo
    echo 'Warning: This script does not check validity. Make sure your block devices exist and are the same size.'
}

if [[ $# -lt 1 ]]; then
    helptext >&2
    exit 1
fi
