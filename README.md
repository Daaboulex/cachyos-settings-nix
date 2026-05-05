# cachyos-settings-nix

<!-- BEGIN generated:badges -->
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
- **Weekly upstream tracking** — GitHub Action diffs `CachyOS-Settings` master every Monday and opens PRs on change
- **Scoped sub-toggles** — every concern (`zram`, `ioSchedulers`, `audio`, `storage`, `thp`, `systemd`, `timesyncd`, `networkManager`, `ntsync`, `debuginfod`, `coredump`, `nvidia`, `amdgpuGcnCompat`) is independently toggleable
- **Eval-only verification** — `nix flake check --no-build` is the canonical CI gate

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
  # All sub-options default to true except GPU-specific ones:
  # nvidia.enable = false;        # Enable for NVIDIA GPUs
  # amdgpuGcnCompat.enable = false; # Enable for GCN 1.0/2.x GPUs
};
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `cachyos.settings.enable` | `false` | Master toggle |
| `zram.enable` | `true` | ZRAM swap (zstd, 100% RAM) |
| `ioSchedulers.enable` | `true` | I/O scheduler udev rules |
| `audio.enable` | `true` | Audio optimizations |
| `storage.enable` | `true` | SATA ALPM + hdparm |
| `thp.enable` | `true` | THP defrag + khugepaged |
| `systemd.enable` | `true` | Systemd timeouts, limits, delegation |
| `timesyncd.enable` | `true` | NTP (Cloudflare + NixOS pool) |
| `networkManager.enable` | `true` | DNS via systemd-resolved |
| `ntsync.enable` | `true` | NT sync module for Wine/Proton |
| `debuginfod.enable` | `true` | CachyOS debuginfod server |
| `coredump.enable` | `true` | Coredump cleanup (3-day) |
| `nvidia.enable` | `false` | NVIDIA modprobe + udev tuning |
| `amdgpuGcnCompat.enable` | `false` | Force amdgpu for GCN 1.0+/2.x |

## Upstream Tracking

Pinned upstream version is tracked in `upstream-version.json`. A weekly GitHub Action checks for upstream changes and opens PRs when the [CachyOS-Settings](https://github.com/CachyOS/CachyOS-Settings) repo updates.

## Development

```bash
git clone https://github.com/Daaboulex/cachyos-settings-nix
cd cachyos-settings-nix
nix develop                       # enter dev shell, installs pre-commit hooks
nix fmt                           # format flake + module
nix flake check --no-build        # eval check (canonical CI gate, module-only repo)
```

CI runs the same chain weekly via `.github/workflows/update.yml`; manual updates rarely needed.

<!-- BEGIN generated:options -->
<!-- END generated:options -->

## License

This packaging flake is [GPL-3.0](./LICENSE) licensed (matches upstream). Upstream CachyOS-Settings is [GPL-3.0](https://github.com/CachyOS/CachyOS-Settings/blob/master/LICENSE).

<!-- BEGIN generated:footer -->
---

*Maintained as part of the [Daaboulex](https://github.com/Daaboulex) NixOS ecosystem.*
<!-- END generated:footer -->
