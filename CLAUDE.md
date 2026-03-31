# cachyos-settings-nix

## Standard
This repo follows the **Daaboulex Nix Packaging Standard v1**.

## Repo Config
- **Package**: `cachyos-settings`
- **Upstream**: github-commit — CachyOS/CachyOS-Settings (master)
- **Hashes**: none
- **Verify**: eval check
- **Schedule**: Weekly Monday at 6 AM UTC

## Session Protocol
1. Read `AI-progress.json` and `AI-tasks.json`
2. Run `nix flake check --no-build`
3. Pick ONE task, complete it, verify it
4. Run `/handoff` before ending (saves state automatically)

## Hard Rules
- **Verification first**: `nix flake check --no-build` + `nix build` before claiming done
- **Format before commit**: `nix fmt` (enforced by git hooks via `nix develop`)
- **Never auto-commit**: show diff, user approves
- **Never commit as Claude**: commit as `Daaboulex <39669593+Daaboulex@users.noreply.github.com>`
- **No Co-Authored-By trailers**
- **Don't restructure** code you weren't asked to touch
- **One task per session** — finish, verify, move on

## Required File Structure
```
.github/workflows/{ci.yml,update.yml,maintenance.yml}
.github/update.json
scripts/update.sh
.editorconfig
.gitignore
LICENSE
README.md
CLAUDE.md
GEMINI.md
flake.nix (formatter + checks + devShells + git-hooks)
```

## Flake Requirements
- Inputs: `nixpkgs/nixos-unstable` + `git-hooks.nix` (with `nixpkgs.follows`)
- No `flake-utils` — use `nixpkgs.lib.genAttrs`
- Pattern: `localSystem.system = system`
- Always export: `formatter`, `checks` (pre-commit), `devShells` (shellHook + nil)
- Package repos: `packages` + `overlays.default`
- Module repos: `nixosModules.default` and/or `homeManagerModules.default`

## Update Contract (`scripts/update.sh`)
- Exit 0: no update needed, or update succeeded (check `updated` output)
- Exit 1: update found but build/verification failed → workflow creates Issue
- Exit 2: network/API error → retry next run
- Outputs: `updated`, `new_version`, `old_version`, `package_name`, `error_type`, `upstream_url`
- Verification chain: eval → clean build → binary verify → ldd check
- **Never false-positive**: ALL checks must pass before pushing to main

## CI Philosophy
- **Success → silent push** to main (zero noise)
- **Failure → GitHub Issue** with build log, recovery steps, update branch
- **All Actions pinned** to full commit SHAs (never `@v4`)
- **SRI hashes** everywhere (`sha256-...`)

## Workflows
1. **ci.yml** — on PR/push: eval, format, build, verify
2. **update.yml** — scheduled: detect upstream, hash extraction, verify, push or issue
3. **maintenance.yml** — weekly: flake.lock update, stale branch cleanup

## AI Tracking
- `AI-progress.json` / `AI-tasks.json` — local session tracking (gitignored)
- Run `/handoff` before ending — saves state and progress automatically
- `verifiedBy` required: `nix-flake-check`, `nix-eval`, `build-passed`, `human-tested`

## Commands
```bash
nix develop      # Enter dev shell (installs git hooks)
nix fmt          # Format code
# nix build    # Module-only repo (no packages output)
nix flake check  # Run all checks
```
