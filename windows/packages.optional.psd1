@{
    # Nice-to-have Windows packages that are still public-safe, but not required for the core bootstrap.

    Winget = @(
        @{
            Name   = 'Microsoft PC Manager'
            Id     = '9PM860492SZD'
            Source = 'msstore'
        }
        'Amazon.Corretto.21.JDK'
        'Bitwarden.Bitwarden'
        'Klocman.BulkCrapUninstaller'
        'calibre.calibre'
        'voidtools.Everything'
        'LiriLiri.AYA'
        'Xanashi.Icaros'
        'ImageMagick.ImageMagick'
        'Oracle.JavaRuntimeEnvironment'
        'LocalSend.LocalSend'
        'Meld.Meld'
        'MoritzBunkus.MKVToolNix'
        'M2Team.NanaZip.Preview'
        'MiniTool.PartitionWizard.Free'
        'Google.Chrome'
        'Google.QuickShare'
        'RustDesk.RustDesk'
        'qarmin.krokiet'
        'SublimeHQ.SublimeMerge'
        'SumatraPDF.SumatraPDF'
        'Tailscale.Tailscale'
        'Mozilla.Thunderbird.it'
        'zhongyang219.TrafficMonitor.Full'
        'Devolutions.UniGetUI'
        'Upscayl.Upscayl'
        'Warp.Warp'
        'AntibodySoftware.WizTree'
        'Zen-Team.Zen-Browser'
        'Microsoft.PowerToys'
        'Microsoft.VisualStudioCode'
    )

    Scoop = @(
        'fastfetch'
    )

    Chocolatey = @(
    )

    NpmGlobal = @(
    )
}
