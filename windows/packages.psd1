@{
    # Curated starter inventory for Windows machines bootstrapped by this repo.
    # Keep this public-safe and conservative: prefer common tools, not machine-specific globals.

    Winget = @(
        'Git.Git'
        'GitHub.cli'
        'JanDeDobbeleer.OhMyPosh'
        'Microsoft.PowerShell'
        'OpenJS.NodeJS.LTS'
    )

    Scoop = @(
        '7zip'
        'eza'
        'fastfetch'
        'fd'
        'fzf'
        'gsudo'
        'ripgrep'
        'uv'
    )

    Chocolatey = @(
    )

    NpmGlobal = @(
    )
}
