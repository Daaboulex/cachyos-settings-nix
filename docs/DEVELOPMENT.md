# Development

```bash
git clone https://github.com/Daaboulex/cachyos-settings-nix
cd cachyos-settings-nix
nix develop
nix fmt
nix flake check --no-eval-cache
```

`nix develop` enters the dev shell and installs the pre-commit hooks. `nix flake check --no-eval-cache` is the gate. It builds every check of the flake:

- `module-eval` instantiates a full NixOS system with every area on, so evaluation and assertion errors of the full system surface. It activates nothing.
- `oomd-user-dropins` runs the oomd generator and reads the drop-in it writes.
- `upstream-page-current` refuses a [UPSTREAM.md](UPSTREAM.md) that differs from the ledger, and a ported file that names no option of the module.

## Porting an upstream change

The last mirrored upstream commit is recorded in [upstream-version.json](../upstream-version.json), together with the ledger: every upstream file with its decision, `ported`, `left-to-nixos` or `not-ported`.

The daily [update workflow](../.github/workflows/update.yml) compares upstream with that commit. A change that only modifies files marked `not-ported` moves the commit by itself. Any other change opens a `remirror-needed` issue naming each file with its decision.

To port one:

1. Read the upstream change the issue shows.
2. Change [module.nix](../module.nix) to match, through the NixOS option that owns the file.
3. In `upstream-version.json`, set `commit` and `date` to the upstream commit, and add, remove or re-decide the files it touched.
4. Run `nix run .#write-upstream-page`, then the gate.
