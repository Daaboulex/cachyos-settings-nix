{
  description = "CachyOS-Settings as a NixOS module — sysctl, udev, systemd, ZRAM, THP optimizations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      git-hooks,
    }:
    let
      supportedSystems = [ "x86_64-linux" ];
      forAllSystems =
        fn:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          fn {
            pkgs = import nixpkgs { localSystem.system = system; };
            inherit system;
          }
        );
    in
    {
      nixosModules.default = import ./module.nix;

      formatter = forAllSystems ({ pkgs, ... }: pkgs.nixfmt);

      checks = forAllSystems (
        { system, ... }:
        {
          pre-commit-check = git-hooks.lib.${system}.run {
            src = self;
            hooks.nixfmt.enable = true;
          };
        }
      );

      devShells = forAllSystems (
        { pkgs, system }:
        {
          default = pkgs.mkShell {
            inherit (self.checks.${system}.pre-commit-check) shellHook;
            buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
            packages = with pkgs; [ nil ];
          };
        }
      );
    };
}
