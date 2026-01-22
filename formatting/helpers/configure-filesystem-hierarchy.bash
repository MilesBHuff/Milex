#!/usr/bin/env bash
function helptext {
    echo "Usage: configure-filesystem-hierarchy.bash"
    echo
    echo 'This script modifies the filesystem hierarchy of the current OS.'
}

## `/var/www` needs to be moved to `/srv` so that it is treated the same as other web services.
mkdir -p /var/www
if [[ ! -L /var/www && ! -d /srv/www ]]; then
    mv -f /var/www /srv/www
    ln -sTv /srv/www /var/www
fi

## This helps reflect dataset inheritance.
if [[ ! -L /home/root ]]; then
    ln -sTv /root /home/root
fi

# The following files need to be moved to a whitelisted directory and symlinked back.
# Unfortunately, their associated applications recreate them, meaning that any symlinks would be deleted and replaced.
#
# if [[ ! -L /var/lib/apt/extended_states && ! -d /var/lib/apt/states ]]; then
#     mkdir -p /var/lib/apt/states
#     mv /var/lib/apt/extended_states /var/lib/apt/states/extended
#     ln -sTv ./states/extended /var/lib/apt/extended_states
# fi
#
# if [[ ! -L /var/lib/shells.state && ! -d /var/lib/shells ]]; then
#     mkdir -p /var/lib/shells
#     mv /var/lib/shells.state /var/lib/shells/state
#     ln -sTv ./shells/state /var/lib/shells.state
# fi

## Ensure that certain key directories in `/var` remain tied to system snapshots.
VARKEEP_DIR='/varkeep'
mkdir -p "$VARKEEP_DIR"
if [[ -d "$VARKEEP_DIR" ]]; then
    declare -a VARKEEP_DIRS=('/var/lib/apt' '/var/lib/dkms' '/var/lib/dpkg' '/var/lib/emacsen-common' '/var/lib/sgml-base' '/var/lib/ucf' '/var/lib/xml-core') # '/var/lib/apt/states' '/var/lib/shells'
    for DIR in "${VARKEEP_DIRS[@]}"; do
        if [[ -d "$DIR" && ! -L "$DIR" ]]; then
            mv -f "$DIR" "$VARKEEP_DIR/"
            ln -sTv "$VARKEEP_DIR/"$(basename "$DIR") "$DIR"
        fi
    done
fi

## Done
exit 0
