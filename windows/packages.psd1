@{
    # Curated starter inventory for Windows machines bootstrapped by this repo.
    # Keep this public-safe and conservative: prefer common tools, not machine-specific globals.

    Winget = @(
        'Git.Git'
        'GitHub.cli'
        'JanDeDobbeleer.OhMyPosh'
        'Microsoft.PowerShell'
        'Microsoft.PowerToys'
        'Microsoft.VisualStudioCode'
        'Microsoft.WindowsTerminal'
        'OpenJS.NodeJS.LTS'
    )

    Scoop = @(
        '7zip'
        'bat'
        'delta'
        'eza'
        'fastfetch'
        'fd'
        'fzf'
        'jq'
        'gsudo'
        'ripgrep'
        'zoxide'
        'uv'
    )

    Chocolatey = @(
    )

    NpmGlobal = @(
    )
}
