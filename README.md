# cachyos-settings-nix

[CachyOS-Settings](https://github.com/CachyOS/CachyOS-Settings) ported as a standalone NixOS module.

Provides sysctl tuning, udev rules, systemd tweaks, ZRAM, THP, I/O schedulers, audio optimizations, and more — matching upstream CachyOS defaults.

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

## License

GPL-3.0 (matching upstream CachyOS-Settings).
