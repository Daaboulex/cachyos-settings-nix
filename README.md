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

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `cachyos.settings.enable` | `false` | Master toggle |
| `zram.enable` | `true` | ZRAM swap (zstd, 100% RAM), handed to xswap on a kernel that provides it |
| `ioSchedulers.enable` | `true` | I/O scheduler udev rules |
| `audio.enable` | `true` | Audio optimizations |
| `storage.enable` | `true` | SATA ALPM + hdparm |
| `thp.enable` | `true` | THP defrag + khugepaged |
| `systemd.enable` | `true` | Systemd timeouts, limits, delegation, systemd-oomd slice policy (acts only while systemd-oomd runs, which NixOS does by default; the module does not switch it on) |
| `timesyncd.enable` | `true` | NTP (Cloudflare + NixOS pool) |
| `networkManager.enable` | `true` | DNS via systemd-resolved |
| `ntsync.enable` | `true` | NT sync module for Wine/Proton |
| `debuginfod.enable` | `true` | CachyOS debuginfod server |
| `coredump.enable` | `true` | Coredump cleanup (3-day) |
| `watchdog.enable` | `false` | Keep the iTCO, SP5100 and WDAT watchdog drivers upstream blacklists |
| `nvidia.enable` | `false` | NVIDIA modprobe + udev tuning |
| `amdgpuGcnCompat.enable` | `false` | Force amdgpu for GCN 1.0+/2.x |

## Upstream Tracking

The last-mirrored upstream commit is recorded in `upstream-version.json`. A daily GitHub Action checks [CachyOS-Settings](https://github.com/CachyOS/CachyOS-Settings) master; because this module is a hand-port (not a fetched build), it files a `remirror-needed` issue when upstream moves rather than auto-updating.

Diverges from upstream only where upstream's value would break NixOS or cannot apply on it; everything else is ported as upstream ships it (re-check this list at each re-mirror):

- `vm.swappiness`: upstream's `70-cachyos-settings.conf` sets a flat 100 and its `30-zram.rules` raises it to 150 once zram0 initialises. The module sets 150 whenever its ZRAM half is on, to prefer compressing anonymous pages over evicting file cache, and 100 otherwise.
- `kernel.unprivileged_userns_clone`: written as `-kernel.unprivileged_userns_clone`. The key comes from a CachyOS/Debian kernel patch, and the leading `-` makes systemd-sysctl skip it on a stock kernel (where unprivileged user namespaces are already on) instead of failing at activation.
- Watchdog blacklist (`iTCO_wdt`, `sp5100_tco`, `wdat_wdt` from `modprobe.d/blacklist.conf`): upstream always blacklists them. The module does so unless `watchdog.enable` is set, so a host that needs its hardware watchdog can keep it.

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
