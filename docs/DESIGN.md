# Design

Why the module is built the way it is. The [README](../README.md) says how to use it.

## How values are set so that yours win

Except for the three named next, every single-valued setting the module lands is a `lib.mkOverride 500`, the priority nixpkgs' own installer profiles and editor modules use: it beats the `mkDefault` values NixOS itself sets (`kernel.kptr_restrict`, `kernel.printk`), and a host overrides it with a plain line, while two modules that set the same value at the same priority fail evaluation as a conflict instead of one silently winning. The exceptions sit at the default priority: `zramSwap.enable`, the `overrideStrategy = "asDropin"` of the four systemd units the module adds a drop-in to (`rtkit-daemon`, `user@`, `system.slice` and the user manager's `session.slice`), and the `pci-latency` service, which the module defines itself. The udev rules, modprobe lines, kernel module lists, tmpfiles rules and PAM limits stay at the default priority and merge with the host's own, as the module system does for lists and lines; a lower priority there would drop the module's whole contribution the moment any other module adds to the same option, so those are switched off with their area, never overridden.

## Where the module differs from upstream

Every value is upstream's, landed through the NixOS option that owns the file. It differs from upstream only here:

- The watchdog blacklist is an area of its own; upstream always blacklists the drivers.
- SATA link power: `powerManagement.scsiLinkPolicy` writes `max_performance` to every `scsi_host` without upstream's `link_power_management_supported=="1"` guard. NixOS refuses it next to `services.tlp`, so a TLP host sets `powerManagement.scsiLinkPolicy = null` (keeping the hdparm rule) or `storage.enable = false`.
- The oomd generator is the upstream script with `coreutils` pinned from the store and without the comment line it writes into the drop-in.

Which upstream file each area ports, and which files are left to NixOS or not ported, is in [UPSTREAM.md](UPSTREAM.md).
