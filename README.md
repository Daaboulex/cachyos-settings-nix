# cachyos-settings-nix

<!-- BEGIN generated:badges -->
[![CI](https://github.com/Daaboulex/cachyos-settings-nix/actions/workflows/ci.yml/badge.svg)](https://github.com/Daaboulex/cachyos-settings-nix/actions/workflows/ci.yml)
[![NixOS unstable](https://img.shields.io/badge/NixOS-unstable-78C0E8?logo=nixos&logoColor=white)](https://nixos.org)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](./LICENSE)
<!-- END generated:badges -->

[CachyOS-Settings](https://github.com/CachyOS/CachyOS-Settings) ported as a standalone NixOS module.

<!-- BEGIN generated:upstream -->
## Upstream

| | |
|---|---|
| **Project** | [CachyOS/CachyOS-Settings](https://github.com/CachyOS/CachyOS-Settings) |
| **License** | GPL-3.0 |
| **Tracked** | Git commits (master) |

<!-- END generated:upstream -->

## What Is This?

A module-only Nix flake providing CachyOS-Settings as a standalone NixOS module:

- **Module-only repo** — no packages output; imports as `nixosModules.default`
- **Daily upstream tracking** — a GitHub Action checks `CachyOS-Settings` master daily and files a `remirror-needed` issue when upstream moves (this module is a hand-port; it never auto-edits)
- **Opt-in areas** — every area (`sysctl`, `zram`, `ioSchedulers`, `audio`, `storage`, `thp`, `ntsync`, `coredump`, `serviceManager`, `journal`, `oomd`, `watchdogBlacklist`, `nvidia`) is off until set; `enable` alone changes nothing
- **Module-instantiation check** — CI instantiates the module (enabled) via `nix flake check`, so activation-time errors surface, not just evaluation

Provides sysctl tuning, udev rules, systemd tweaks, ZRAM, THP, I/O schedulers, audio optimizations, and more — matching upstream CachyOS defaults.

<!-- BEGIN generated:installation -->
## Installation

Add as a flake input:

```nix
{
  inputs.cachyos-settings = {
    url = "github:Daaboulex/cachyos-settings-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Import the NixOS module:

```nix
imports = [ inputs.cachyos-settings.nixosModules.default ];
```

<!-- END generated:installation -->

## Usage

Add to your flake inputs:

```nix
cachyos-settings-nix = {
  url = "github:Daaboulex/cachyos-settings-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Import the module:

```nix
modules = [
  inputs.cachyos-settings-nix.nixosModules.default
];
```

Enable in your configuration. Every area is opt-in; `enable` alone changes
nothing:

```nix
cachyos.settings = {
  enable = true;
  sysctl.enable = true;
  ioSchedulers.enable = true;
  audio.enable = true;
  serviceManager.enable = true;
  oomd.enable = true;
};
```

Every single-valued setting the module lands is a `lib.mkOverride 500`, the priority nixpkgs' own installer profiles and editor modules use: it beats the `mkDefault` values NixOS itself sets (`kernel.kptr_restrict`, `kernel.printk`), and a host overrides it with a plain line, while two modules that set the same value at the same priority fail evaluation as a conflict instead of one silently winning. The udev rules, modprobe lines, kernel module lists, tmpfiles rules and PAM limits stay at the default priority and merge with the host's own, as the module system does for lists and lines; a lower priority there would drop the module's whole contribution the moment any other module adds to the same option, so those are switched off with their area, never overridden.

## Options

Every option is a boolean that defaults to `false`. The last column names the upstream files each area ports, as paths in the CachyOS-Settings tree at the commit `upstream-version.json` pins.

| Option | Description | Upstream files |
|--------|-------------|----------------|
| `cachyos.settings.enable` | Lets the areas below apply; changes nothing on its own | |
| `sysctl.enable` | VM, kernel and network sysctls; swappiness 150 and zswap off once a zram device is up, whoever set zram up | `usr/lib/sysctl.d/70-cachyos-settings.conf`, `usr/lib/udev/rules.d/30-zram.rules` |
| `zram.enable` | zram swap: zstd, up to 100% of RAM, priority 100 | `usr/lib/systemd/zram-generator.conf` |
| `ioSchedulers.enable` | bfq for rotational disks, mq-deadline for SSD and eMMC, kyber for NVMe | `usr/lib/udev/rules.d/60-ioschedulers.rules` |
| `audio.enable` | PCI latency timers (80 cycles for sound cards, 20 for the rest), snd-hda-intel power saving off on AC, HPET/RTC and CPU DMA latency for the audio group, rtprio and nice limits, rtkit logging capped at info | `usr/lib/udev/rules.d/20-audio-pm.rules` with its `audio-pm-ctl` helper, `40-hpet-permissions.rules`, `99-cpu-dma-latency.rules`, `usr/lib/systemd/system/pci-latency.service`, `system/rtkit-daemon.service.d/override.conf`, `etc/security/limits.d/20-audio.conf` |
| `storage.enable` | SATA ALPM at max_performance, hdparm for rotational disks | `usr/lib/udev/rules.d/50-sata.rules`, `69-hdparm.rules` |
| `thp.enable` | THP defrag at defer+madvise, khugepaged shrinker | `usr/lib/tmpfiles.d/thp.conf`, `thp-shrinker.conf` |
| `ntsync.enable` | ntsync module for Wine and Proton | `usr/lib/modules-load.d/ntsync.conf` |
| `coredump.enable` | Core dumps removed after three days | `usr/lib/tmpfiles.d/coredump.conf` |
| `serviceManager.enable` | Start and stop timeouts and open-file limits for the system and user managers, cgroup delegation to user managers | `usr/lib/systemd/system.conf.d/00-timeout.conf`, `10-limits.conf`, `user.conf.d/00-timeout.conf`, `10-limits.conf`, `system/user@.service.d/delegate.conf` |
| `journal.enable` | System journal capped at 50M | `usr/lib/systemd/journald.conf.d/00-journal-size.conf` |
| `oomd.enable` | systemd-oomd slice policy; acts only while systemd-oomd runs, which NixOS does by default | `usr/lib/systemd/system/system.slice.d/10-oomd-per-slice-defaults.conf`, `user/slice.d/10-oomd-per-slice-defaults.conf`, `user/session.slice.d/10-ignore-session-slice.conf` |
| `watchdogBlacklist.enable` | Blacklist the iTCO, SP5100 and WDAT hardware watchdog drivers | `usr/lib/modprobe.d/blacklist.conf` |
| `nvidia.enable` | Runtime power management on bind, and `NVreg_InitializeSystemMemoryAllocations=0`, which skips zeroing freshly allocated system memory for speed | `usr/lib/udev/rules.d/71-nvidia.rules`, `usr/lib/modprobe.d/nvidia.conf` |

## Upstream Tracking

The last-mirrored upstream commit is recorded in `upstream-version.json`. A daily GitHub Action checks [CachyOS-Settings](https://github.com/CachyOS/CachyOS-Settings) master; because this module is a hand-port, it files one `remirror-needed` issue when upstream moves and keeps it open, with the days since it opened, until the marker is advanced.

Every value is upstream's, landed through the NixOS option that owns the file. It differs from upstream only here (re-check this list at each re-mirror):

- The watchdog blacklist is an area of its own; upstream always blacklists the drivers.
- SATA link power: `powerManagement.scsiLinkPolicy` writes `max_performance` to every `scsi_host` without upstream's `link_power_management_supported=="1"` guard. NixOS refuses it next to `services.tlp`, so a TLP host sets `powerManagement.scsiLinkPolicy = null` (keeping the hdparm rule) or `storage.enable = false`.
- The user manager's `slice.d` drop-in is shipped as the upstream file through `systemd.packages`, because NixOS has no option for a drop-in that applies to every slice.

Left to NixOS, which already has the switch (re-check at each re-mirror):

- `usr/lib/NetworkManager/conf.d/dns.conf`: NixOS points NetworkManager at systemd-resolved whenever `services.resolved.enable` is on.
- `usr/lib/modprobe.d/amdgpu.conf`: `hardware.amdgpu.legacySupport.enable` sets the same four parameters.
- `usr/lib/systemd/timesyncd.conf.d/10-timesyncd.conf`: NixOS runs timesyncd by default with its own pool; upstream's fallback servers are Arch's vendor zone, which belongs to Arch. Set `services.timesyncd.servers` for Cloudflare.
- The upstream package enabling `systemd-oomd`: NixOS enables it by default.
- `ananicy-cpp` with the CachyOS rules, which the upstream package depends on: `services.ananicy` with `rulesProvider = pkgs.ananicy-rules-cachyos`.

Deliberately not ported, because they do nothing useful on NixOS (re-check this list at each re-mirror):

- `usr/bin` user tools (`game-performance`, `cachyos-bugreport.sh`, `dlss-swapper`, `dlss-swapper-dll`, `kerver`, `paste-cachyos`, `sbctl-batch-sign`, `topmem`, `zink-run`): launchers and tools built around pacman and CachyOS's paste service; `pci-latency` is the exception, ported as a systemd service.
- Wireless regdomain automation (`usr/lib/iw-set-regdomain`, `85-iw-regulatory.rules`, `cachyos-iw-set-regdomain.{path,service}`): set the regulatory domain declaratively instead.
- The xswap generator and its `systemd-zram-setup@.service` drop-in: they act only on a kernel exposing `/sys/kernel/mm/xswap`, a patch series neither mainline nor the CachyOS 7.3 kernel carries.
- `fs.file-max = 2097152` from the sysctl file: systemd already raises the limit to its maximum at boot, so upstream's value lowers it.
- `kernel.unprivileged_userns_clone = 1` from the sysctl file: the key exists only on patched kernels, where 1 is already the default (CachyOS 7.3 `kernel/fork.c:135`).
- GNOME/GDM branding (`usr/share/glib-2.0/.../login-screen` override, `usr/share/icons/cachyos.svg`).
- X11 touchpad defaults (`usr/share/X11/xorg.conf.d/20-touchpad.conf`): NixOS's libinput already enables tap-to-click.
- The debuginfod server URL (`etc/debuginfod/cachyos.urls`): the server indexes CachyOS and Arch build ids; a binary built by Nix never matches, so every lookup would only wait for a 404.

## Development

```bash
git clone https://github.com/Daaboulex/cachyos-settings-nix
cd cachyos-settings-nix
nix develop                       # enter dev shell, installs pre-commit hooks
nix fmt                           # format flake + module
nix flake check --no-build        # eval check (canonical CI gate, module-only repo)
```

The daily `.github/workflows/update.yml` only DETECTS upstream movement (it opens a `remirror-needed` issue); re-porting the module is a manual step.

<!-- BEGIN generated:options -->
<!-- END generated:options -->

## License

This packaging flake is [GPL-3.0](./LICENSE) licensed (matches upstream). Upstream CachyOS-Settings is [GPL-3.0](https://github.com/CachyOS/CachyOS-Settings/blob/master/LICENSE).

<!-- BEGIN generated:footer -->
<!-- END generated:footer -->
