#!/usr/bin/env bash
## Tune system I/O.

#################
## PREPARATION ##
#################

## Make sure we're root
if [[ $EUID -ne 0 ]]; then
    echo "ERROR: This script must be run as root." >&2
    exit 1
fi

## Try to load environment variables from some possible locations. Stop after the first match.
declare -a ENV_FILES=(
    '/etc/filesystem-env.sh'
    '../filesystem-env.sh'
)
for ENV_FILE in "${ENV_FILES[@]}"; do
    if [[ -f "$ENV_FILE" ]]; then
        source "$ENV_FILE"
        break
    fi
done
unset ENV_FILES

## Check to make sure that all the environment variables we need are defined.
declare -a ENV_VARS=(
    "$ENV_NVME_QUEUE_DEPTH"
    "$ENV_POOL_NAME_NAS"
    "$ENV_POOL_NAME_OS"
    "$ENV_RECORDSIZE_HDD"
    "$ENV_RECORDSIZE_SSD"
)
for ENV_VAR in "${ENV_VARS[@]}"; do
    if [[ -z "$ENV_VAR" ]]; then
        echo "ERROR: Missing environment variable!" >&2
        exit 1
    fi
done

function apply-setting {
    [[ -f "$2" ]] || return 1
    COMMAND="echo '$1' > '$2'"
    echo "$COMMAND"
    eval "$COMMAND"
    [[ $? = 0 ]] || echo "$0: current value: $(cat "$2")" >&2
}

#TODO: Make persistent via udev, so that it will automatically re-apply whenever devices are inserted/removed.
#FIXME: Linux assumes rotational by default, which results in flashdrives incorrectly being marked as rotational.
for DEV in /sys/block/sd* /sys/block/nvme*n*; do
    DEV_DEV="/dev/$(basename "$DEV")"

    ## Make sure flash drives are not marked as rotational
    if udevadm info --query=property --name="$DEV_DEV" | grep 'FLASH'; then #WARN: This assumes that everything claiming to be "FLASH" is actually flash, which is probably correct almost always. It does not get things that are flash but do not call themselves "FLASH". Overall, this should have low-to-no false-positives, which is good. Some false-negatives falling through the cracks is fine.
        SETTING_NEW=0
        SETTING_PATH="$DEV/queue/rotational"
        apply-setting "$SETTING_NEW" "$SETTING_PATH"
    fi
    ROTATIONAL=$(cat "$DEV/queue/rotational")

    ## If this is a USB device, note if it uses BOT.
    declare -i IS_BOT=0
    [[ "$(readlink -f "$DEV/device/driver")" == */usb-storage ]] && IS_BOT=1

    ## Configure queue depth limits per-device
    SETTING_NEW=32
    [[ $ROTATIONAL -eq 1 ]] && SETTING_NEW=16 ## Cap HDD queue depths (prevents head-thrashing / improves latency without harming throughput) (16 is what Exoses are rated for.)
    [[ "$DEV" == *nvme* ]] && SETTING_NEW=$ENV_NVME_QUEUE_DEPTH #TODO: Set this dynamically to the NVMe's actual max queue depth.
    [[ "$IS_BOT" -eq 1 ]] && SETTING_NEW=1 ## BOT only supports 1.
    SETTING_PATH="$DEV/device/queue_depth"
    apply-setting "$SETTING_NEW" "$SETTING_PATH"

    ## Configure schedulers per-device
    #NOTE: HDDs and BOT USBs need a scheduler since they will have queues below what ZFS can control, thanks to their above queue limits.
    SETTING_NEW='mq-deadline'
    [[ $ROTATIONAL -eq 0 && IS_BOT -eq 0 ]] && SETTING_NEW='none'
    SETTING_PATH="$DEV/queue/scheduler"
    apply-setting "$SETTING_NEW" "$SETTING_PATH"

    ## Disable complex request merging for NVMe
    if [[ "$DEV" == *nvme* ]]; then
        SETTING_NEW=1 ## Difference between this and 2 (disabled) is almost nothing for the CPU. Default is 0, which uses a less-simple algorithm.
        SETTING_PATH="$DEV/queue/nomerge"
        apply-setting "$SETTING_NEW" "$SETTING_PATH"
    fi

    ## May help to match recordsize on disks in ZFS pool
    declare -i IS_PART_OF_POOL=0
    declare -a POOL_NAMES=("$ENV_POOL_NAME_DAS" "$ENV_POOL_NAME_NAS" "$ENV_POOL_NAME_OS")
    for NAME in "${POOL_NAMES[@]}"; do
        DEVICES=$(zpool status -P "$NAME" | sed -E 's/^\/dev\/(.+)p?\d*?$/\1/') #FIXME: Only works for things inside the root of `/dev`, not for things in subdirectories.
        for DEVICE in $DEVICES; do
            DISK=$(readlink -f "$DEVICE" | sed 's|/dev/||')
            if [[ "/sys/block/$DISK" == "$DEV" ]]; then
                IS_PART_OF_POOL=1
                break
            fi
        done
        [[ $IS_PART_OF_POOL -eq 1 ]] && break
    done
    if [[ $IS_PART_OF_POOL -eq 1 ]]; then

        #WARN: This code only works with recordsizes under 1M! (It expects "K".)
        SETTING_NEW="${ENV_RECORDSIZE_HDD%K}" ## Default: 128
        [[ $ROTATIONAL -eq 0 ]] && SETTING_NEW="${ENV_RECORDSIZE_SSD%K}"
        SETTING_PATH="$DEV/queue/read_ahead_kb"
        apply-setting "$SETTING_NEW" "$SETTING_PATH"

        SETTING_PATH="$DEV/queue/optimal_io_size"
        if [[ $(cat "$SETTING_PATH") -eq 0 ]]; then ## Only set if it wasn't set automatically.
            SETTING_NEW=$((SETTING_NEW * 1024))
            apply-setting "$SETTING_NEW" "$SETTING_PATH"
        fi
    fi
done

#############
## WRAP UP ##
#############

## All done!
exit 0
