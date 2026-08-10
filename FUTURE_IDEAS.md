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

## Active Backlog

| Priority | Status | Area | Idea |
| --- | --- | --- | --- |
| P1 | delivered | Git & Diffing | Make `delta` the default pager with a sane theme and side-by-side settings, gated behind an opt-in prompt. |
| P1 | delivered | PATH & Shell Robustness | Auto-clean legacy PATH de-dup lines inserted by older installer versions during upgrade. |
| P2 | delivered | GitHub CLI | Prompt to run `gh auth login` after installation and guide SSH/GPG setup. |
| P2 | delivered | Docs & DX | Add a tiny `jq`-based health check script to verify tool availability and versions. |
| P2 | delivered | CI | Add a manual full-install smoke test on clean Ubuntu to cover optional tool branches. |
| P2 | delivered | macOS / Inventory | Review `list-macOS-apps` snapshots before promoting conservative casks and App Store entries into `macos/Brewfile`. |
| P2 | planned | Windows / PowerShell | Expand the curated Windows manifest only when a package has a clear public baseline value and does not pull in machine-specific globals. |
| P2 | delivered | Node (nvm) | Offer automatic global package migration with `nvm reinstall-packages <prev>` after a Node upgrade. |
| P2 | planned | Python (uv) | Add a prompt to install `pipx` via `uv tool` and suggest common global tools such as `pre-commit`. |
| P3 | planned | Swift (swiftly) | Add a helper to list and switch toolchains, plus an optional prompt for a specific version or channel. |
| P3 | planned | Environment & Tools | Consider `direnv`, `pre-commit`, or `starship` as optional additions if they keep the config lean. |
| P3 | planned | Windows / PowerShell | Add profile aliases/functions that match the reference Windows workflow without forcing Bash parity. |
| P3 | delivered | Windows / PowerShell | Add a clean Windows smoke test in CI once the PowerShell setup stabilizes. |
| P3 | maybe | macOS / Brewfile UX | Add an interactive cask picker before `brew bundle install` so you can keep everything selected by default and prune with arrows/checkboxes only when needed. |
| P3 | delivered | CI | Add an uninstall smoke test that installs, uninstalls, and asserts no managed files remain. |
| P3 | maybe | CLI Utilities | Evaluate `lazygit`, `tmux`/`zellij`, `yq`, `httpie`/`curlie`, `duf`/`dust`, `tldr`, and `tree`/`broot`. |
| P3 | maybe | Zsh Plugins | Evaluate `zsh-autosuggestions` and `zsh-syntax-highlighting` only if startup cost stays low. |
| P3 | maybe | Security & Keys | Guided SSH key generation plus `gh auth login`, and optional GPG signing setup. |

## Notes

- Ideas that start looking like docs belong in the README instead of here.
- Ideas that duplicate existing behavior should be removed rather than layered on top.
