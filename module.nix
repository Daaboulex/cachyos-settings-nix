{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cachyos.settings;
  upstreamDefault = lib.mkOverride 500;

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
in
{
  options.cachyos.settings = {
    enable = lib.mkEnableOption "the CachyOS settings areas switched on below; on its own it changes nothing";

    sysctl.enable = lib.mkEnableOption "upstream's VM, kernel and network sysctls, and swappiness 150 with zswap off once a zram device is up";
    zram.enable = lib.mkEnableOption "zram swap with upstream's values: zstd, up to 100% of RAM, priority 100";
    ioSchedulers.enable = lib.mkEnableOption "I/O scheduler udev rules: bfq for rotational disks, mq-deadline for SSD and eMMC, kyber for NVMe";
    audio.enable = lib.mkEnableOption "audio latency tuning: PCI latency timers, snd-hda-intel power saving off on AC, HPET/RTC and CPU DMA latency for the audio group, rtprio and nice limits, rtkit logging capped at info";
    storage.enable = lib.mkEnableOption "SATA link power at max_performance and hdparm for rotational disks";
    thp.enable = lib.mkEnableOption "THP defrag at defer+madvise and the khugepaged shrinker threshold";
    ntsync.enable = lib.mkEnableOption "the ntsync kernel module, which Wine and Proton use for NT synchronization";
    coredump.enable = lib.mkEnableOption "removal of core dumps older than three days";
    serviceManager.enable = lib.mkEnableOption "systemd's start and stop timeouts and open-file limits for the system and user managers, and cgroup delegation to user managers";
    journal.enable = lib.mkEnableOption "a 50M cap on the system journal";
    oomd.enable = lib.mkEnableOption "systemd-oomd slice policy: kill on swap for system.slice, kill on swap and at 80% memory pressure for every slice of a user manager, session.slice left alone; it acts only while systemd-oomd runs";
    watchdogBlacklist.enable = lib.mkEnableOption "the blacklist of the iTCO, SP5100 and WDAT hardware watchdog drivers";
    nvidia.enable = lib.mkEnableOption "NVIDIA runtime power management on bind, and NVreg_InitializeSystemMemoryAllocations=0, which skips zeroing freshly allocated system memory for speed";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf cfg.sysctl.enable {
        boot.kernel.sysctl = lib.mapAttrs (_: upstreamDefault) {
          "vm.swappiness" = 100;
          "vm.vfs_cache_pressure" = 50;
          "vm.dirty_bytes" = 268435456;
          "vm.dirty_background_bytes" = 67108864;
          "vm.dirty_writeback_centisecs" = 1500;
          "vm.page-cluster" = 0;

          "kernel.nmi_watchdog" = 0;
          "kernel.printk" = "3 3 3 3";
          "kernel.kptr_restrict" = 2;
          "kernel.sysrq" = 1;

          "net.core.netdev_max_backlog" = 4096;
        };

        services.udev.extraRules = lib.mkIf config.zramSwap.enable ''
          ACTION=="change", KERNEL=="zram0", ATTR{initstate}=="1", SYSCTL{vm.swappiness}="150", RUN+="${pkgs.bash}/bin/bash -c 'echo N > /sys/module/zswap/parameters/enabled'"
        '';
      })

      (lib.mkIf cfg.zram.enable {
        zramSwap = {
          enable = true;
          algorithm = upstreamDefault "zstd";
          memoryPercent = upstreamDefault 100;
          priority = upstreamDefault 100;
        };
      })

      (lib.mkIf cfg.watchdogBlacklist.enable {
        boot.blacklistedKernelModules = [
          "iTCO_wdt"
          "sp5100_tco"
          "wdat_wdt"
        ];
      })

      (lib.mkIf cfg.audio.enable {
        services.udev.extraRules = ''
          ACTION=="add", SUBSYSTEM=="sound", KERNEL=="card*", DRIVERS=="snd_hda_intel", TEST!="/run/udev/snd-hda-intel-powersave", RUN+="${lib.getExe audioPmCtl} init"
          ACTION=="add|change", SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_TYPE}=="Mains", ENV{POWER_SUPPLY_ONLINE}=="0", TEST=="/sys/module/snd_hda_intel", RUN+="${lib.getExe audioPmCtl} battery"
          ACTION=="add|change", SUBSYSTEM=="power_supply", ENV{POWER_SUPPLY_TYPE}=="Mains", ENV{POWER_SUPPLY_ONLINE}=="1", TEST=="/sys/module/snd_hda_intel", RUN+="${lib.getExe audioPmCtl} ac"
          KERNEL=="rtc0", GROUP="audio"
          KERNEL=="hpet", GROUP="audio"
          DEVPATH=="/devices/virtual/misc/cpu_dma_latency", OWNER="root", GROUP="audio", MODE="0660"
        '';

        systemd.services.pci-latency = {
          description = "Adjust latency timers for PCI peripherals";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pciLatencyScript}";
          };
        };

        systemd.services.rtkit-daemon = {
          overrideStrategy = "asDropin";
          serviceConfig.LogLevelMax = upstreamDefault "info";
        };

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

      (lib.mkIf cfg.storage.enable {
        powerManagement.scsiLinkPolicy = upstreamDefault "max_performance";

        services.udev.extraRules = ''
          ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ENV{ID_USB_DRIVER}=="", ENV{ID_BUS}=="ata", RUN+="${pkgs.hdparm}/bin/hdparm -B 254 -S 0 /dev/%k"
        '';
      })

      (lib.mkIf cfg.ioSchedulers.enable {
        services.udev.extraRules = ''
          ACTION=="add|change", KERNEL=="sd[a-z]*", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
          ACTION=="add|change", KERNEL=="sd[a-z]*|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
          ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="kyber"
        '';
      })

      (lib.mkIf cfg.nvidia.enable {
        services.udev.extraRules = ''
          ACTION=="add|bind", SUBSYSTEM=="pci", DRIVERS=="nvidia", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", TEST=="power/control", ATTR{power/control}="auto"
          ACTION=="remove|unbind", SUBSYSTEM=="pci", DRIVERS=="nvidia", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", TEST=="power/control", ATTR{power/control}="on"
        '';

        boot.extraModprobeConfig = ''
          options nvidia NVreg_InitializeSystemMemoryAllocations=0
        '';
      })

      (lib.mkIf cfg.ntsync.enable {
        boot.kernelModules = [ "ntsync" ];
      })

      (lib.mkIf cfg.serviceManager.enable {
        systemd.settings.Manager = lib.mapAttrs (_: upstreamDefault) {
          DefaultTimeoutStartSec = "15s";
          DefaultTimeoutStopSec = "10s";
          DefaultLimitNOFILE = "2048:2097152";
        };

        systemd.user.settings.Manager = lib.mapAttrs (_: upstreamDefault) {
          DefaultTimeoutStartSec = "15s";
          DefaultTimeoutStopSec = "10s";
          DefaultLimitNOFILE = "1024:1048576";
        };

        systemd.services."user@" = {
          overrideStrategy = "asDropin";
          serviceConfig.Delegate = upstreamDefault "cpu cpuset io memory pids";
        };
      })

      (lib.mkIf cfg.journal.enable {
        services.journald.settings.Journal.SystemMaxUse = upstreamDefault "50M";
      })

      (lib.mkIf cfg.oomd.enable {
        systemd.oomd.enableSystemSlice = upstreamDefault true;
        systemd.slices.system = {
          overrideStrategy = "asDropin";
          sliceConfig.ManagedOOMSwap = upstreamDefault "kill";
        };

        systemd.packages = [
          (pkgs.writeTextDir "lib/systemd/user/slice.d/10-oomd-per-slice-defaults.conf" ''
            [Slice]
            ManagedOOMSwap=kill
            ManagedOOMMemoryPressure=kill
            ManagedOOMMemoryPressureLimit=80%
          '')
        ];

        systemd.user.slices.session = {
          overrideStrategy = "asDropin";
          sliceConfig.ManagedOOMPreference = upstreamDefault "omit";
        };
      })

      (lib.mkIf cfg.thp.enable {
        boot.kernel.sysfs.kernel.mm.transparent_hugepage = {
          defrag = upstreamDefault "defer+madvise";
          khugepaged.max_ptes_none = upstreamDefault 409;
        };
      })

      (lib.mkIf cfg.coredump.enable {
        systemd.tmpfiles.rules = [
          "e /var/lib/systemd/coredump - - - 3d"
        ];
      })
    ]
  );
}
