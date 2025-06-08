#!/usr/bin/env bash
function helptext {
    echo 'Usage: partition-ssd-with-data.bash device0 [device1 ...]'
    echo
    echo 'Please pass as arguments all the block devices you wish to partition.'
    echo 'The provided block devices will all be given the same partition layout.'
    echo 'There will be an SLOG partition and an SVDEV partition.'
    echo
    echo 'You can configure this script by editing `env.sh`.'
    echo
    echo 'Warning: This script does not check validity. Make sure your block devices exist and are the same size.'
}

## Validate parameters
if [[ $# -lt 1 ]]; then
    helptext >&2
    exit 1
fi

## Get environment
ENV_FILE='../env.sh'
if [[ -f "$ENV_FILE" ]]; then
    source ../env.sh
else
    echo "ERROR: Missing '$ENV_FILE'."
    exit 2
fi
if [[
    -z "$ENV_NAME_RESERVED" ||\
    -z "$ENV_NAME_SLOG" ||\
    -z "$ENV_NAME_SVDEV" ||\
    -z "$ENV_ZFS_SECTORS_RESERVED"
]]; then
    echo "ERROR: Missing variables in '$ENV_FILE'!" >&2
    exit 3
fi

## Partition the disk
set -e
declare -i EXIT_CODE=0
for DEVICE in "$@"; do
    if [[ ! -b "$DEVICE" ]]; then
        echo "ERROR: $DEVICE is not a valid block device." >&2
        EXIT_CODE=2
        continue
    fi
    ## Ensure correct alignment value.
    declare -i ALIGNMENT=$(((1024 ** 2) / $(blockdev --getss "$DEVICE"))) ## Always equals 1MiB in sectors. Is 2048 unless drive is 4Kn, in which case is 256. This math avoids the undesirable default situation which is to waste 8MiB instead of 1MiB on 4Kn disks.
    ## TRIM entire device (also wipes data, albeit insecurely)
    blkdiscard -f "$DEVICE"
    ## Create GPT partition table
    sgdisk --zap-all "$DEVICE"
    ## Create reserved partition (to allow for future drive size mismatches)
    sgdisk --set-alignment=1 --new=9:-"$ENV_ZFS_SECTORS_RESERVED":0 --typecode=9:BF07 --change-name=9:"$ENV_NAME_RESERVED" "$DEVICE"
    ## Create SLOG partition
    sgdisk --set-alignment=$ALIGNMENT --new=1:0:+6GiB --typecode=1:BF02 --change-name=1:"$ENV_NAME_SLOG" "$DEVICE" ## The absolute worst-possible-case scenario with default settings is apparently 4.8GiB. 5GiB covers that, and 6GiB covers that without performance degradation.
    ## Create SVDEV partition
    sgdisk --set-alignment=$ALIGNMENT --new=2:0:0 --typecode=2:BF01 --change-name=2:"$ENV_NAME_SVDEV" "$DEVICE"
done
exit $EXIT_CODE
