# Options

Every option the modules of this flake declare. This file is generated from the module sources: change a description there, then run `nix run .#std-write-option-reference`.

## NixOS module

Declared in [module.nix](../module.nix).

### `cachyos.settings.enable`

Whether to enable the CachyOS settings areas switched on below; on its own it changes nothing.

Type: `boolean`. Default: `false`.

### `cachyos.settings.audio.enable`

Whether to enable audio latency tuning: PCI latency timers, snd-hda-intel power saving off on AC, HPET/RTC and CPU DMA latency for the audio group, rtprio and nice limits, rtkit logging capped at info.

Type: `boolean`. Default: `false`.

### `cachyos.settings.coredump.enable`

Whether to enable removal of core dumps older than three days.

Type: `boolean`. Default: `false`.

### `cachyos.settings.ioSchedulers.enable`

Whether to enable I/O scheduler udev rules: bfq for rotational disks, mq-deadline for SSD and eMMC, kyber for NVMe.

Type: `boolean`. Default: `false`.

### `cachyos.settings.journal.enable`

Whether to enable a 50M cap on the system journal.

Type: `boolean`. Default: `false`.

### `cachyos.settings.ntsync.enable`

Whether to enable the ntsync kernel module, which Wine and Proton use for NT synchronization.

Type: `boolean`. Default: `false`.

### `cachyos.settings.nvidia.enable`

Whether to enable NVIDIA runtime power management on bind, and NVreg_InitializeSystemMemoryAllocations=0, which skips zeroing freshly allocated system memory for speed.

Type: `boolean`. Default: `false`.

### `cachyos.settings.oomd.enable`

Whether to enable systemd-oomd slice policy: kill on swap for system.slice, kill on swap and at 80% memory pressure for every slice of a user manager that can see PID 1, session.slice left alone; it acts only while systemd-oomd runs.

Type: `boolean`. Default: `false`.

### `cachyos.settings.serviceManager.enable`

Whether to enable systemd's stop timeout and open-file limits for the system and user managers, and cgroup delegation to user managers.

Type: `boolean`. Default: `false`.

### `cachyos.settings.storage.enable`

Whether to enable SATA link power at max_performance and hdparm for rotational disks.

Type: `boolean`. Default: `false`.

### `cachyos.settings.sysctl.enable`

Whether to enable upstream's VM, kernel and network sysctls with dirty memory as ratios of RAM, writeback caps on slow disks, and swappiness 150 with zswap off once a zram device is up.

Type: `boolean`. Default: `false`.

### `cachyos.settings.thp.enable`

Whether to enable THP defrag at defer+madvise and the khugepaged shrinker threshold.

Type: `boolean`. Default: `false`.

### `cachyos.settings.watchdogBlacklist.enable`

Whether to enable the blacklist of the iTCO, SP5100 and WDAT hardware watchdog drivers.

Type: `boolean`. Default: `false`.

### `cachyos.settings.zram.enable`

Whether to enable zram swap with upstream's values: zstd, up to 100% of RAM, priority 100.

Type: `boolean`. Default: `false`.
