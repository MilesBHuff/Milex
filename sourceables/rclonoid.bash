#!/usr/bin/env bash
function rclonoid {
    function helptext {
        echo "Usage: rclonoid <source> <destination>"
    }

    if [[ -z "$1" || -z "$2" ]]; then
        helptext >&2
        return 1
    fi

    RCLONE=$(which rclone)
    #RCLONE=~/.local/bin/rclone
    if [[ ! -f "$RCLONE" ]]; then
        echo "Error: '$RCLONE' not extant." >&2
        return 2
    fi
    if [[ ! -x "$RCLONE" ]]; then
        echo "Error: '$RCLONE' not executable." >&2
        return 2
    fi

    local LOGDIR="${RCLONOID_LOGDIR:-/tmp/rclonoid}"
    mkdir -p "$LOGDIR" > /dev/null 2>&1 || {
        echo "Error: Unable to create '$LOGDIR'." >&2
        return 3
    }
    [[ ! -x "$LOGDIR" || ! -w "$LOGDIR" || ! -r "$LOGDIR" ]] && {
        echo "Error: Insufficient access to '$LOGDIR'." >&2
        return 4
    }

    CACHE_DIR='/tmp/rclone'
    mkdir -p "$CACHE_DIR"
    local TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

    clear
    "$RCLONE" copy \
        --metadata \
        --cache-dir="$CACHE_DIR" \
        --checksum \
        --create-empty-src-dirs \
        --default-time=0s \
        --fix-case \
        --human-readable \
        --inplace \
        --links \
        --multi-thread-write-buffer-size=16M \
        --no-unicode-normalization \
        --progress \
        --transfers=16 \
        --track-renames \
        --update \
        -- "$1" "$2" \
        2> >(tee "$LOGDIR/rclonoid_$TIMESTAMP.stderr.txt" >&2)
    #WARN: Will not copy things like sockets and pipes. This is actually probably a good thing.
    #NOTE: If the destination does not support move, do not use `--fix-case` or `--track-renames`.
    #NOTE: Skip `--inplace` when doing transfers to in-use filesystems. `--inplace` is necessary to not break hardlinks.
    #NOTE: Set `--multi-thread-write-buffer-size` to your destination's recordsize if using ZFS; else, remove the argument.
    #NOTE: Remove `--no-unicode-normalization` if you want to convert everything to UTF-8.
    #NOTE: Set `--transfers` to the lowest `nproc` between your source and destination, or the lowest queue depth of any involved disk, whichever is lower.
}
