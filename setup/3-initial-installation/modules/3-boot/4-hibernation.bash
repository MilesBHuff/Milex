#!/usr/bin/env bash
##
## **Overview:**
## > Hibernation is a useful but universally overlooked feature in the server space.
## > In the event of a prolonged power-outage, a system connected to a UPS can hibernate instead of powering off.
## > At the end of the outage, this system can then restore to its prior state.
## > This is much faster and much-less-disruptive than a true cold boot, and crucially for some ZFS setups: it means you don't have to rebuild L2ARC.
## > Hibernation is also, obviously, very useful on a laptop: The system can hibernate before the battery dies, thus allowing resumption without a reboot once power is resupplied.
##
## **Etymology:**
## > Windows, unlike Linux, properly distinguishes the roles of the on-disk memory cache ("pagefile") and hibernation cache ("hiberfile").
## > This script introduces that distinction to Linux.
## > As swap devices in a ZFS system are nigh-necessarily zvols, I have taken to calling the former a "pagevol" and the latter a "hibervol", by analogy.
##
## **Hibernation:**
## > Create a new sparse zvol with snapshots disabled and compression enabled (using the same algorithm as zram swap: zstd-2), equal to the size of the zram swap: "pagevol" (Why: We need somewhere on-disk to dump the contents of zram swap)
## > Create a new sparse zvol with snapshots disabled and compression disabled: "hibervol" (Why: The Linux kernel already compresses the memory sent to the hibervol.)
## > Format pagevol as swap with name "pageswap" and priority `-1`. (the lowest possible)
## > Format hibervol as swap with name "hiberswap" and priority `100` (an arbitrary number that is higher than pageswap and lower than zram swap).
## > Swapon pageswap, then drop unneeded caches (`vm.drop_caches=3`), then disable systemd-oomd, then swapoff zram swap, then disable zswap.
## > * If free RAM is limited, this will temporarily cause a substantial drop in performance as the kernel moves things from zram swap to pageswap. Expect lockups and potentially thrashing if zram swap is substantial.
## > * Dropping unneeded caches beforehand should help a lot, but it's no guarantee that there will not be a serious performance hit.
## > * If memory pressure is sufficiently severe, an OOM killer could be engaged. It's imperative that we avoid that eventuality. We can disable systemd's, but we can't disable the kernel's.
## > Compact memory (`vm.compact_memory=1``), swapon hibervol and initiate hibernation.
## > * Memory compaction is optional, but it may result in a higher compression ratio; and, in any case, it will help with performance after resume.
##
## **Restoration:**
## > initramfs unlocks the pool.
## > initramfs looks for the presence of hibervol.
## > If hibervol is not present, initramfs loads the system normally.
## > If hibervol is present, initramfs resumes from it.
## > If an error is encountered, the system attempts
## > After restoration: enable zswap, then swapon zram swap, then swapoff hiberswap, then swapoff pageswap.
## > After swapoffs finish: enable systemd-oomd, delete hibervol, then delete pagevol.
##
## **Failsafe:**
## > We check for the existence of the pagevol and the hibervol on normal boots.
## > If found, we delete them and log a warning.
## > This helps ensure clean operation even in the event that something ever goes wrong with hibernation.
##
## **Contingency:**
## > Set a hard quota on the OS zpool equal to the total amount of installed RAM.
## > This should virtually ensure that there is always room for a hibervol to be made.
## > How:
## > * We move zram swap (max 1/3 of RAM) to a swap zvol with the same size and compression algorithm. So to guarantee that we can fit the contents of zram swap, we only need to reserve 1/3 of total RAM on the storage pool.
## > * The other 2/3 of RAM is uncompressed (1:1, if unswapped) or lightly compressed (2:1, if zswapped). Linux typically compresses to roughly about 5:2 when hibernating, which is at least as much as zswap is doing; so a reservation of 2/3 total RAM is a guarantee that we will always have enough space to hibernate.
##
## **Whys:**
## > Why bother with this? Why not just have permanent on-disk swap all the time? Why not just not have swap at all?
## > * Swap on ZFS is a bad idea for normal operation:
## >   * System resource contention can result in *bad* scenarios where there aren't enough resources to properly steward the zvol that swap is located on at the same time as the system needs to swap/unswap in order to function.
## >   * zvol swap is not great; swapfiles are even worse.
## > * Swap partitions are extremely inelegant:
## >   * They must be encrypted or an attacker can read the full contents of your memory from your disk.
## >     * On an array, this means encrypted LUKS atop LVM OR several independent LUKS partitions; either way, you have to configure your initramfs to unlock them or you have to manually enter passwords.
## >   * They kill the beautiful dream of having ZFS be the one true master of all storage.
## >   * They prevent ZFS from running in whole-disk mode.
## >   * They significantly complicate the addition of new disks to an array.
## > * For 99.9% of a server's operation life, having on-disk swap is not only unnecessary: It's actively harmful.
## >   * The only time swap needs durability is during hibernation.
## >   * Swapping to/from compressed RAM is *ludicrously* faster than swapping to/from durable storage.
## >   * Swapping to/from durable storage competes with normal I/O, thus degrading normal I/O performance.
## >   * ZFS performance significantly degrades when there is not much freespace. A permanent capacity loss equal to total RAM can be *substantial*, and thereby pose a significant reduction to performance in a near-full pool.
## >   * Significantly reducing the space available to ZFS 99.9% of the time to simplify 0.01% of the time is a bad trade.
## > * Having no swap at all means you don't have any way to avert an OOM killer when the kernel excessively overcommits memory. Given the ease with which zram swap can be enabled, I consider it to be senseless/reckless to run swapless.
## > Why do we need two transient swap zvols?
## > * zram swap *most likely* looks like a normal swap device to the kernel, so I *assume* it is not included when hibernating. Therefore, failure to dump it beforehand *should* guarantee an unusable hibernation image.
## > * zram swap is compressed differently from how hibernated RAM is compressed, so the only way to guarantee the right amount of on-disk swap is to create one zvol per source, each matched to that source in compression expectations.
##
## **Risks:**
## > * If something goes wrong and hibernation or resume fails, you have the effects of a sudden system crash.
## > * If resume fails, you may be unable to boot without manual intervention.
## > * If memory pressure spikes too high during swap drains, an OOM killer could be triggered.
## > My goal is to eliminate these risks.
##
## **Theory TODOs:**
## > zram swap is just a zram device formatted as a swap partition; because of this, I *assume* that it is excluded from hibernation just as any other swap device would be, and that it must therefore be drained to durable storage prior to hibernation.
## > However, I don't actually know for certain that this caveat is true; it is possible that perhaps the kernel hibernates the entirety of RAM *period*, without regard to whether some of RAM is a swap device. It is also possible that the kernel may treat zram swap differently from normal swap.
## > I need to confirm before beginning implementation.

#TODO: Implement the above.
#TODO: Enable automatic hibernation when NUT detects that the UPS is low on battery.
