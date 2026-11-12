# What comes from upstream

Every file of [CachyOS/CachyOS-Settings](https://github.com/CachyOS/CachyOS-Settings) and what this module does with it, at the commit [upstream-version.json](../upstream-version.json) records. This page is generated from that file: change a decision there, then run `nix run .#write-upstream-page`.

## Ported

| Upstream file | Option under `cachyos.settings` |
|---|---|
| `etc/security/limits.d/20-audio.conf` | `audio.enable` |
| `usr/bin/pci-latency` | `audio.enable` |
| `usr/lib/modprobe.d/blacklist.conf` | `watchdogBlacklist.enable` |
| `usr/lib/modprobe.d/nvidia.conf` | `nvidia.enable` |
| `usr/lib/modules-load.d/ntsync.conf` | `ntsync.enable` |
| `usr/lib/sysctl.d/70-cachyos-settings.conf` | `sysctl.enable` |
| `usr/lib/systemd/journald.conf.d/00-journal-size.conf` | `journal.enable` |
| `usr/lib/systemd/system.conf.d/00-timeout.conf` | `serviceManager.enable` |
| `usr/lib/systemd/system.conf.d/10-limits.conf` | `serviceManager.enable` |
| `usr/lib/systemd/system/pci-latency.service` | `audio.enable` |
| `usr/lib/systemd/system/rtkit-daemon.service.d/override.conf` | `audio.enable` |
| `usr/lib/systemd/system/system.slice.d/10-oomd-per-slice-defaults.conf` | `oomd.enable` |
| `usr/lib/systemd/system/user@.service.d/delegate.conf` | `serviceManager.enable` |
| `usr/lib/systemd/user-generators/cachyos-oomd-generator` | `oomd.enable` |
| `usr/lib/systemd/user.conf.d/00-timeout.conf` | `serviceManager.enable` |
| `usr/lib/systemd/user.conf.d/10-limits.conf` | `serviceManager.enable` |
| `usr/lib/systemd/user/session.slice.d/10-ignore-session-slice.conf` | `oomd.enable` |
| `usr/lib/systemd/zram-generator.conf` | `zram.enable` |
| `usr/lib/tmpfiles.d/coredump.conf` | `coredump.enable` |
| `usr/lib/tmpfiles.d/thp-shrinker.conf` | `thp.enable` |
| `usr/lib/tmpfiles.d/thp.conf` | `thp.enable` |
| `usr/lib/udev/audio-pm-ctl` | `audio.enable` |
| `usr/lib/udev/rules.d/20-audio-pm.rules` | `audio.enable` |
| `usr/lib/udev/rules.d/30-zram.rules` | `sysctl.enable` |
| `usr/lib/udev/rules.d/40-hpet-permissions.rules` | `audio.enable` |
| `usr/lib/udev/rules.d/50-sata.rules` | `storage.enable` |
| `usr/lib/udev/rules.d/60-ioschedulers.rules` | `ioSchedulers.enable` |
| `usr/lib/udev/rules.d/61-writeback-limits.rules` | `sysctl.enable` |
| `usr/lib/udev/rules.d/69-hdparm.rules` | `storage.enable` |
| `usr/lib/udev/rules.d/71-nvidia.rules` | `nvidia.enable` |
| `usr/lib/udev/rules.d/99-cpu-dma-latency.rules` | `audio.enable` |

## Left to NixOS

| Upstream file | Why |
|---|---|
| `usr/lib/NetworkManager/conf.d/dns.conf` | NixOS points NetworkManager at systemd-resolved whenever services.resolved.enable is on. |
| `usr/lib/modprobe.d/amdgpu.conf` | hardware.amdgpu.legacySupport.enable sets the same four parameters. |
| `usr/lib/systemd/timesyncd.conf.d/10-timesyncd.conf` | NixOS runs timesyncd by default with its own pool. Upstream's fallback servers are Arch's vendor zone, which belongs to Arch. |

## Not ported

| Upstream file | Why |
|---|---|
| `CODE_OF_CONDUCT.md` | Upstream's own project page. |
| `CONTRIBUTING.md` | Upstream's own project page. |
| `LICENSE.md` | Upstream's own project page. |
| `README.md` | Upstream's own project page. |
| `etc/debuginfod/cachyos.urls` | The server indexes CachyOS and Arch build ids. A binary built by Nix never matches, so every lookup would only wait for a 404. |
| `usr/bin/cachyos-bugreport.sh` | A tool built around pacman and CachyOS's paste service. |
| `usr/bin/dlss-swapper` | A launcher built around CachyOS's package layout. |
| `usr/bin/dlss-swapper-dll` | A launcher built around CachyOS's package layout. |
| `usr/bin/eac-setup` | Easy Anti-Cheat Linux v2 needs a boot signed by CachyOS's certificate and the linux-cachyos-eac kernel. A NixOS boot has neither. |
| `usr/bin/eac-status` | Easy Anti-Cheat Linux v2 needs a boot signed by CachyOS's certificate and the linux-cachyos-eac kernel. A NixOS boot has neither. |
| `usr/bin/game-performance` | A launcher built around CachyOS's package layout. |
| `usr/bin/kerver` | A tool built around pacman. |
| `usr/bin/paste-cachyos` | A client for CachyOS's paste service. |
| `usr/bin/sbctl-batch-sign` | A tool built around pacman and sbctl. |
| `usr/bin/topmem` | A user tool, not a setting. |
| `usr/bin/zink-run` | A launcher, not a setting. |
| `usr/lib/iw-set-regdomain` | Set the wireless regulatory domain declaratively instead. |
| `usr/lib/systemd/system-generators/xswap-generator` | It acts only on a kernel exposing /sys/kernel/mm/xswap, a patch series neither mainline nor the CachyOS kernel carries. |
| `usr/lib/systemd/system/cachyos-iw-set-regdomain.path` | Set the wireless regulatory domain declaratively instead. |
| `usr/lib/systemd/system/cachyos-iw-set-regdomain.service` | Set the wireless regulatory domain declaratively instead. |
| `usr/lib/systemd/system/systemd-zram-setup@.service.d/xswap.conf` | It acts only on a kernel exposing /sys/kernel/mm/xswap, a patch series neither mainline nor the CachyOS kernel carries. |
| `usr/lib/udev/rules.d/85-iw-regulatory.rules` | Set the wireless regulatory domain declaratively instead. |
| `usr/share/X11/xorg.conf.d/20-touchpad.conf` | NixOS's libinput already enables tap-to-click. |
| `usr/share/glib-2.0/schemas/zz_cachyos.org.gnome.login-screen.gschema.override` | GNOME and GDM branding. |
| `usr/share/icons/cachyos.svg` | GNOME and GDM branding. |
