#!/usr/bin/env bash
set -e

## Variables
SRC_DS='nas-pool'
OUT_DS_PARENT='das-pool'
OUT_DS="$OUT_DS_PARENT/$SRC_DS"
## "DS" -> "Dataset"
## "SRC" -> "Source"
## "OUT" -> "Output"

## Configurables
declare -i HOW_TO_REPLICATE=1 ## 0: First replication ever | 1: Subsequent replications | 2: Subsequent replications if `syncoid` is unavailable
SNAPSHOT_NEW="$SRC_DS@2025-05-06T20:11:39-04:00" ## Only used in replication option 2. Optional.
SNAPSHOT_OLD="$SRC_DS@2025-03-04T12:21-05:00" ## Only used in replication option 2. Find the last common snapshot with `zfs list -t snapshot`.

## Before a replication
zfs unmount -a
zfs list -H -o name -r "$OUT_DS" | while read -r DS; do
    zfs set mountpoint=none "$DS"
done
zfs set readonly=off "$OUT_DS"

case "$HOW_TO_REPLICATE" in
    0) ## Do this only for the first replication.
        SNAPSHOT="$SRC_DS@initial"
        zfs snapshot -r "$SNAPSHOT"
        zfs send -Rw "$SNAPSHOT" | zfs receive -F "$OUT_DS"
        unset SNAPSHOT
        ;;
    1) ## Do this on subsequent replications.
        syncoid --force --no-stream --sendoptions="-Rw" "$SRC_DS" "$OUT_DS" # --recursive
        ;;
    2) ## Do this on subsequent replications only if syncoid isn't available.
        if [[ -z "$SNAPSHOT_NEW" ]]; then
            SNAPSHOT="$SRC_DS@$(date --iso-8601=seconds)"
            zfs snapshot -r "$SNAPSHOT"
        else
            SNAPSHOT="$SNAPSHOT_NEW"
        fi
        zfs send -i "$SNAPSHOT_OLD" -Rw "$SNAPSHOT" | zfs receive -F "$OUT_DS"
        unset SNAPSHOT SNAPSHOT_NEW SNAPSHOT_OLD
        ;;
esac

## After a replication
zfs list -H -o name -r "$OUT_DS" | while read -r DS; do
    MOUNTPOINT="/mnt/$OUT_DS_PARENT${DS#$OUT_DS_PARENT}"
    zfs set mountpoint="$MOUNTPOINT" "$DS"
    zfs set readonly=on "$DS"
done

## Unlock the replicated dataset
zfs load-key -r "$OUT_DS"
zfs mount -a

## Done
exit 0
