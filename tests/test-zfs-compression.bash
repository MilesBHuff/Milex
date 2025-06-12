#!/usr/bin/env bash
[[ ! $# -eq 1 || ! -e "$1" ]] && echo "Please specify a path on tmpfs to test compression on. " && exit 1

DATASET='nas-pool/test'
zfs set compression=off "$DATASET"

SRC_DIR="$1"
OUT_DIR="/media/zfs/$DATASET"

SRC_SIZE=$(($(du -s "$SRC_DIR" | cut -f1) * 1024))
echo -n 'source'
echo -e "\t\t| Bytes: $SRC_SIZE\t|"

function round_expr {
    echo "$1" | bc -l | xargs printf "%.${2:0}f"
}

function do_test {
    echo -n "$1"
    zfs destroy "$DATASET/$1" >/dev/null 2>&1
    zfs create "$DATASET/$1" >/dev/null 2>&1
    zfs set compression="$1" "$DATASET/$1" >/dev/null 2>&1
    TIME=$(/usr/bin/time -f '%e' cp -a "$SRC_DIR" "$OUT_DIR/$1" 2>&1 | tail -n1)
    SIZE=$(($(du -s "$OUT_DIR/$1" | cut -f1) * 1024))
    SPEED=$(numfmt --to=iec <<< $(round_expr "$SRC_SIZE / $TIME" 0))
    RATIO=$(round_expr "$SIZE / $SRC_SIZE * 100" 2)'%'
    TABS=$([[ ${#1} -lt 8 ]] && echo '\t\t' || echo '\t')
    echo -e "$TABS| Bytes: ${SIZE}\t| Secs: ${TIME}\t| Speed: ${SPEED}/s\t| Ratio: ${RATIO}\t|"
}

#do_test 'off'
#do_test 'zle'
do_test 'lz4'
#do_test 'zstd-fast-1000'
#do_test 'zstd-fast-100'
#do_test 'zstd-fast-10'
do_test 'zstd-fast-1'
do_test 'zstd-1'
do_test 'zstd-2'
#for LVL in {1..19}; do
#    do_test "zstd-$LVL"
#done

## Done
exit 0
