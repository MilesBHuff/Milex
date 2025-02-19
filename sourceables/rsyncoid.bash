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
    "$RSYNC" \
        -hP -HS -aAEX -W --numeric-ids --no-compress --no-checksum --bwlimit=0 \
        "$1" "$2" \
        2> >(tee "$LOGDIR/rsyncoid_$TIMESTAMP.stderr.txt" >&2)
    #NOTE: If updating data instead of copying for the first time, remove `-W --no-checksum` and add ` --append-verify`.
    #NOTE: If you're sending this over the network, remove `--no-compress`.
}
