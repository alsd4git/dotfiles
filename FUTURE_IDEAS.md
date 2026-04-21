# Future Ideas

A parking lot for possible enhancements. Active items are prioritized; finished items are kept only when they help preserve context.

## Delivered

- `shellcheck` and `shfmt` are already enforced in CI for shell files.
- CI now includes a dry-run installer check plus clean-home smoke tests for Bash and Zsh.
- macOS now has a Brewfile manifest plus a small recommended defaults script wired into the installer.
- Windows now has a curated public package baseline in `windows/packages.psd1`, plus installer output that summarizes it.

## Active Backlog

| Priority | Status | Area | Idea |
| --- | --- | --- | --- |
| P1 | planned | Git & Diffing | Make `delta` the default pager with a sane theme and side-by-side settings, gated behind an opt-in prompt. |
| P1 | planned | PATH & Shell Robustness | Auto-clean legacy PATH de-dup lines inserted by older installer versions during upgrade. |
| P2 | planned | GitHub CLI | Prompt to run `gh auth login` after installation and guide SSH/GPG setup. |
| P2 | planned | Docs & DX | Add a tiny `jq`-based health check script to verify tool availability and versions. |
| P2 | planned | CI | Add a scheduled or manual full-install smoke test on clean Ubuntu to cover optional tool branches. |
| P2 | planned | macOS / Inventory | Use `list-macOS-apps` snapshots to curate and expand `macos/Brewfile` with conservative casks and App Store entries. |
| P2 | planned | Windows / PowerShell | Decide whether `install.ps1` should also install the curated Windows package manifest automatically, or keep it as an inventory-only reference. |
| P2 | planned | Node (nvm) | Offer automatic global package migration with `nvm reinstall-packages <prev>` after a Node upgrade. |
| P2 | planned | Python (uv) | Add a prompt to install `pipx` via `uv tool` and suggest common global tools such as `pre-commit`. |
| P3 | planned | Swift (swiftly) | Add a helper to list and switch toolchains, plus an optional prompt for a specific version or channel. |
| P3 | planned | Environment & Tools | Consider `direnv`, `pre-commit`, or `starship` as optional additions if they keep the config lean. |
| P3 | planned | Windows / PowerShell | Add profile aliases/functions that match the reference Windows workflow without forcing Bash parity. |
| P3 | planned | Windows / PowerShell | Add a clean Windows smoke test in CI once the PowerShell setup stabilizes. |
| P3 | maybe | macOS / Brewfile UX | Add an interactive cask picker before `brew bundle install` so you can keep everything selected by default and prune with arrows/checkboxes only when needed. |
| P3 | maybe | CI | Add an uninstall smoke test that installs, uninstalls, and asserts no managed files remain. |
| P3 | maybe | CLI Utilities | Evaluate `lazygit`, `tmux`/`zellij`, `yq`, `httpie`/`curlie`, `duf`/`dust`, `tldr`, and `tree`/`broot`. |
| P3 | maybe | Zsh Plugins | Evaluate `zsh-autosuggestions` and `zsh-syntax-highlighting` only if startup cost stays low. |
| P3 | maybe | Security & Keys | Guided SSH key generation plus `gh auth login`, and optional GPG signing setup. |

## Notes

- Ideas that start looking like docs belong in the README instead of here.
- Ideas that duplicate existing behavior should be removed rather than layered on top.
