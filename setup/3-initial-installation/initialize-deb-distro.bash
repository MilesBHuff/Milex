#!/usr/bin/env bash
set -euo pipefail

################################################################################
## META                                                                       ##
################################################################################

function helptext {
    echo "Usage: install-deb-distro.bash"
    echo
    echo 'This script installs Debian or Ubuntu to the target directory.'
    echo "It assumes you are running it from a LiveCD for either Debian ($DEBIAN_VERSION) or Ubuntu Server ($UBUNTU_VERSION)."
    echo 'It also assumes that you are connected to the Internet.'
}
## Special thanks to https://openzfs.github.io/openzfs-docs/Getting%20Started/Debian/Debian%20Bookworm%20Root%20on%20ZFS.html
## Special thanks to ChatGPT for helping with my endless questions.

################################################################################
## FUNCTIONS                                                                  ##
################################################################################

function cleanup {
    set +e
    umount -R dev proc run sys tmp media/scripts 2>/dev/null || true
}; trap cleanup EXIT

################################################################################
## ENVIRONMENT                                                                ##
################################################################################

## Get environment
ENV_FILE='../../env.sh'
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
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

## Set variables
echo ':: Setting variables...'
export UBUNTU_VERSION='noble' #TODO: Change once Resolute Racoon (26.04) comes out.
export DEBIAN_VERSION='trixie'
export TARGET="$ENV_ZFS_ROOT/$ENV_POOL_NAME_OS"
if ! mountpoint -q "$TARGET"; then
    echo "ERROR: Target '$TARGET' not mounted!" >&2
    exit 4
fi
CWD=$(pwd)
cd "$TARGET"

################################################################################
## MOUNTS                                                                     ##
################################################################################

## Mount tmpfs dirs
echo ':: Mounting tmpfs dirs...'
declare -a TMPS=(tmp)
for TMP in "${TMPS[@]}"; do
    if mountpoint -q "$TMP"; then
        echo "WARN: '$TMP' is already mounted." >&2
    else
        mkdir -p "$TMP"
        mount -t tmpfs -o nosuid,nodev,mode=1777 tmpfs "$TMP"
    fi
done

################################################################################
## BOOTSTRAP                                                                  ##
################################################################################

echo ':: Debootstrapping...'
declare -i DISTRO=0
while [[ "$DISTRO" -ne 1 && "$DISTRO" -ne 2 ]]; do
    set +e
    read -rp "Which distro are we setting up? (Type '1' for 'Debian' or '2' for 'Ubuntu') " DISTRO
    set -e
done
export DISTRO
apt update
apt install -y debootstrap
if [[ $DISTRO -eq 1 ]]
    then debootstrap "$DEBIAN_VERSION" "$TARGET"
    else debootstrap "$UBUNTU_VERSION" "$TARGET" 'https://archive.ubuntu.com/ubuntu'
fi

## Bring over things from /etc
echo ':: Bringing over configs...'
declare -a FILES=('etc/zfs/zpool.cache' "etc/zfs/keys/$ENV_POOL_NAME_OS.key")
for FILE in "${FILES[@]}"; do
    mkdir -p "$(dirname -- "$FILE")"
    [[ -e "/$FILE" ]] && cp -a "/$FILE" "$FILE" || echo "WARN: '/$FILE' does not exist!" >&2
done
unset FILES
cp -a /etc/hostid etc/hostid ## ZFS keeps track of the host that imported it in its cachefile, so we need to keep the same hostid as the LiveCD.

################################################################################
## CHROOT                                                                     ##
################################################################################

## Bind-mount system directories for chroot
echo ':: Bindmounting directories for chroot...'
declare -a BIND_DIRS=(dev proc run sys)
for BIND_DIR in "${BIND_DIRS[@]}"; do
    if mountpoint -q "$BIND_DIR"; then
        echo "WARN: '$BIND_DIR' is already mounted." >&2
    else
        mkdir -p "$BIND_DIR"
        mount --make-private --rbind "/$BIND_DIR" "$BIND_DIR"
    fi
done
SCRIPTS_DIR='media/scripts'
if mountpoint -q "$SCRIPTS_DIR"; then
    echo "WARN: '$SCRIPTS_DIR' is already mounted." >&2
else
    mkdir -p "$SCRIPTS_DIR"
    mount --bind "$CWD" "$SCRIPTS_DIR"
fi

## Run chroot-based scripts
echo ':: Run the following script in chroot:'
echo ":: /$SCRIPTS_DIR/helpers/install-deb-distro-from-chroot.bash"
exec chroot "$TARGET" env bash --login
