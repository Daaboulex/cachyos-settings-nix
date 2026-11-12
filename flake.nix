{
  description = "CachyOS-Settings as a NixOS module — sysctl, udev, systemd, ZRAM, THP optimizations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    std = {
      url = "github:Daaboulex/nix-packaging-standard/release";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.git-hooks.follows = "git-hooks";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [ inputs.std.flakeModules.base ];

      perSystem =
        { pkgs, system, ... }:
        let
          everyArea.cachyos.settings = {
            enable = true;
            sysctl.enable = true;
            zram.enable = true;
            ioSchedulers.enable = true;
            audio.enable = true;
            storage.enable = true;
            thp.enable = true;
            ntsync.enable = true;
            coredump.enable = true;
            serviceManager.enable = true;
            journal.enable = true;
            oomd.enable = true;
            watchdogBlacklist.enable = true;
            nvidia.enable = true;
          };
          etc =
            (inputs.nixpkgs.lib.nixosSystem {
              inherit system;
              modules = [
                ./module.nix
                everyArea
                {
                  boot.isContainer = true;
                  system.stateVersion = inputs.nixpkgs.lib.trivial.release;
                }
              ];
            }).config.environment.etc;
          userUnits = etc."systemd/user".source;
          userGenerators = etc."systemd/user-generators".source;
        in
        {
          checks.module-eval = inputs.std.lib.nixosModuleCheck {
            inherit (inputs) nixpkgs;
            inherit system;
            module = ./module.nix;
            config = everyArea;
          };

          checks.oomd-user-dropins = pkgs.runCommand "oomd-user-dropins" { } ''
            generator=${userGenerators}/cachyos-oomd-generator
            if [ ! -x "$generator" ]; then
              echo "the oomd generator is not among the user manager's generators"
              exit 1
            fi
            "$generator" "$PWD/generated"
            if ! grep -qx 'ManagedOOMMemoryPressureLimit=80%' generated/slice.d/10-oomd-per-slice-defaults.conf; then
              echo "the oomd generator did not write the per-slice defaults into the directory it was given"
              exit 1
            fi
            status=0
            "$generator" || status=$?
            if [ "$status" != 1 ]; then
              echo "the oomd generator exited $status, not 1, when given no directory to write to"
              exit 1
            fi
            if ! grep -qx 'ManagedOOMPreference=omit' ${userUnits}/session.slice.d/overrides.conf; then
              echo "session.slice in the user manager does not carry ManagedOOMPreference=omit"
              exit 1
            fi
            touch "$out"
          '';
        };

      flake.nixosModules.default = import ./module.nix;
    };
}
