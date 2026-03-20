# Minimal PowerShell profile for Windows dotfiles.

if (Get-Module -ListAvailable -Name PSReadLine) {
    try {
        Set-PSReadLineOption -EditMode Windows
        Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    } catch {
        # Keep the profile resilient if PSReadLine is unavailable or locked down.
    }
}

function rld {
    . $PROFILE
}

function l {
    Get-ChildItem @args
}

function la {
    Get-ChildItem -Force @args
}

function ll {
    Get-ChildItem -Force @args
}

function aa {
    Get-Alias | Sort-Object Name | Format-Table Name, Definition -AutoSize
}

function myip {
    try {
        (Invoke-RestMethod -Uri 'https://ifconfig.me').Trim()
    } catch {
        Write-Warning "Unable to resolve public IP."
    }
}

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    try {
        oh-my-posh init pwsh | Invoke-Expression
    } catch {
        # Keep startup non-fatal if the prompt engine is temporarily unavailable.
    }
}
