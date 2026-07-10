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
        'GNU.Nano'
        'OpenJS.NodeJS.LTS'
        '7zip.7zip'
        'sharkdp.bat'
        'dandavison.delta'
        'eza-community.eza'
        'sharkdp.fd'
        'junegunn.fzf'
        'jqlang.jq'
        'BurntSushi.ripgrep.MSVC'
        'ajeetdsouza.zoxide'
        'astral-sh.uv'
    )

    NpmGlobal = @(
    )
}
