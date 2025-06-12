#!/usr/bin/env bash
[[ ! $# -eq 1 || ! -e "$1" ]] && echo "Please specify a path to compress for the test. " && exit 1

DATASET='nas-pool/test'
zfs set compression=off "$DATASET"

echo 'Preparing paths...'
FAKEOUT='/dev/null'
REALOUT='/media/zfs/$DATASET/compression'
rm -rf "$REALOUT"
mkdir -p "$REALOUT"
echo

echo 'Preparing tarfile...'
TEMPFILE="$(mktemp).tar"
tar -cf - "$1" 2>/dev/null >"$TAR"
echo

echo 'IN-MEMORY TEST'
echo 'cat'
pv "$TAR" | cat >"$FAKEOUT"
echo 'lz4'
pv "$TAR" | lz4 -B4 --fast=1 -c >"$FAKEOUT"
echo "zstd-fast-1"
pv "$TAR" | zstd --fast=1 -c >"$FAKEOUT"
for LVL in {1..9}; do
    echo "zstd-$LVL"
    pv "$TAR" | zstd -$LVL -c >"$FAKEOUT"
done
echo

echo 'TO-DISK TEST'
echo 'cat'
pv "$TAR" | cat >"$REALOUT/0.tar"
echo 'lz4'
pv "$TAR" | lz4 -B4 --fast -c >"$REALOUT/0.tar.lz4"
echo "zstd-fast-1"
pv "$TAR" | zstd --fast=1 -c >"$REALOUT/0.tar.zstd"
for LVL in {1..9}; do
    echo "zstd-$LVL"
    pv "$TAR" | zstd -$LVL -c >"$REALOUT/$LVL.tar.zstd"
done
echo
ls -s "$REALOUT"
rm -rf "$REALOUT" && mkdir -p "$REALOUT"

#echo 'TIME TEST'
#time cat "$TAR" | zstd --fast=1 -c >/dev/null
#time cat "$TAR" | lz4 -B4 --fast - >/dev/null
#echo

## Done
zfs set compression=zstd-fast-1 "$DATASET"
rm -f "$TAR"
exit 0
