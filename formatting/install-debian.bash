#!/usr/bin/env bash
function helptext {
    echo "Usage: install-debian.bash"
    echo
    echo 'This script installs debian to the target directory.'
}
## Special thanks to https://openzfs.github.io/openzfs-docs/Getting%20Started/Debian/Debian%20Bookworm%20Root%20on%20ZFS.html
## Also thanks to ChatGPT (not for code, but for helping with some installataion steps)

## Get environment
ENV_FILE='../env.sh'
if [[ -f "$ENV_FILE" ]]; then
    source ../env.sh
else
    echo "ERROR: Missing '$ENV_FILE'." >&2
    exit 2
fi
if [[
    -z "$ENV_NAME_ESP" ||\
    -z "$ENV_POOL_NAME_OS" ||\
    -z "$ENV_ZFS_ROOT"
]]; then
    echo "ERROR: Missing variables in '$ENV_FILE'!" >&2
    exit 3
fi
set -e

## Set variables
echo ':: Setting variables...'
export TARGET="$ENV_ZFS_ROOT/$ENV_POOL_NAME_OS"
CWD=$(pwd)
cd "$TARGET"

## Mount tmpfs dirs
echo ':: Mounting tmpfs dirs...'
declare -a TMPS=(run tmp)
for TMP in "${TMPS[@]}"; do
    mkdir "$TMP"
    mount -t tmpfs tmpfs "$TMP"
done

## Do the do
echo ':: Debootstrapping...'
apt install -y debootstrap
debootstrap bookworm "$TARGET"

## Bring over ZFS imports
echo ':: Bringing over ZFS imports...'
mkdir -p etc/zfs
set +e
cp /etc/zfs/zpool.cache etc/zfs
cp /etc/zfs/zroot.key etc/zfs
set -e

## Bind-mount system directories for chroot
echo ':: Bindmounting directories for chroot...'
declare -a BIND_DIRS=(dev proc sys)
for BIND_DIR in "${BIND_DIRS[@]}"; do
    mount --make-private --rbind "/$BIND_DIR" "$BIND_DIR"
done
SCRIPTS_DIR='media/scripts'
mkdir -p "$SCRIPTS_DIR"
mount --bind "$CWD" media/scripts

## Run chroot-based scripts
echo ':: Run the following script in chroot:'
echo ":: /$SCRIPTS_DIR/helpers/install-debian-from-chroot.bash"
exec chroot "$TARGET" env bash --login
