#!/usr/bin/env bash
function helptext {
    echo "Usage: zfs-create-os-datasets.bash"
    echo
    echo 'Warning: This script does not check validity — make sure your pool exists.'
}

## Get environment
ENV_FILE='../env.sh'
if [[ -f "$ENV_FILE" ]]; then
    source ../env.sh
else
    echo "ERROR: Missing '$ENV_FILE'."
    exit 2
fi
if [[
    -z "$ENV_POOL_NAME_OS" ||\
    -z "$ENV_SNAPSHOT_NAME_INITIAL" ||\
    -z "$ENV_ZFS_ROOT" ||\
    -z "$ENV_ZPOOL_COMPRESSION_MOST"
]]; then
    echo "ERROR: Missing variables in '$ENV_FILE'!" >&2
    exit 3
fi

## Declare variables

#declare -a DATASETS=('/os' "/os/$ENV_SNAPSHOT_NAME_INITIAL" '/data' '/data/home' '/data/srv' '/exclude' '/exclude/var_cache' '/exclude/var_log' '/exclude/var_spool' '/exclude/var_tmp' '/exclude/tmp' '/virtual' '/virtual/var_lib_vz' '/virtual/var_lib_lxc' '/virtual/var_lib_libvirt' '/virtual/var_lib_qemu' '/virtual/var_lib_rrdcached' '/virtual/var_lib_pve-cluster' '/virtual/var_lib_pve-manager' '/virtual/var_lib_docker') ## The idea is to allow for separate OS snapshots and data snapshots while excluding unimportant tempfiles.
#declare -a   MOUNTS=(   ''                              '/'      ''      '/home'      '/srv'         ''         '/var/cache'         '/var/log'         '/var/spool'         '/var/tmp'         '/tmp'         ''         '/var/lib/vz'         '/var/lib/lxc'         '/var/lib/libvirt'         '/var/lib/qemu'         '/var/lib/rrdcached'         '/var/lib/pve-cluster'         '/var/lib/pve-manager'         '/var/lib/docker')

#NOTE: All-caps is conventional for the dataset containing the OS, because capital letters sort before lowercase, and therefore load before lowercase.
#WARN: `/var/lib/apt/extended_states` and `/var/lib/shells.state` need to be included in system snapshots, but the other items in their parent directories do not. Symlinking is not viable because these files are periodically recreated. While we can live with snapshotting all of `/var/lib/apt`, doing so for all of `/var/lib` would be excessive, and is not worth it to have an in-sync `shells.state`.
# declare -a DATASETS=('/data' '/data/home' '/data/home/root' '/data/srv' '/data/var'  '/OS' '/OS/debian' '/OS/debian/var:lib:apt' '/OS/debian/var:lib:dkms' '/OS/debian/var:lib:dpkg' '/OS/debian/var:lib:sgml-base' '/OS/debian/var:lib:ucf' '/OS/debian/var:lib:xml-core') ## The idea is to allow for separate OS snapshots and data snapshots while excluding unimportant tempfiles.
# declare -a   MOUNTS=(     ''      '/home'           '/root'      '/srv'      '/var'     ''          '/'           '/var/lib/apt'           '/var/lib/dkms'           '/var/lib/dpkg'           '/var/lib/sgml-base'           '/var/lib/ucf'           '/var/lib/xml-core')

#NOTE: All-caps is conventional for the dataset containing the OS, because capital letters sort before lowercase, and therefore load before lowercase.
declare -a DATASETS=('/data' '/data/home' '/data/home/root' '/data/srv' '/data/var'  '/OS' '/OS/debian') ## The idea is to allow for separate OS snapshots and data snapshots while excluding unimportant tempfiles. The few things in `/var` that need to be kept with rollbacks can be placed into `/varkeep` and symlinked/bind-mounted back to their original locations.
declare -a   MOUNTS=(     ''      '/home'           '/root'      '/srv'      '/var'     ''          '/')

if [[ ! ${#DATASETS[@]} -eq ${#MOUNTS[@]} ]]; then
    echo "ERROR: Mismatch in number of items in the DATASETS (${#DATASETS[@]}) and MOUNTS (${#MOUNTS[@]}) arrays; please fix!" >&2
    exit 3
fi
declare -i COUNT=${#DATASETS[@]}

## Create datasets
set -e
declare -i I=0
while [[ $I -lt $COUNT ]]; do
    if [[ "${MOUNTS[$I]}" == '' ]]; then
        zfs create \
            \
            -o canmount=off \
            -o mountpoint=none \
            \
            "$ENV_POOL_NAME_OS${DATASETS[$I]}"
    else
        zfs create \
            \
            -o canmount=$([[ ${MOUNTS[$I]} == '/' ]] && echo noauto || echo on) \
            -o mountpoint="${MOUNTS[$I]}" \
            \
            "$ENV_POOL_NAME_OS${DATASETS[$I]}"
    fi
    zfs snapshot "$ENV_POOL_NAME_OS${DATASETS[$I]}@$ENV_SNAPSHOT_NAME_INITIAL"
    ((++I))
done
set +e

## Configure datasets
zfs set com.sun:auto-snapshot=false "$ENV_POOL_NAME_OS/data/var"
zpool set bootfs="$ENV_POOL_NAME_OS/OS/debian" "$ENV_POOL_NAME_OS"

## Ensure that `/etc/zfs/zpool.cache` exists and that everything is mounted.
if [[ ! -f '/etc/zfs/zpool.cache' ]]; then
    zpool export -f "$ENV_POOL_NAME_OS"
    zpool import -N -R "$ENV_ZFS_ROOT/$ENV_POOL_NAME_OS" "$ENV_POOL_NAME_OS"
    zfs load-key "$ENV_POOL_NAME_OS"
    zfs mount "$ENV_POOL_NAME_OS/OS/debian"
    zfs mount "$ENV_POOL_NAME_OS/data/var"
    zfs mount "$ENV_POOL_NAME_OS/data/srv"
    zfs mount "$ENV_POOL_NAME_OS/data/home"
    zfs mount "$ENV_POOL_NAME_OS/data/home/root"
fi

## Done
udevadm trigger
exit 0
