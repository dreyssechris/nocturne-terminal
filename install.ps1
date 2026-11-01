<#
.SYNOPSIS
    Installs the Nocturne terminal look on Windows.

.DESCRIPTION
    1. Installs JetBrainsMono Nerd Font for the current user (no admin needed).
    2. Merges the Nocturne color scheme, tab theme and profile defaults into
       every Windows Terminal settings.json it finds. Your profiles stay as they are.
       A timestamped backup is written next to each settings.json first.
    3. Optional (-WithOhMyPosh): copies the oh-my-posh prompt theme.

    Works with Windows PowerShell 5.1 and PowerShell 7.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\install.ps1

.EXAMPLE
    .\install.ps1 -SkipFont -WithOhMyPosh
#>
[CmdletBinding()]
param(
    [switch]$SkipFont,
    [switch]$WithOhMyPosh,
    [string[]]$SettingsPath
)

$ErrorActionPreference = 'Stop'
$RepoRaw = 'https://raw.githubusercontent.com/dreyssechris/nocturne-terminal/main'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

# Windows PowerShell 5.1 serializes arrays as {"value":[...],"Count":n} unless this type data is removed.
if ($PSVersionTable.PSVersion.Major -lt 6) { Remove-TypeData System.Array -ErrorAction SilentlyContinue }
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

function Get-RepoFile([string]$RelPath) {
    if ($PSScriptRoot) {
        $local = Join-Path $PSScriptRoot $RelPath
        if (Test-Path $local) { return [IO.File]::ReadAllText($local) }
    }
    # Running via "irm ... | iex": fetch the file from GitHub instead.
    return (Invoke-WebRequest -UseBasicParsing "$RepoRaw/$($RelPath -replace '\\', '/')").Content
}

function Set-Prop($Obj, [string]$Name, $Value) {
    if ($Obj.PSObject.Properties[$Name]) { $Obj.$Name = $Value }
    else { $Obj | Add-Member -NotePropertyName $Name -NotePropertyValue $Value }
}

function Install-NocturneFont {
    $userReg = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    $names = @()
    foreach ($key in $userReg, 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts') {
        $props = Get-ItemProperty $key -ErrorAction SilentlyContinue
        if ($props) { $names += $props.PSObject.Properties.Name }
    }
    if ($names | Where-Object { $_ -like 'JetBrainsMono NF *' }) {
        Write-Host 'JetBrainsMono Nerd Font is already installed.' -ForegroundColor DarkGray
        return
    }

    $tmp = Join-Path $env:TEMP ('nocturne-font-' + [guid]::NewGuid())
    New-Item -ItemType Directory $tmp | Out-Null
    try {
        Write-Host 'Downloading JetBrainsMono Nerd Font ...'
        $zip = Join-Path $tmp 'JetBrainsMono.zip'
        Invoke-WebRequest -UseBasicParsing 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip' -OutFile $zip
        Expand-Archive $zip -DestinationPath $tmp -Force

        $dest = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
        New-Item -ItemType Directory -Force $dest | Out-Null
        Add-Type -AssemblyName PresentationCore
        Add-Type -Namespace Nocturne -Name Gdi -MemberDefinition @'
[DllImport("gdi32.dll", CharSet = CharSet.Unicode)] public static extern int AddFontResourceW(string file);
[DllImport("user32.dll")] public static extern IntPtr SendMessageTimeoutW(IntPtr hWnd, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
'@
        foreach ($font in Get-ChildItem $tmp -Filter 'JetBrainsMonoNerdFont-*.ttf') {
            $target = Join-Path $dest $font.Name
            Copy-Item $font.FullName $target -Force
            $glyph = New-Object System.Windows.Media.GlyphTypeface ([uri]$target)
            $regName = '{0} {1} (TrueType)' -f $glyph.Win32FamilyNames['en-us'], $glyph.Win32FaceNames['en-us']
            New-ItemProperty -Path $userReg -Name $regName -Value $target -PropertyType String -Force | Out-Null
            [void][Nocturne.Gdi]::AddFontResourceW($target)
        }
        $ignored = [IntPtr]::Zero
        [void][Nocturne.Gdi]::SendMessageTimeoutW([IntPtr]0xffff, 0x001D, [IntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$ignored)
        Write-Host 'Font installed for the current user.' -ForegroundColor Green
    }
    finally {
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Update-TerminalSettings([string]$Path, $Cfg) {
    $backup = '{0}.bak-{1}' -f $Path, (Get-Date -Format 'yyyyMMdd-HHmmss')
    Copy-Item $Path $backup

    # settings.json may contain // comment lines, which ConvertFrom-Json in PS 5.1 rejects.
    $text = (Get-Content $Path -Encoding UTF8 | Where-Object { $_ -notmatch '^\s*//' }) -join "`n"
    $s = $text | ConvertFrom-Json

    if (-not $s.PSObject.Properties['profiles']) {
        Set-Prop $s 'profiles' ([pscustomobject]@{ defaults = [pscustomobject]@{}; list = @() })
    }
    elseif ($s.profiles -is [array]) {
        Set-Prop $s 'profiles' ([pscustomobject]@{ defaults = [pscustomobject]@{}; list = $s.profiles })
    }
    if (-not $s.profiles.PSObject.Properties['defaults'] -or $null -eq $s.profiles.defaults) {
        Set-Prop $s.profiles 'defaults' ([pscustomobject]@{})
    }

    $defaults = $s.profiles.defaults
    foreach ($name in $Cfg.removeFromDefaults) { $defaults.PSObject.Properties.Remove($name) }
    foreach ($p in $Cfg.defaults.PSObject.Properties) { Set-Prop $defaults $p.Name $p.Value }
    foreach ($p in $Cfg.global.PSObject.Properties) { Set-Prop $s $p.Name $p.Value }

    foreach ($key in 'schemes', 'themes') {
        $ours = @($Cfg.$key)
        $ourNames = $ours | ForEach-Object { $_.name }
        $keep = @()
        if ($s.PSObject.Properties[$key] -and $s.$key) {
            $keep = @($s.$key | Where-Object { $ourNames -notcontains $_.name })
        }
        Set-Prop $s $key ([object[]]($keep + $ours))
    }

    $json = $s | ConvertTo-Json -Depth 64
    $null = $json | ConvertFrom-Json  # sanity check before writing
    [IO.File]::WriteAllText($Path, $json, $Utf8NoBom)
    Write-Host "Updated $Path" -ForegroundColor Green
    Write-Host "  backup: $backup" -ForegroundColor DarkGray
}

# 1. Font
if (-not $SkipFont) { Install-NocturneFont }

# 2. Windows Terminal
$cfg = (Get-RepoFile 'windows-terminal\nocturne.json') | ConvertFrom-Json
if (-not $SettingsPath) {
    $SettingsPath = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    ) | Where-Object { Test-Path $_ }
}
if (-not $SettingsPath) {
    Write-Warning 'No Windows Terminal settings.json found. Start Windows Terminal once, then run this script again.'
}
foreach ($path in $SettingsPath) { Update-TerminalSettings $path $cfg }

# 3. Optional prompt theme
if ($WithOhMyPosh) {
    if ($env:POSH_THEMES_PATH) {
        $dest = Join-Path $env:POSH_THEMES_PATH 'chris-simple.omp.json'
        [IO.File]::WriteAllText($dest, (Get-RepoFile 'oh-my-posh\chris-simple.omp.json'), $Utf8NoBom)
        Write-Host "Prompt theme copied to $dest" -ForegroundColor Green
        Write-Host 'Add this line to your PowerShell profile (notepad $PROFILE):'
        Write-Host "  oh-my-posh init pwsh --config `"$dest`" | Invoke-Expression"
    }
    else {
        Write-Warning 'oh-my-posh not found. Install it with: winget install JanDeDobbeleer.OhMyPosh'
    }
}

Write-Host ''
Write-Host 'Done. Windows Terminal reloads automatically; restart it if the font does not show up yet.' -ForegroundColor Cyan
