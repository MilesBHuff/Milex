#!/usr/bin/env bash
function rsyncoid {
    function helptext {
        echo "Usage: rsyncoid <source> <destination>"
    }

    if [[ -z "$1" || -z "$2" ]]; then
        helptext >&2
        return 1
    fi

    RSYNC=$(which rsync)
    #RSYNC=~/.local/bin/rsync
    #RSYNC=~/.local/bin/prsync
    if [[ ! -f "$RSYNC" ]]; then
        echo "Error: '$RSYNC' not extant." >&2
        return 2
    fi
    if [[ ! -x "$RSYNC" ]]; then
        echo "Error: '$RSYNC' not executable." >&2
        return 2
    fi

    local LOGDIR="${RSYNCOID_LOGDIR:-/tmp/rsyncoid}"
    mkdir -p "$LOGDIR" > /dev/null 2>&1 || {
        echo "Error: Unable to create '$LOGDIR'." >&2
        return 3
    }
    [[ ! -x "$LOGDIR" || ! -w "$LOGDIR" || ! -r "$LOGDIR" ]] && {
        echo "Error: Insufficient access to '$LOGDIR'." >&2
        return 4
    }

    local TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

    clear
    "$RSYNC" \
        -hP --no-partial -HS -aAEX --numeric-ids --checksum --update --inplace --whole-file --no-compress --bwlimit=0 --block-size=128K --outbuf=B,$((16*(1024**2))) \
        "$1" "$2" \
        2> >(tee "$LOGDIR/rsyncoid_$TIMESTAMP.stderr.txt" >&2)
    #NOTE: If you're copying locally (not over USB3 or network), add `--no-checksum` for more performance.
    #NOTE: If you're sending this over the network, remove `--no-compress`.
    #NOTE: If the writes must be atomic, add `--fsync`
    #NOTE: If you are using ZFS, set `outbuf` to your recordsize.
    #NOTE: Remove `--inplace` if destination FS is not CoW.
}
