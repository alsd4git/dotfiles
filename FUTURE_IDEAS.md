# Future Ideas

A parking lot for possible enhancements. Active items are prioritized; finished items are kept only when they help preserve context.

## Delivered

- `shellcheck` and `shfmt` are already enforced in CI for shell files.
- CI now includes a dry-run installer check plus clean-home smoke tests for Bash and Zsh.
- macOS now has a Brewfile manifest plus a small recommended defaults script wired into the installer.
- Windows now has curated public package baselines in `windows/packages.psd1` and `windows/packages.optional.psd1`, plus installer output that summarizes them.
- Windows package bootstrap is now idempotent and only installs missing baseline entries after confirmation.
- The shell-quality workflow runs for pushes to `main` (and keeps `master` compatibility).
- Installer backup cleanup is explicit and limited to backups recorded by the installer; `--force` no longer deletes files.
- CI already includes a clean-home uninstall lifecycle smoke test.
- CI validates macOS defaults and Dock dry-runs on a macOS runner.
- The manual full-install workflow has a timeout and uploads its log artifact for diagnosis.
- The current macOS inventory was reviewed with `list-macOS-apps`; machine-specific and manual apps were intentionally not promoted into the public Brewfile.
- Delta configuration is now an explicit opt-in with conservative Git state restoration.
- Legacy PATH de-duplication lines are migrated automatically during shell startup updates.
- The installer now offers interactive `gh auth login` only when explicitly approved, with SSH/GPG setup hints.
- `scripts/tool-health-check.sh` validates the curated tool manifest with `jq` and reports versions.
- nvm upgrades now offer an explicit migration of global npm packages from the previous Node version.
- Remote bootstrap helpers now support optional SHA-256 verification, with dynamic upstream channels documented as explicit exceptions.
- Installer CLI, bootstrap policy, and result reporting now live in focused sourced modules.
- `--yes` handles non-interactive confirmation, `--all` selects optional components, and legacy `--force` remains a compatibility alias.
- Windows smoke assertions live in `tests/windows-smoke.ps1` instead of inline workflow YAML.
- File/RC, Git state, platform helpers, and toolchain helpers are split into focused sourced modules; Ubuntu 24.04 container smoke tests cover Bash and Zsh lifecycle behavior.
- The legacy installer lives under `archive/`; `install.sh` is the only supported entry point.
- Required, optional, and advisory steps share one reporting policy, with cleanup and failure-path tests.
- The supported Bash baseline is 3.2 and has a dedicated container smoke test.
- Package classifications are centralized in `lib/tool-manifest.sh`; the installer exposes named platform-tools, Git, and NVM phases.

## Open Backlog

| Priority | Status | Area | Idea |
| --- | --- | --- | --- |
| P2 | planned | Windows / PowerShell | Expand the curated Windows manifest only when a package has a clear public baseline value and does not pull in machine-specific globals. |
| P2 | planned | Python (uv) | Add a prompt to install `pipx` via `uv tool` and suggest common global tools such as `pre-commit`. |
| P3 | planned | Swift (swiftly) | Add a helper to list and switch toolchains, plus an optional prompt for a specific version or channel. |
| P3 | planned | Environment & Tools | Consider `direnv`, `pre-commit`, or `starship` as optional additions if they keep the config lean. |
| P3 | planned | Windows / PowerShell | Add profile aliases/functions that match the reference Windows workflow without forcing Bash parity. |
| P3 | maybe | macOS / Brewfile UX | Add an interactive cask picker before `brew bundle install` so you can keep everything selected by default and prune with arrows/checkboxes only when needed. |
| P3 | maybe | CLI Utilities | Evaluate `lazygit`, `tmux`/`zellij`, `yq`, `httpie`/`curlie`, `duf`/`dust`, `tldr`, and `tree`/`broot`. |
| P3 | maybe | Zsh Plugins | Evaluate `zsh-autosuggestions` and `zsh-syntax-highlighting` only if startup cost stays low. |
| P3 | maybe | Security & Keys | Guided SSH key generation plus `gh auth login`, and optional GPG signing setup. |

## Notes

- Ideas that start looking like docs belong in the README instead of here.
- Ideas that duplicate existing behavior should be removed rather than layered on top.
