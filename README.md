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
- **Scoped sub-toggles** — every concern (`zram`, `ioSchedulers`, `audio`, `storage`, `thp`, `systemd`, `timesyncd`, `networkManager`, `ntsync`, `debuginfod`, `coredump`, `watchdog`, `nvidia`, `amdgpuGcnCompat`) is independently toggleable
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

Enable in your configuration:

```nix
cachyos.settings = {
  enable = true;
  # All sub-options default to true except GPU-specific ones and watchdog:
  # nvidia.enable = false;        # Enable for NVIDIA GPUs
  # amdgpuGcnCompat.enable = false; # Enable for GCN 1.0/2.x GPUs
  # watchdog.enable = false;      # Enable to keep the iTCO/SP5100/WDAT hardware watchdog upstream blacklists
};
```

Every single-valued setting the module lands is a `lib.mkOverride 500`, the priority nixpkgs' own installer profiles and editor modules use: it beats the `mkDefault` values NixOS itself sets (`kernel.kptr_restrict`, `kernel.printk`), and a host overrides it with a plain line, while two modules that set the same value at the same priority fail evaluation as a conflict instead of one silently winning. The udev rules, modprobe lines, kernel module lists, tmpfiles rules, PAM limits and debuginfod servers stay at the default priority and merge with the host's own, as the module system does for lists and lines; a lower priority there would drop the module's whole contribution the moment any other module adds to the same option, so those are switched off with their toggle, never overridden.

## Options

The last column names the upstream files each toggle ports, as paths in the CachyOS-Settings tree at the commit `upstream-version.json` pins.

| Option | Default | Description | Upstream files |
|--------|---------|-------------|----------------|
| `cachyos.settings.enable` | `false` | Master toggle; the sysctls, and the zram0 rule whenever `zramSwap.enable` is on, whoever set it | `usr/lib/sysctl.d/70-cachyos-settings.conf`, `usr/lib/udev/rules.d/30-zram.rules` |
| `zram.enable` | `true` | ZRAM swap (zstd, 100% RAM), handed to xswap on a kernel that provides it | `usr/lib/systemd/zram-generator.conf`, the xswap generator and its `systemd-zram-setup@.service` drop-in |
| `ioSchedulers.enable` | `true` | I/O scheduler udev rules: bfq for rotational disks, mq-deadline for SSD and eMMC, kyber for NVMe | `usr/lib/udev/rules.d/60-ioschedulers.rules` |
| `audio.enable` | `true` | Audio optimizations: PCI latency timers (80 cycles for sound cards, 20 for the rest), snd-hda-intel power saving off on AC, HPET/RTC and CPU DMA latency for the audio group, rtprio and nice limits | `usr/lib/udev/rules.d/20-audio-pm.rules` with its `audio-pm-ctl` helper, `40-hpet-permissions.rules`, `99-cpu-dma-latency.rules`, `usr/lib/systemd/system/pci-latency.service`, `etc/security/limits.d/20-audio.conf` |
| `storage.enable` | `true` | SATA ALPM + hdparm | `usr/lib/udev/rules.d/50-sata.rules`, `69-hdparm.rules` |
| `thp.enable` | `true` | THP defrag + khugepaged | `usr/lib/tmpfiles.d/thp.conf`, `thp-shrinker.conf` |
| `systemd.enable` | `true` | Systemd timeouts, limits, delegation, systemd-oomd slice policy (acts only while systemd-oomd runs, which NixOS does by default; the module does not switch it on) | `usr/lib/systemd/journald.conf.d/00-journal-size.conf`, `system.conf.d/00-timeout.conf`, `system.conf.d/10-limits.conf`, `user.conf.d/00-timeout.conf`, `user.conf.d/10-limits.conf`, `system/user@.service.d/delegate.conf`, `system/rtkit-daemon.service.d/override.conf`, `system/system.slice.d/10-oomd-per-slice-defaults.conf`, `system/user-.slice.d/10-oomd-per-slice-defaults.conf`, `user/session.slice.d/10-ignore-session-slice.conf` |
| `timesyncd.enable` | `true` | NTP (Cloudflare, with Google and the Arch pool as fallback) | `usr/lib/systemd/timesyncd.conf.d/10-timesyncd.conf` |
| `networkManager.enable` | `true` | DNS via systemd-resolved | `usr/lib/NetworkManager/conf.d/dns.conf` |
| `ntsync.enable` | `true` | NT sync module for Wine/Proton | `usr/lib/modules-load.d/ntsync.conf` |
| `debuginfod.enable` | `true` | CachyOS debuginfod server | `etc/debuginfod/cachyos.urls` |
| `coredump.enable` | `true` | Coredump cleanup (3-day) | `usr/lib/tmpfiles.d/coredump.conf` |
| `watchdog.enable` | `false` | Keep the iTCO, SP5100 and WDAT watchdog drivers upstream blacklists | `usr/lib/modprobe.d/blacklist.conf` |
| `nvidia.enable` | `false` | NVIDIA modprobe + udev tuning | `usr/lib/udev/rules.d/71-nvidia.rules`, `usr/lib/modprobe.d/nvidia.conf` |
| `amdgpuGcnCompat.enable` | `false` | Force amdgpu for GCN 1.0+/2.x | `usr/lib/modprobe.d/amdgpu.conf` |

## Upstream Tracking

The last-mirrored upstream commit is recorded in `upstream-version.json`. A daily GitHub Action checks [CachyOS-Settings](https://github.com/CachyOS/CachyOS-Settings) master; because this module is a hand-port (not a fetched build), it files a `remirror-needed` issue when upstream moves rather than auto-updating.

Every value is upstream's, landed through the NixOS option that owns the file. It differs from upstream only here (re-check this list at each re-mirror):

- `kernel.unprivileged_userns_clone`: written as `-kernel.unprivileged_userns_clone`. The key comes from a CachyOS/Debian kernel patch, and the leading `-` makes systemd-sysctl skip it on a stock kernel (where unprivileged user namespaces are already on) instead of failing at activation.
- Watchdog blacklist (`iTCO_wdt`, `sp5100_tco`, `wdat_wdt` from `modprobe.d/blacklist.conf`): upstream always blacklists them. The module does so unless `watchdog.enable` is set, so a host that needs its hardware watchdog can keep it.
- SATA link power: `powerManagement.scsiLinkPolicy` writes `max_performance` to every `scsi_host` without upstream's `link_power_management_supported=="1"` guard. NixOS refuses it next to `services.tlp`, so a TLP host sets `powerManagement.scsiLinkPolicy = null` (keeping the hdparm rule) or `storage.enable = false`.

Deliberately not ported (outside the module's settings scope; re-check this list at each re-mirror):

- `usr/bin` user tools (`game-performance`, `cachyos-bugreport.sh`, `dlss-swapper`, `dlss-swapper-dll`, `kerver`, `paste-cachyos`, `sbctl-batch-sign`, `topmem`, `zink-run`) -- interactive tools, not system settings; `pci-latency` is the exception, ported as a systemd service.
- Wireless regdomain automation (`usr/lib/iw-set-regdomain`, `85-iw-regulatory.rules`, `cachyos-iw-set-regdomain.{path,service}`) -- on NixOS set the regulatory domain declaratively instead.
- GNOME/GDM branding (`usr/share/glib-2.0/.../login-screen` override, `usr/share/icons/cachyos.svg`).
- X11 touchpad defaults (`usr/share/X11/xorg.conf.d/20-touchpad.conf`) -- use `services.libinput` options.

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
