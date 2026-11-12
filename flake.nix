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
        {
          lib,
          pkgs,
          system,
          ...
        }:
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

          ledger = lib.importJSON ./upstream-version.json;
          decided =
            decision: lib.attrsToList (lib.filterAttrs (_: entry: entry.decision == decision) ledger.files);
          knownArea =
            area:
            lib.hasSuffix ".enable" area && everyArea.cachyos.settings ? ${lib.removeSuffix ".enable" area};
          table =
            heading: column: decision: cell:
            lib.concatStringsSep "\n" (
              [
                "## ${heading}"
                ""
                "| Upstream file | ${column} |"
                "|---|---|"
              ]
              ++ map (file: "| `${file.name}` | ${cell file.value} |") (decided decision)
            );
          strayDecisions = lib.attrNames (
            lib.filterAttrs (
              _: entry:
              !lib.elem entry.decision [
                "ported"
                "left-to-nixos"
                "not-ported"
              ]
            ) ledger.files
          );
          strayAreas = map (file: "${file.name} names ${file.value.area or "no area"}") (
            lib.filter (file: !knownArea (file.value.area or "")) (decided "ported")
          );
          upstreamPage =
            if strayDecisions != [ ] then
              throw "upstream-version.json: these files carry a decision that is none of ported, left-to-nixos, not-ported: ${toString strayDecisions}"
            else if strayAreas != [ ] then
              throw "upstream-version.json: a ported file must name the option that carries it, as <area>.enable: ${lib.concatStringsSep "; " strayAreas}"
            else
              lib.concatStringsSep "\n\n" [
                "# What comes from upstream"
                "Every file of [${ledger.repo}](https://github.com/${ledger.repo}) and what this module does with it, at the commit [upstream-version.json](../upstream-version.json) records. This page is generated from that file: change a decision there, then run `nix run .#write-upstream-page`."
                (table "Ported" "Option under `cachyos.settings`" "ported" (entry: "`${entry.area}`"))
                (table "Left to NixOS" "Why" "left-to-nixos" (entry: entry.why))
                (table "Not ported" "Why" "not-ported" (entry: entry.why))
              ]
              + "\n";
        in
        {
          checks.module-eval = inputs.std.lib.nixosModuleCheck {
            inherit (inputs) nixpkgs;
            inherit system;
            module = ./module.nix;
            config = everyArea;
          };

          apps.write-upstream-page = {
            type = "app";
            program = lib.getExe (
              pkgs.writeShellApplication {
                name = "write-upstream-page";
                runtimeInputs = [
                  pkgs.coreutils
                  pkgs.git
                ];
                text = ''
                  install -Dm644 ${pkgs.writeText "UPSTREAM.md" upstreamPage} "$(git rev-parse --show-toplevel)/docs/UPSTREAM.md"
                '';
              }
            );
            meta.description = "Write docs/UPSTREAM.md from the file ledger in upstream-version.json";
          };

          checks.upstream-page-current =
            pkgs.runCommand "upstream-page-current"
              {
                rendered = upstreamPage;
                committed = builtins.readFile ./docs/UPSTREAM.md;
                passAsFile = [
                  "rendered"
                  "committed"
                ];
              }
              ''
                if ! diff -u "$committedPath" "$renderedPath"; then
                  echo "docs/UPSTREAM.md is not what upstream-version.json says; rewrite it with: nix run .#write-upstream-page"
                  exit 1
                fi
                touch "$out"
              '';

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
