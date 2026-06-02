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
      url = "github:Daaboulex/nix-packaging-standard?ref=v2.3.1";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.git-hooks.follows = "git-hooks";
    };
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      imports = [ inputs.std.flakeModules.base ];

      perSystem =
        { system, ... }:
        {
          # Instantiate the module (enabled) so CI catches activation-time
          # failures, not just that it evaluates as a definition.
          checks.module-eval = inputs.std.lib.nixosModuleCheck {
            inherit (inputs) nixpkgs;
            inherit system;
            module = ./module.nix;
            config.cachyos.settings.enable = true;
          };
        };

      flake.nixosModules.default = import ./module.nix;
    };
}
