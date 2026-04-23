@{
    # Core public baseline for Windows machines bootstrapped by this repo.
    # Keep this conservative and public-safe: prefer common tools, not machine-specific globals.

    Winget = @(
        'Git.Git'
        'GitHub.cli'
        'JanDeDobbeleer.OhMyPosh'
        'DEVCOM.JetBrainsMonoNerdFont'
        'Microsoft.PowerShell'
        'Microsoft.WindowsTerminal'
        'OpenJS.NodeJS.LTS'
    )

    Scoop = @(
        '7zip'
        'bat'
        'delta'
        'eza'
        'fd'
        'fzf'
        'jq'
        'gsudo'
        'ripgrep'
        'zoxide'
        'uv'
    )

    NpmGlobal = @(
    )
}
