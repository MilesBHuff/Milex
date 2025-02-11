# Miles's NAS Configs & Scripts

This repo contains scripts, configurations, etc that pertain to my NAS.

## Formatting

This directory contains scripts that will yield you a ZFS pool with optimized settings, an HDD mirror for most of your data, and an SSD for SLOG + SVDEV (metadata / small files). This will get you optimal performance and longevity for minimal hardware.

(Ideally, the OS would also go onto the SSD mirror, to take advantage of its redundancy and further-decrease the amount of hardware required by the system; but TrueNAS does not support installation to a partition.)
