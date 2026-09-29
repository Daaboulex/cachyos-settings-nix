{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cachyos.settings;

  # PCI latency script from CachyOS
  # Sets sound card PCI latency to 80 cycles for reduced audio latency
  # Resets all other devices to 20 cycles to prevent gaps
  pciLatencyScript = pkgs.writeShellScript "pci-latency" ''
    if [ "$(id -u)" -ne 0 ]; then
      echo "Error: This script must be run with root privileges." >&2
      exit 1
    fi
    ${pkgs.pciutils}/bin/setpci -v -s '*:*' latency_timer=20
    ${pkgs.pciutils}/bin/setpci -v -s '0:0' latency_timer=0
    ${pkgs.pciutils}/bin/setpci -v -d '*:*:04xx' latency_timer=80
  '';

  audioPmCtl = pkgs.writeShellApplication {
    name = "audio-pm-ctl";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnugrep
    ];
    inheritPath = false;
    bashOptions = [ ];
    text = ''
      declare -r PARAM=/sys/module/snd_hda_intel/parameters/power_save
      declare -r STATE=/run/udev/snd-hda-intel-powersave

      save() {
          local cur
          cur="$(cat "$PARAM")"
          [[ "$cur" != 0 ]] && echo "$cur" > "$STATE"
          return 0
      }

      is_on_ac() {
          local d online
          while IFS= read -r d; do
              online="$(cat "''${d/type/online}" 2>/dev/null)"
              [[ "$online" == 1 ]] || return 1
          done < <(grep -l "Mains" /sys/class/power_supply/*/type 2>/dev/null)
          return 0
      }

      do_init() {
          is_on_ac || return 0
          save
          echo 0 > "$PARAM"
      }

      do_battery() {
          local v
          v="$(cat "$STATE" 2>/dev/null)"
          [[ -n "$v" ]] || v=10
          echo "$v" > "$PARAM"
      }

      do_ac() {
          save
          echo 0 > "$PARAM"
      }

      usage() {
          echo "Usage: $0 {init|battery|ac}" >&2
          exit 1
      }

      main() {
          case "$1" in
              init)    do_init ;;
              battery) do_battery ;;
              ac)      do_ac ;;
              *)       usage ;;
          esac
      }

      main "$@"
    '';
  };

  xswapGenerator = pkgs.writeScript "xswap-generator" ''
    #!${pkgs.bashInteractive}/bin/bash
    if [[ -e /sys/kernel/mm/xswap && ! -n "$(compgen -G '/sys/kernel/mm/xswap/type*')" ]]; then
        ${pkgs.coreutils}/bin/ln -s /dev/null /run/systemd/zram-generator.conf
        echo 100 > /sys/kernel/mm/xswap/create
    fi
  '';

  oomdPerSliceDefaults = ''
    [Slice]
    ManagedOOMSwap=kill
    ManagedOOMMemoryPressure=kill
    ManagedOOMMemoryPressureLimit=80%
  '';
in
{
  # ==================================================================
  # Options
  # ==================================================================
  options.cachyos.settings = {
    enable = lib.mkEnableOption "CachyOS system optimizations (upstream-matched settings)";

    # --- Upstream CachyOS-Settings groups ---
    zram.enable =
      lib.mkEnableOption "ZRAM swap (zstd, 100% RAM), handed to xswap on a kernel that provides it"
      // {
        default = true;
      };
    ioSchedulers.enable = lib.mkEnableOption "I/O scheduler udev rules (bfq/mq-deadline/none)" // {
      default = true;
    };
    audio.enable =
      lib.mkEnableOption "Audio optimizations (PCI latency, power save, HPET/RTC perms, CPU DMA latency, PAM rtprio/nice)"
      // {
        default = true;
      };
    storage.enable = lib.mkEnableOption "SATA ALPM + hdparm for rotational disks" // {
      default = true;
    };
    thp.enable =
      lib.mkEnableOption "THP defrag (defer+madvise) and khugepaged shrinker (kernel 6.12+)"
      // {
        default = true;
      };
    systemd.enable =
      lib.mkEnableOption "Systemd timeouts, NOFILE limits, journal size, cgroup delegation, rtkit, systemd-oomd slice policy"
      // {
        default = true;
      };
    timesyncd.enable = lib.mkEnableOption "NTP time synchronization (Cloudflare + NixOS pool)" // {
      default = true;
    };
    networkManager.enable = lib.mkEnableOption "NetworkManager DNS via systemd-resolved" // {
      default = true;
    };
    ntsync.enable = lib.mkEnableOption "NT sync kernel module for Wine/Proton" // {
      default = true;
    };
    debuginfod.enable = lib.mkEnableOption "CachyOS debuginfod symbol server" // {
      default = true;
    };
    coredump.enable = lib.mkEnableOption "Coredump cleanup (3-day retention)" // {
      default = true;
    };
    watchdog.enable = lib.mkEnableOption "the iTCO, SP5100 and WDAT hardware watchdog drivers, which upstream blacklists";

    # --- GPU-specific (off by default) ---
    nvidia.enable = lib.mkEnableOption "NVIDIA modprobe + udev tuning (runtime PM, power management)";
    amdgpuGcnCompat.enable = lib.mkEnableOption "Force amdgpu driver for GCN 1.0+ (SI) and GCN 2.x (CIK) GPUs";
  };

  # ==================================================================
  # Config
  # ==================================================================
  config = lib.mkIf cfg.enable (
    lib.mkMerge [

      # ================================================================
      # Core Sysctls — always on with top-level enable
      # Source: usr/lib/sysctl.d/70-cachyos-settings.conf
      # ================================================================
      {
        boot.kernel.sysctl = {
          # Memory & I/O Management
          "vm.swappiness" = if cfg.zram.enable then 150 else 100;
          # Lower VFS cache pressure to keep directory/inode caches longer
          "vm.vfs_cache_pressure" = 50;
          # Process starts writing dirty data at 256MB
          "vm.dirty_bytes" = 268435456;
          # Background flusher starts at 64MB
          "vm.dirty_background_bytes" = 67108864;
          # Flusher wakeup interval: 15 seconds
          "vm.dirty_writeback_centisecs" = 1500;
          # Disable swap readahead clustering (optimal for ZRAM/SSD)
          "vm.page-cluster" = 0;

          # System Stability & Security
          # Disable NMI watchdog (performance + power saving)
          "kernel.nmi_watchdog" = 0;
          "-kernel.unprivileged_userns_clone" = 1;
          # Hide kernel messages from console
          "kernel.printk" = "3 3 3 3";
          # Restrict kernel pointer exposure in /proc
          "kernel.kptr_restrict" = 2;
          "kernel.sysrq" = 1;

          # Network
          # Increase network device backlog queue
          "net.core.netdev_max_backlog" = 4096;

          # Filesystem
          # Increase maximum open file handles
          "fs.file-max" = 2097152;
        };
      }

      # Source: usr/lib/modprobe.d/blacklist.conf
      (lib.mkIf (!cfg.watchdog.enable) {
        boot.blacklistedKernelModules = [
          "iTCO_wdt"
          "sp5100_tco"
          "wdat_wdt"
        ];
      })

      # ================================================================
      # ZRAM Swap
      # Source: usr/lib/systemd/zram-generator.conf
      # ================================================================
      (lib.mkIf cfg.zram.enable {
        zramSwap = {
          enable = true;
          algorithm = "zstd";
          memoryPercent = 100;
          priority = 100;
        };

        # Source: usr/lib/udev/rules.d/30-zram.rules
        # When ZRAM is active, override swappiness to 150 and disable zswap
        services.udev.extraRules = ''
          ACTION=="change", KERNEL=="zram0", ATTR{initstate}=="1", SYSCTL{vm.swappiness}="150", RUN+="${pkgs.bash}/bin/bash -c 'echo N > /sys/module/zswap/parameters/enabled'"
        '';

        systemd.generators.xswap-generator = "${xswapGenerator}";
        systemd.packages = [
          (pkgs.writeTextDir "lib/systemd/system/systemd-zram-setup@.service.d/xswap.conf" ''
            [Unit]
            ConditionPathExistsGlob=!/sys/kernel/mm/xswap/type*
          '')
        ];
      })

      # ================================================================
      # Udev: Audio Power Management + Device Permissions
      # Source: usr/lib/udev/rules.d/20-audio-pm.rules
      # Source: usr/lib/udev/rules.d/40-hpet-permissions.rules
      # Source: usr/lib/udev/rules.d/99-cpu-dma-latency.rules
      # ================================================================
      (lib.mkIf cfg.audio.enable {
        services.udev.extraRules = ''
          # 20-audio-pm: Disable snd-hda-intel power saving on AC
          ACTION=="add", SUBSYSTEM=="sound", KERNEL=="card*", DRIVERS=="snd_hda_intel", TEST!="/run/udev/snd-hda-intel-powersave", RUN+="${lib.getExe audioPmCtl} init"
          ACTION=="add|change", SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_TYPE}=="Mains", ENV{POWER_SUPPLY_ONLINE}=="0", TEST=="/sys/module/snd_hda_intel", RUN+="${lib.getExe audioPmCtl} battery"
          ACTION=="add|change", SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_TYPE}=="Mains", ENV{POWER_SUPPLY_ONLINE}=="1", TEST=="/sys/module/snd_hda_intel", RUN+="${lib.getExe audioPmCtl} ac"
          # 40-hpet-permissions: Audio group access to HPET/RTC
          KERNEL=="rtc0", GROUP="audio"
          KERNEL=="hpet", GROUP="audio"
          # 99-cpu-dma-latency: Audio group access to CPU DMA latency
          DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"
        '';

        # Modprobe: disable snd-hda-intel power saving at module level
        boot.extraModprobeConfig = ''
          options snd-hda-intel power_save=0
        '';

        # PCI latency service
        # Source: usr/lib/systemd/system/pci-latency.service
        systemd.services.pci-latency = {
          description = "Adjust latency timers for PCI peripherals";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pciLatencyScript}";
          };
        };

        # PAM audio limits
        # Source: etc/security/limits.d/20-audio.conf
        security.pam.loginLimits = [
          {
            domain = "@audio";
            type = "-";
            item = "rtprio";
            value = "99";
          }
          {
            domain = "@audio";
            type = "-";
            item = "nice";
            value = "-11";
          }
        ];
      })

      # ================================================================
      # Udev: SATA ALPM + hdparm
      # Source: usr/lib/udev/rules.d/50-sata.rules
      # Source: usr/lib/udev/rules.d/69-hdparm.rules
      # ================================================================
      (lib.mkIf cfg.storage.enable {
        services.udev.extraRules = ''
          # 50-sata: SATA Active Link Power Management
          ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", ATTR{link_power_management_supported}=="1", ATTR{link_power_management_policy}=="*", ATTR{link_power_management_policy}="max_performance"
          # 69-hdparm: HDD tuning (-B 254 -S 0)
          ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ENV{ID_USB_DRIVER}=="", ENV{ID_BUS}=="ata", RUN+="${pkgs.hdparm}/bin/hdparm -B 254 -S 0 /dev/%k"
        '';
      })

      # ================================================================
      # Udev: I/O Schedulers
      # Source: usr/lib/udev/rules.d/60-ioschedulers.rules
      # ================================================================
      (lib.mkIf cfg.ioSchedulers.enable {
        services.udev.extraRules = ''
          # HDD: bfq
          ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
          # SSD: mq-deadline
          ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
          # NVMe: kyber (upstream CachyOS#220)
          ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="kyber"
        '';
      })

      # ================================================================
      # Udev + Modprobe: NVIDIA
      # Source: usr/lib/udev/rules.d/71-nvidia.rules
      # Source: usr/lib/modprobe.d/nvidia.conf
      # ================================================================
      (lib.mkIf cfg.nvidia.enable {
        services.udev.extraRules = ''
          # Runtime PM: enable on bind, disable on unbind
          ACTION=="add|bind", SUBSYSTEM=="pci", DRIVERS=="nvidia", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", TEST=="power/control", ATTR{power/control}="auto"
          ACTION=="remove|unbind", SUBSYSTEM=="pci", DRIVERS=="nvidia", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", TEST=="power/control", ATTR{power/control}="on"
        '';

        boot.extraModprobeConfig = ''
          options nvidia NVreg_InitializeSystemMemoryAllocations=0
        '';
      })

      # ================================================================
      # Modprobe: AMDGPU GCN Compatibility
      # Source: usr/lib/modprobe.d/amdgpu.conf
      # ================================================================
      (lib.mkIf cfg.amdgpuGcnCompat.enable {
        boot.extraModprobeConfig = ''
          options amdgpu si_support=1 cik_support=1
          options radeon si_support=0 cik_support=0
        '';
      })

      # ================================================================
      # Kernel Modules: ntsync
      # Source: usr/lib/modules-load.d/ntsync.conf
      # ================================================================
      (lib.mkIf cfg.ntsync.enable {
        boot.kernelModules = [ "ntsync" ];
      })

      # ================================================================
      # Systemd — Service & System Management
      # Source: journald.conf.d, system.conf.d, user.conf.d, delegate, rtkit
      # ================================================================
      (lib.mkIf cfg.systemd.enable {
        # Source: usr/lib/systemd/journald.conf.d/00-journal-size.conf
        services.journald.settings.Journal.SystemMaxUse = "50M";

        # Source: usr/lib/systemd/system.conf.d/00-timeout.conf + 10-limits.conf
        systemd.settings.Manager = {
          DefaultTimeoutStartSec = "15s";
          DefaultTimeoutStopSec = "10s";
          DefaultLimitNOFILE = "2048:2097152";
        };

        # Source: usr/lib/systemd/user.conf.d/10-limits.conf
        #       + usr/lib/systemd/user.conf.d/00-timeout.conf (upstream a469516)
        environment.etc."systemd/user.conf.d/10-cachyos-limits.conf".text = ''
          [Manager]
          DefaultLimitNOFILE=1024:1048576
          DefaultTimeoutStartSec=15s
          DefaultTimeoutStopSec=10s
        '';

        # Source: usr/lib/systemd/system/user@.service.d/delegate.conf
        systemd.services."user@" = {
          overrideStrategy = "asDropin";
          serviceConfig.Delegate = "cpu cpuset io memory pids";
        };

        # Source: usr/lib/systemd/system/rtkit-daemon.service.d/override.conf
        systemd.services.rtkit-daemon = {
          overrideStrategy = "asDropin";
          serviceConfig.LogLevelMax = "info";
        };

        systemd.packages = [
          (pkgs.writeTextDir "lib/systemd/system/system.slice.d/10-oomd-per-slice-defaults.conf" oomdPerSliceDefaults)
          (pkgs.writeTextDir "lib/systemd/system/user-.slice.d/10-oomd-per-slice-defaults.conf" oomdPerSliceDefaults)
          (pkgs.writeTextDir "lib/systemd/system/session.slice.d/10-ignore-session-slice.conf" ''
            [Slice]
            ManagedOOMPreference=omit
          '')
        ];
      })

      # ================================================================
      # Timesyncd — NTP
      # Source: usr/lib/systemd/timesyncd.conf.d/10-timesyncd.conf
      # ================================================================
      (lib.mkIf cfg.timesyncd.enable {
        services.timesyncd = {
          enable = lib.mkDefault true;
          servers = [ "time.cloudflare.com" ];
          fallbackServers = [
            "time.google.com"
            "0.nixos.pool.ntp.org"
            "1.nixos.pool.ntp.org"
            "2.nixos.pool.ntp.org"
            "3.nixos.pool.ntp.org"
          ];
        };
      })

      # ================================================================
      # Tmpfiles — THP
      # Source: usr/lib/tmpfiles.d/thp.conf + thp-shrinker.conf
      # ================================================================
      (lib.mkIf cfg.thp.enable {
        systemd.tmpfiles.rules = [
          "w! /sys/kernel/mm/transparent_hugepage/defrag - - - - defer+madvise"
          "w! /sys/kernel/mm/transparent_hugepage/khugepaged/max_ptes_none - - - - 409"
        ];
      })

      # ================================================================
      # Tmpfiles — Coredump
      # Source: usr/lib/tmpfiles.d/coredump.conf
      # ================================================================
      (lib.mkIf cfg.coredump.enable {
        systemd.tmpfiles.rules = [
          "e /var/lib/systemd/coredump - - - 3d"
        ];
      })

      # ================================================================
      # NetworkManager DNS — use systemd-resolved
      # Source: usr/lib/NetworkManager/conf.d/dns.conf
      # ================================================================
      (lib.mkIf cfg.networkManager.enable {
        networking.networkmanager.dns = lib.mkDefault "systemd-resolved";
        services.resolved.enable = lib.mkDefault true;
      })

      # ================================================================
      # Debuginfod — CachyOS symbol server
      # Source: etc/debuginfod/cachyos.urls
      # ================================================================
      (lib.mkIf cfg.debuginfod.enable {
        environment.variables.DEBUGINFOD_URLS = lib.mkDefault "https://debuginfod.cachyos.org";
      })
    ]
  );
}
