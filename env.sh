#!/bin/sh
## This file contains variables used by the other scripts in this directory.

## Names

export ENV_POOL_NAME_NAS='nas-pool'
export ENV_POOL_NAME_DAS='das-pool'
export ENV_POOL_NAME_OS='os-pool'

export ENV_NAME_CACHE='cache'
export ENV_NAME_ESP='esp'
export ENV_NAME_OS='os'
export ENV_NAME_RESERVED='reserved'
export ENV_NAME_SLOG='slog'
export ENV_NAME_SVDEV='svdev'
export ENV_NAME_VDEV='vdev'

export ENV_NAME_OS_LUKS="crypt-$ENV_NAME_OS"

export ENV_SNAPSHOT_NAME_INITIAL='initial'

## Paths

export ENV_ZFS_ROOT='/media/zfs'

## Mount Options

export ENV_MOUNT_OPTIONS_ESP='noatime,lazytime,sync,flush,tz=UTC,iocharset=utf8,fmask=0137,dmask=0027,nodev,noexec,nosuid'
export ENV_MOUNT_OPTIONS_OS='noatime,lazytime,ssd,discard=async,compress=lzo'

## Misc Options

export ENV_SECONDS_DATA_LOSS_ACCEPTABLE=5 ## Lower is better apart from fragmentation. You want the lowest value that doesn't significantly increase fragmentation.

## Drive Characteristics

export ENV_SECTOR_SIZE_HDD=4096
export ENV_SECTOR_SIZE_LOGICAL_HDD=4096
export ENV_SECTOR_SIZE_SSD=4096
export ENV_SECTOR_SIZE_LOGICAL_SSD=512
export ENV_SECTOR_SIZE_OS=512
export ENV_SECTOR_SIZE_LOGICAL_OS=512

## Drive Speeds

export ENV_SPEED_MBPS_MAX_THEORETICAL_HDD=285 ## SeaGate Exos X20
export ENV_SPEED_MBPS_MAX_THEORETICAL_SSD=530 ## Micron 5300 Pro: 540 read, 520 write

export ENV_SPEED_MBPS_MAX_SLOWEST_HDD=243 ## Tested with `hdparm -t`: 243, 253, 270
export ENV_SPEED_MBPS_MAX_SLOWEST_SSD=430 ## Tested with `hdparm -t`: 431, 430, 430

export ENV_SPEED_MBPS_AVG_SLOWEST_HDD=$(($ENV_SPEED_MBPS_MAX_SLOWEST_HDD / 2)) #TODO: Measure
export ENV_SPEED_MBPS_AVG_SLOWEST_SSD=$(($ENV_SPEED_MBPS_MAX_SLOWEST_SSD / 2)) #TODO: Measure

## How many devices?
export ENV_DEVICES_IN_VDEVS=3
export ENV_DEVICES_IN_L2ARC=1

## How long, on average, until failure? (in hours)
export ENV_MTBF_NVDEV=2500000
export ENV_MTBF_SVDEV=3000000
export ENV_MTBF_L2ARC=1750000

## How long do you want these devices to last?
export ENV_MTBF_TARGET_L2ARC=2 ## In years.

## How many writes can be endured (in terrabytes per 5 years)
export ENV_ENDURANCE_NVDEV=2750
export ENV_ENDURANCE_SVDEV=2628
export ENV_ENDURANCE_L2ARC=300

## Measured speeds in MB/s (`hdparm -t` averaged across devices)
export ENV_SPEED_L2ARC=4470

## Sizes

export ENV_RECORDSIZE_ARCHIVE='16M' ## Most-efficient storage.
export ENV_RECORDSIZE_HDD='256K' ## Safely above the point at which all filesizes cost the same amount of time to operate on.
export ENV_RECORDSIZE_SSD='64K' ## Safely above the point at which all filesizes cost the same amount of time to operate on.

export ENV_THRESHOLD_SMALL_FILE='64K' ## This is solidly below the point at which HDD operations cost the same time no matter the filesize, so files of this size *need* to be on an SSD if at all possible for optimal performance.

## Root ZPool Options

export ENV_ZPOOL_NORMALIZATION='formD' ## Most-performant option that unifies pre-composed letters and letters with combining diacritics. Downside is that it implies that all filenames are UTF-8; best to not use this setting for legacy pools, or for pools that an OS runs on.
export ENV_ZPOOL_CASESENSITIVITY='sensitive' ## Best for strictness.

export ENV_ZPOOL_ATIME='off' ## Terrible for performance, and *might* cause data duplication on snapshotting (it definitely does in btrfs) — `atime` is fwiu generally incompatible with CoW+snapshotting.

export ENV_ZPOOL_ENCRYPTION='aes-256-gcm' ## Better performance than CCM. Not significantly slower than 128 on my system.
export ENV_ZPOOL_PBKDF2ITERS='999999' ## Run `cryptsetup benchmark` and divide PBKDF2-sha256 by 10 or less to get this number. This makes it take 125ms to unlock this pool on your current computer, and annoys the heck out of attackers.
export ENV_ZPOOL_CHECKSUM='fletcher4' ## This is the default, and is so fast as to be free. Cryptographic hashes like BLAKE3 are ridiculously slower, and provide no benefit if you are not using deduplication or `zfs send | recv`ing from untrusted devices or renting out entire datasets to users with root-level access to those datasets. `cat /proc/sys/kstat/fletcher_4_bench /proc/sys/kstat/chksum_bench` for details.

export ENV_ZPOOL_COMPRESSION_FREE='lz4' ## Practically no performance implications.
export ENV_ZPOOL_COMPRESSION_BALANCED='zstd-4' ## Best ratio of CPU time to filesize on my system. zstd-2 also works very well -- the two are neck-and-neck, and either can win depending on chance. zstd-4 is technically slower on SSDs, but on *my* SSDs there is no difference.
export ENV_ZPOOL_COMPRESSION_MOST='zstd-11' ## Highest level that keeps performance above HDD random I/O is 12, but on my test data it cost 6 more seconds for literally 0 gain vs 11. 11=90M/s, 12=72M/s, 13=38M/s.

export ENV_ZFS_SECTORS_RESERVED=16384 ## This is how much space ZFS gives to partition 9 on whole-disk allocations. On 4K-native disks, this unfortunately eats 64MiB instead of the standard 8MiB...
