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
- **Module-instantiation check.** The `module-eval` check instantiates a full NixOS system with every area on, so evaluation and assertion errors of the full system surface. It activates nothing.

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

Except for the three named next, every single-valued setting the module lands is a `lib.mkOverride 500`, the priority nixpkgs' own installer profiles and editor modules use: it beats the `mkDefault` values NixOS itself sets (`kernel.kptr_restrict`, `kernel.printk`), and a host overrides it with a plain line, while two modules that set the same value at the same priority fail evaluation as a conflict instead of one silently winning. The exceptions sit at the default priority: `zramSwap.enable`, the `overrideStrategy = "asDropin"` of the four systemd units the module adds a drop-in to (`rtkit-daemon`, `user@`, `system.slice` and the user manager's `session.slice`), and the `pci-latency` service, which the module defines itself. The udev rules, modprobe lines, kernel module lists, tmpfiles rules and PAM limits stay at the default priority and merge with the host's own, as the module system does for lists and lines; a lower priority there would drop the module's whole contribution the moment any other module adds to the same option, so those are switched off with their area, never overridden.

## Options

Every option is a boolean under `cachyos.settings` that defaults to `false`, and [module.nix](./module.nix) declares each one with its description. Which upstream file each area ports, and which files are left to NixOS or not ported at all, is in [docs/UPSTREAM.md](docs/UPSTREAM.md).

## Upstream Tracking

The last-mirrored upstream commit is recorded in [upstream-version.json](./upstream-version.json). A daily GitHub Action checks [CachyOS-Settings](https://github.com/CachyOS/CachyOS-Settings) master; because this module is a hand-port, it files one `remirror-needed` issue when upstream moves and keeps it open, with the days since it opened, until the marker is advanced.

Every value is upstream's, landed through the NixOS option that owns the file. It differs from upstream only here:

- The watchdog blacklist is an area of its own; upstream always blacklists the drivers.
- SATA link power: `powerManagement.scsiLinkPolicy` writes `max_performance` to every `scsi_host` without upstream's `link_power_management_supported=="1"` guard. NixOS refuses it next to `services.tlp`, so a TLP host sets `powerManagement.scsiLinkPolicy = null` (keeping the hdparm rule) or `storage.enable = false`.
- The oomd generator is the upstream script with `coreutils` pinned from the store and without the comment line it writes into the drop-in.

## Development

```bash
git clone https://github.com/Daaboulex/cachyos-settings-nix
cd cachyos-settings-nix
nix develop                       # enter dev shell, installs pre-commit hooks
nix fmt                           # format flake + module
nix flake check --no-eval-cache
```

`nix flake check --no-eval-cache` is the gate. It builds every check of the flake, among them `module-eval` and `oomd-user-dropins`.

The daily [.github/workflows/update.yml](./.github/workflows/update.yml) only DETECTS upstream movement (it opens a `remirror-needed` issue); re-porting the module is a manual step.

<!-- BEGIN generated:options -->
<!-- END generated:options -->

## License

This packaging flake is [GPL-3.0](./LICENSE) licensed (matches upstream). Upstream CachyOS-Settings is [GPL-3.0](https://github.com/CachyOS/CachyOS-Settings/blob/master/LICENSE).

<!-- BEGIN generated:footer -->
<!-- END generated:footer -->
