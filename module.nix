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

  xswapGenerator = pkgs.writeScript "xswap-generator" ''
    #!${pkgs.bashInteractive}/bin/bash
    if [[ -e /sys/kernel/mm/xswap && ! -n "$(compgen -G '/sys/kernel/mm/xswap/type*')" ]]; then
        ${pkgs.coreutils}/bin/ln -s /dev/null /run/systemd/zram-generator.conf
        echo 100 > /sys/kernel/mm/xswap/create
    fi
  '';
in
{
  options.cachyos.settings = {
    enable = lib.mkEnableOption "CachyOS system optimizations (upstream-matched settings)";

    zram.enable =
      lib.mkEnableOption "ZRAM swap (zstd, 100% RAM), handed to xswap on a kernel that provides it"
      // {
        default = true;
      };
    ioSchedulers.enable =
      lib.mkEnableOption "I/O scheduler udev rules (bfq for rotational disks, mq-deadline for SSD and eMMC, kyber for NVMe)"
      // {
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
    timesyncd.enable =
      lib.mkEnableOption "NTP time synchronization (Cloudflare, with Google and the Arch pool as fallback)"
      // {
        default = true;
      };
    networkManager.enable = lib.mkEnableOption "NetworkManager DNS via systemd-resolved" // {
      default = true;
    };
    ntsync.enable = lib.mkEnableOption "NT sync kernel module for Wine/Proton" // {
      default = true;
    };
    coredump.enable = lib.mkEnableOption "Coredump cleanup (3-day retention)" // {
      default = true;
    };
    watchdog.enable = lib.mkEnableOption "the iTCO, SP5100 and WDAT hardware watchdog drivers, which upstream blacklists";

    nvidia.enable = lib.mkEnableOption "NVIDIA modprobe + udev tuning (runtime PM, power management)";
    amdgpuGcnCompat.enable = lib.mkEnableOption "Force amdgpu driver for GCN 1.0+ (SI) and GCN 2.x (CIK) GPUs";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [

      {
        boot.kernel.sysctl = lib.mapAttrs (_: upstreamDefault) {
          "vm.swappiness" = 100;
          "vm.vfs_cache_pressure" = 50;
          "vm.dirty_bytes" = 268435456;
          "vm.dirty_background_bytes" = 67108864;
          "vm.dirty_writeback_centisecs" = 1500;
          "vm.page-cluster" = 0;

          "kernel.nmi_watchdog" = 0;
          "-kernel.unprivileged_userns_clone" = 1;
          "kernel.printk" = "3 3 3 3";
          "kernel.kptr_restrict" = 2;
          "kernel.sysrq" = 1;

          "net.core.netdev_max_backlog" = 4096;

          "fs.file-max" = 2097152;
        };
      }

      (lib.mkIf (!cfg.watchdog.enable) {
        boot.blacklistedKernelModules = [
          "iTCO_wdt"
          "sp5100_tco"
          "wdat_wdt"
        ];
      })

      (lib.mkIf cfg.zram.enable {
        zramSwap = {
          enable = true;
          algorithm = upstreamDefault "zstd";
          memoryPercent = upstreamDefault 100;
          priority = upstreamDefault 100;
        };

        systemd.generators.xswap-generator = "${xswapGenerator}";
        systemd.packages = [
          (pkgs.writeTextDir "lib/systemd/system/systemd-zram-setup@.service.d/xswap.conf" ''
            [Unit]
            ConditionPathExistsGlob=!/sys/kernel/mm/xswap/type*
          '')
        ];
      })

      (lib.mkIf config.zramSwap.enable {
        services.udev.extraRules = ''
          ACTION=="change", KERNEL=="zram0", ATTR{initstate}=="1", SYSCTL{vm.swappiness}="150", RUN+="${pkgs.bash}/bin/bash -c 'echo N > /sys/module/zswap/parameters/enabled'"
        '';
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

      (lib.mkIf cfg.amdgpuGcnCompat.enable {
        boot.extraModprobeConfig = ''
          options amdgpu si_support=1 cik_support=1
          options radeon si_support=0 cik_support=0
        '';
      })

      (lib.mkIf cfg.ntsync.enable {
        boot.kernelModules = [ "ntsync" ];
      })

      (lib.mkIf cfg.systemd.enable {
        services.journald.settings.Journal.SystemMaxUse = upstreamDefault "50M";

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

        systemd.services.rtkit-daemon = {
          overrideStrategy = "asDropin";
          serviceConfig.LogLevelMax = upstreamDefault "info";
        };

        systemd.oomd.enableSystemSlice = upstreamDefault true;
        systemd.slices.system = {
          overrideStrategy = "asDropin";
          sliceConfig.ManagedOOMSwap = upstreamDefault "kill";
        };
        systemd.slices."user-" = {
          overrideStrategy = "asDropin";
          sliceConfig = lib.mapAttrs (_: upstreamDefault) {
            ManagedOOMSwap = "kill";
            ManagedOOMMemoryPressure = "kill";
            ManagedOOMMemoryPressureLimit = "80%";
          };
        };

        systemd.user.slices.session = {
          overrideStrategy = "asDropin";
          sliceConfig.ManagedOOMPreference = upstreamDefault "omit";
        };
      })

      (lib.mkIf cfg.timesyncd.enable {
        services.timesyncd = {
          enable = upstreamDefault true;
          servers = upstreamDefault [ "time.cloudflare.com" ];
          fallbackServers = upstreamDefault [
            "time.google.com"
            "0.arch.pool.ntp.org"
            "1.arch.pool.ntp.org"
            "2.arch.pool.ntp.org"
            "3.arch.pool.ntp.org"
          ];
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

      (lib.mkIf cfg.networkManager.enable {
        networking.networkmanager.dns = upstreamDefault "systemd-resolved";
      })
    ]
  );
}
