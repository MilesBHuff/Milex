#!/usr/bin/env bash
[[ ! $# -eq 1 || ! -e "$1" ]] && echo 'Please specify a test path.' && exit 1
zfs set compression=off nas-pool

echo 'THEORETICAL TEST'
OUT='/dev/null'
echo 'tar'
tar -cf - "$1" 2>/dev/null | pv >"$OUT"
echo 'lz4'
tar -cf - "$1" 2>/dev/null | pv | lz4 -c >"$OUT"
for LVL in {1..19}; do
    echo "zstd:$LVL"
    tar -cf - "$1" 2>/dev/null | pv | zstd -$LVL -c >"$OUT"
done
echo

echo 'REAL TEST'
OUT='/media/zfs/nas-pool/compression-test'
mkdir -p "$OUT"
echo 'tar'
tar -cf - "$1" 2>/dev/null | pv >"$OUT/0.tar"
echo 'lz4'
tar -cf - "$1" 2>/dev/null | pv | lz4 -c >"$OUT/0.tar.lz4"
for LVL in {1..19}; do
    echo "zstd:$LVL"
    tar -cf - "$1" 2>/dev/null | pv | zstd -$LVL -c >"$OUT/$LVL.tar.zstd"
done
ls -s "$OUT"

zfs set compression=zstd-4 nas-pool
exit 0
