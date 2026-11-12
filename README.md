# cachyos-settings-nix

The system tuning of [CachyOS-Settings](https://github.com/CachyOS/CachyOS-Settings),
ported by hand to a NixOS module: sysctl values, udev rules, systemd limits,
zram, transparent huge pages and I/O schedulers.

It is a module only, with no package. Nothing is switched on until you pick
an area.

## Install

Add the flake:

```nix
{
  inputs.cachyos-settings = {
    url = "github:Daaboulex/cachyos-settings-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Import the module:

```nix
imports = [ inputs.cachyos-settings.nixosModules.default ];
```

## Use

Switch on the areas you want. `enable` on its own changes nothing.

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

The areas are `sysctl`, `zram`, `ioSchedulers`, `audio`, `storage`, `thp`,
`ntsync`, `coredump`, `serviceManager`, `journal`, `oomd`, `watchdogBlacklist`
and `nvidia`. What each one sets is in [docs/OPTIONS.md](docs/OPTIONS.md).

## Changing a value

A single value the module sets is weaker than a plain line in your own
configuration, so setting the same NixOS option yourself wins. The three
exceptions are named in [docs/DESIGN.md](docs/DESIGN.md).

The lists the module adds to (udev rules, modprobe lines, kernel modules,
tmpfiles rules and PAM limits) merge with yours. To drop those, switch the
area off.

## Known limits

- `storage.enable` sets the SATA link power policy, which NixOS refuses next
  to `services.tlp`. On a TLP machine set
  `powerManagement.scsiLinkPolicy = null`, which keeps the hdparm rule, or
  leave `storage.enable` off.
- `oomd.enable` only sets the policy. It acts while `systemd-oomd` runs.
- Not everything upstream ships is ported. Some files are left to NixOS, which
  already has the switch, and some do nothing useful on NixOS. The full list,
  file by file: [docs/UPSTREAM.md](docs/UPSTREAM.md).

## Following upstream

A daily job watches CachyOS-Settings. When upstream changes a file this module
ports, it opens an issue that names the file and shows the change, and a
person ports it. A change that touches only files nobody ported moves the
recorded commit by itself.

## More

- [docs/OPTIONS.md](docs/OPTIONS.md): every option with its description
- [docs/UPSTREAM.md](docs/UPSTREAM.md): every upstream file and what happens
  to it
- [docs/DESIGN.md](docs/DESIGN.md): how values are set so that yours win, and
  where the module differs from upstream
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md): the checks, and how to port an
  upstream change

## License

This packaging flake is [GPL-3.0](./LICENSE) licensed (matches upstream). Upstream CachyOS-Settings is [GPL-3.0](https://github.com/CachyOS/CachyOS-Settings/blob/master/LICENSE).
