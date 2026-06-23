<#
.SYNOPSIS
    One-shot installer for the Hades II co-op mod on Windows.

.DESCRIPTION
    Simplifies installation by doing everything the manual steps do, automatically:
      1. Locates your Hades II install (Steam library folders, Epic manifests, common paths,
         or a manual pick / -GamePath override).
      2. Downloads the latest mod release bundle (HadesCoopMod.zip) from GitHub and verifies
         its SHA-256 against the digest published by the GitHub Releases API. This bundle
         contains the native extension (HadesModNativeExtension.asi) plus the TN_Core and
         TN_CoopMod folders.
      3. Grabs the required Ultimate ASI Loader (bink2w64) prerequisite and wires it next to
         every Hades2.exe (DirectX and Vulkan renderer folders).
      4. Installs the native plugin + mods into the correct folders.
      5. Backs up your save games first.

    Re-runnable (idempotent). Use -DryRun to preview without changing anything.

    Pass -Uninstall to reverse the process: removes the mod folders and native plugin,
    and restores the original Ultimate ASI Loader (renames bink2w64Hooked.dll back to
    bink2w64.dll). Save games are left untouched.

.PARAMETER Uninstall
    Remove the mod instead of installing it. Deletes TN_Core / TN_CoopMod from Content\Mods,
    removes HadesModNativeExtension.asi from each renderer's plugins folder, and (unless
    -SkipAsiLoader) restores the original bink2w64.dll the loader displaced. No download is
    performed in this mode.

.PARAMETER GamePath
    Path to the Hades II install root (the folder that contains 'Content') OR directly to a
    Hades2.exe. If omitted, the script auto-detects Steam/Epic installs and falls back to a
    file picker.

.PARAMETER Version
    Release tag to install (e.g. 'v0.1.6'). Defaults to the latest published release.

.PARAMETER LocalBundle
    Path to an already-unpacked release folder or a local CMake 'bin' output (must contain
    HadesModNativeExtension.asi, TN_Core, TN_CoopMod). Skips the GitHub download.

.PARAMETER SkipAsiLoader
    Do not download/install the Ultimate ASI Loader (use if you already have a loader, e.g.
    ReturnOfModding / Hell2Modding).

.PARAMETER SkipSaveBackup
    Skip the automatic save-game backup.

.PARAMETER DryRun
    Print every action without touching disk.

.PARAMETER NoPrompt
    Never show interactive dialogs; fail instead of prompting (for unattended use).

.EXAMPLE
    .\Install-Hades2Coop.ps1
    Auto-detect, download latest, install.

.EXAMPLE
    .\Install-Hades2Coop.ps1 -GamePath "D:\SteamLibrary\steamapps\common\Hades II" -DryRun

.EXAMPLE
    .\Install-Hades2Coop.ps1 -Uninstall
    Auto-detect and cleanly remove the co-op mod, restoring the original ASI loader.
#>
[CmdletBinding()]
param(
    [string]$GamePath,
    [string]$Version,
    [string]$LocalBundle,
    [switch]$SkipAsiLoader,
    [switch]$SkipSaveBackup,
    [switch]$DryRun,
    [switch]$NoPrompt,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo          = 'Hades2-coop-project/hades2-coop'
$AsiLoaderUrl  = 'https://github.com/ThirteenAG/Ultimate-ASI-Loader/releases/download/x64-latest/bink2w64-x64.zip'
$BundleAsset   = 'HadesCoopMod.zip'
$ModFolders    = @('TN_Core', 'TN_CoopMod')
$PluginFile    = 'HadesModNativeExtension.asi'
$UA            = 'hades2-coop-installer'

# ---------- logging helpers ----------
function Info  ($m) { Write-Host "[*] $m" -ForegroundColor Cyan }
function Good  ($m) { Write-Host "[+] $m" -ForegroundColor Green }
function Warn  ($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Step  ($m) { Write-Host "`n=== $m ===" -ForegroundColor Magenta }
function Die   ($m) { Write-Host "[x] $m" -ForegroundColor Red; exit 1 }

function Do-Action {
    param([string]$Description, [scriptblock]$Action)
    if ($DryRun) { Write-Host "    DRY-RUN: $Description" -ForegroundColor DarkGray; return }
    & $Action
}

# ---------- environment checks ----------
function Assert-Environment {
    if ($PSVersionTable.PSVersion.Major -lt 5) { Die "PowerShell 5.0+ required (found $($PSVersionTable.PSVersion))." }
    if (-not ($IsWindows -ne $false)) { } # PS5 has no $IsWindows; treat as Windows
    if ($env:OS -ne 'Windows_NT') { Die "This installer targets Windows." }
}

# ---------- game detection ----------
function Get-SteamLibraries {
    $roots = @()
    foreach ($key in 'HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam','HKLM:\SOFTWARE\Valve\Steam') {
        try {
            $p = (Get-ItemProperty -Path $key -ErrorAction Stop)
            $sp = $p.SteamPath; if (-not $sp) { $sp = $p.InstallPath }
            if ($sp) { $roots += $sp }
        } catch { }
    }
    $libs = @()
    foreach ($r in ($roots | Select-Object -Unique)) {
        $vdf = Join-Path $r 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            $text = Get-Content $vdf -Raw
            foreach ($m in [regex]::Matches($text, '"path"\s+"([^"]+)"')) {
                $libs += ($m.Groups[1].Value -replace '\\\\', '\')
            }
        }
        $libs += $r
    }
    return $libs | Select-Object -Unique
}

function Get-EpicInstalls {
    $manifestDir = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
    $found = @()
    if (Test-Path $manifestDir) {
        foreach ($item in Get-ChildItem $manifestDir -Filter *.item -ErrorAction SilentlyContinue) {
            try {
                $j = Get-Content $item.FullName -Raw | ConvertFrom-Json
                if (($j.DisplayName -match 'Hades') -or ($j.LaunchExecutable -match 'Hades2\.exe')) {
                    if ($j.InstallLocation) { $found += $j.InstallLocation }
                }
            } catch { }
        }
    }
    return $found
}

function Find-GameRoot {
    if ($GamePath) {
        $gp = $GamePath
        if ($gp -match '\.exe$') { $gp = Split-Path (Split-Path $gp -Parent) -Parent }
        if (Test-Path (Join-Path $gp 'Content')) { return (Resolve-Path $gp).Path }
        # maybe they pointed at the exe's own folder
        if (Test-Path (Join-Path $gp 'Hades2.exe')) { return (Resolve-Path (Split-Path $gp -Parent)).Path }
        Die "GamePath '$GamePath' does not look like a Hades II install (no Content folder found)."
    }

    Info "Auto-detecting Hades II install..."
    $candidates = @()
    foreach ($lib in (Get-SteamLibraries)) { $candidates += (Join-Path $lib 'steamapps\common\Hades II') }
    $candidates += (Get-EpicInstalls)
    foreach ($drive in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null })) {
        $candidates += (Join-Path $drive.Root 'Program Files\Epic Games\Hades II')
        $candidates += (Join-Path $drive.Root 'XboxGames\Hades II\Content')
    }

    foreach ($c in ($candidates | Select-Object -Unique)) {
        if ($c -and (Test-Path $c) -and (Test-Path (Join-Path $c 'Content'))) {
            Good "Found: $c"
            return (Resolve-Path $c).Path
        }
    }

    # manual fallback
    if ($NoPrompt) { Die "Could not auto-detect Hades II. Re-run with -GamePath." }
    Warn "Auto-detection failed. Please pick your Hades2.exe..."
    Add-Type -AssemblyName System.Windows.Forms
    $dlg = New-Object System.Windows.Forms.OpenFileDialog -Property @{
        Filter = 'Hades2.exe|Hades2.exe'; Title = 'Select your Hades2.exe'
    }
    if ($dlg.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { Die "Cancelled." }
    $root = Split-Path (Split-Path $dlg.FileName -Parent) -Parent
    if (-not (Test-Path (Join-Path $root 'Content'))) {
        # exe might be directly under root
        $root = Split-Path $dlg.FileName -Parent
    }
    return $root
}

function Get-ExeDirs {
    param([string]$Root)
    $exes = Get-ChildItem -Path $Root -Filter 'Hades2.exe' -Recurse -Depth 2 -ErrorAction SilentlyContinue
    $dirs = $exes | ForEach-Object { $_.DirectoryName } | Select-Object -Unique
    if (-not $dirs) { Die "No Hades2.exe found under '$Root'." }
    return $dirs
}

# ---------- download helpers ----------
function Get-LatestRelease {
    $api = if ($Version) {
        "https://api.github.com/repos/$Repo/releases/tags/$Version"
    } else {
        "https://api.github.com/repos/$Repo/releases/latest"
    }
    Info "Querying release info: $api"
    return Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = $UA }
}

function Download-Bundle {
    param([string]$WorkDir)
    $rel = Get-LatestRelease
    $asset = $rel.assets | Where-Object { $_.name -eq $BundleAsset } | Select-Object -First 1
    if (-not $asset) { Die "Release '$($rel.tag_name)' has no asset named '$BundleAsset'." }
    Good "Release $($rel.tag_name): $($asset.name) ($([math]::Round($asset.size/1KB)) KB)"

    $zip = Join-Path $WorkDir $BundleAsset
    Info "Downloading mod bundle..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -Headers @{ 'User-Agent' = $UA }

    if ($asset.digest -and $asset.digest -match '^sha256:(.+)$') {
        $expected = $Matches[1].ToLower()
        $actual = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
        if ($actual -ne $expected) { Die "SHA-256 mismatch! expected $expected got $actual. Aborting." }
        Good "SHA-256 verified."
    } else {
        Warn "No digest published for this asset; skipping hash verification."
    }

    $extract = Join-Path $WorkDir 'bundle'
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    return $extract
}

function Resolve-BundleRoot {
    param([string]$Path)
    # The asi + mod folders may be at the root of the extract or one level down.
    foreach ($p in @($Path) + (Get-ChildItem $Path -Directory | ForEach-Object FullName)) {
        if (Test-Path (Join-Path $p $PluginFile)) { return $p }
    }
    Die "Could not find '$PluginFile' in the bundle. Unexpected archive layout."
}

# ---------- install steps ----------
function Backup-Saves {
    if ($SkipSaveBackup) { return }
    $saveDir = Join-Path $env:USERPROFILE 'Saved Games\Hades II'
    if (-not (Test-Path $saveDir)) { Warn "No save folder at '$saveDir' (nothing to back up)."; return }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $dest = Join-Path $env:USERPROFILE "Saved Games\Hades II.backup-$stamp.zip"
    Do-Action "Zip saves -> $dest" { Compress-Archive -Path "$saveDir\*" -DestinationPath $dest -Force }
    Good "Saves backed up to $dest"
}

function Install-AsiLoader {
    param([string]$ExeDir, [string]$WorkDir)
    if ($SkipAsiLoader) { Info "Skipping ASI loader (per -SkipAsiLoader)."; return }
    if (Test-Path (Join-Path $ExeDir 'ReturnOfModding')) { Good "ReturnOfModding present in $ExeDir -> skip ASI loader."; return }
    if (Test-Path (Join-Path $ExeDir 'bink2w64Hooked.dll')) { Good "ASI loader already installed in $ExeDir -> skip."; return }

    $orig = Join-Path $ExeDir 'bink2w64.dll'
    if (Test-Path $orig) {
        Do-Action "Rename bink2w64.dll -> bink2w64Hooked.dll in $ExeDir" {
            Move-Item $orig (Join-Path $ExeDir 'bink2w64Hooked.dll') -Force
        }
    } else {
        Warn "Original bink2w64.dll not found in $ExeDir (continuing)."
    }

    $zip = Join-Path $WorkDir 'asi_loader.zip'
    $tmp = Join-Path $WorkDir 'asi_loader'
    Do-Action "Download + extract Ultimate ASI Loader" {
        Invoke-WebRequest -Uri $AsiLoaderUrl -OutFile $zip -Headers @{ 'User-Agent' = $UA }
        if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
        Expand-Archive -Path $zip -DestinationPath $tmp -Force
        $dll = Get-ChildItem $tmp -Filter 'bink2w64.dll' -Recurse | Select-Object -First 1
        if (-not $dll) { throw "bink2w64.dll missing from ASI loader archive." }
        Copy-Item $dll.FullName (Join-Path $ExeDir 'bink2w64.dll') -Force
    }
    Good "ASI loader installed in $ExeDir"
}

function Install-Plugin {
    param([string]$ExeDir, [string]$BundleRoot)
    $plugins = Join-Path $ExeDir 'plugins'
    $src = Join-Path $BundleRoot $PluginFile
    if (-not (Test-Path $src)) { Die "Bundle missing $PluginFile." }
    Do-Action "Ensure $plugins + copy $PluginFile" {
        if (-not (Test-Path $plugins)) { New-Item -ItemType Directory -Path $plugins | Out-Null }
        Copy-Item $src $plugins -Force
    }
    Good "Native plugin installed in $plugins"
}

function Install-Mods {
    param([string]$ModsDir, [string]$BundleRoot)
    Do-Action "Ensure $ModsDir" {
        if (-not (Test-Path $ModsDir)) { New-Item -ItemType Directory -Path $ModsDir | Out-Null }
    }
    foreach ($m in $ModFolders) {
        $src = Join-Path $BundleRoot $m
        if (-not (Test-Path $src)) { Warn "Bundle missing mod folder '$m' (skipping)."; continue }
        $dest = Join-Path $ModsDir $m
        Do-Action "Replace $dest" {
            if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
            Copy-Item $src $ModsDir -Recurse -Force
        }
        Good "Installed mod: $m"
    }
}

function Test-Install {
    param([string[]]$ExeDirs, [string]$ModsDir)
    if ($DryRun) { return }
    $ok = $true
    foreach ($d in $ExeDirs) {
        if (-not $SkipAsiLoader -and -not (Test-Path (Join-Path $d 'bink2w64.dll'))) { Warn "Missing loader in $d"; $ok = $false }
        if (-not (Test-Path (Join-Path $d "plugins\$PluginFile"))) { Warn "Missing plugin in $d"; $ok = $false }
    }
    foreach ($m in $ModFolders) {
        if (-not (Test-Path (Join-Path $ModsDir $m))) { Warn "Missing mod $m"; $ok = $false }
    }
    if ($ok) { Good "Verification passed." } else { Warn "Verification found gaps (see above)." }
}

# ---------- uninstall steps ----------
function Uninstall-Mods {
    param([string]$ModsDir)
    foreach ($m in $ModFolders) {
        $dest = Join-Path $ModsDir $m
        if (Test-Path $dest) {
            Do-Action "Remove $dest" { Remove-Item $dest -Recurse -Force }
            Good "Removed mod: $m"
        } else {
            Info "Mod '$m' not present (nothing to remove)."
        }
    }
}

function Uninstall-Plugin {
    param([string]$ExeDir)
    $plugins = Join-Path $ExeDir 'plugins'
    $asi = Join-Path $plugins $PluginFile
    if (Test-Path $asi) {
        Do-Action "Remove $asi" { Remove-Item $asi -Force }
        Good "Removed plugin from $plugins"
    } else {
        Info "Plugin not present in $plugins."
    }
    # tidy up an empty plugins folder we may have created
    if ((Test-Path $plugins) -and -not (Get-ChildItem $plugins -Force -ErrorAction SilentlyContinue)) {
        Do-Action "Remove empty $plugins" { Remove-Item $plugins -Force }
    }
}

function Uninstall-AsiLoader {
    param([string]$ExeDir)
    if ($SkipAsiLoader) { Info "Leaving ASI loader in place (per -SkipAsiLoader)."; return }
    if (Test-Path (Join-Path $ExeDir 'ReturnOfModding')) { Info "ReturnOfModding present in $ExeDir -> leaving loader untouched."; return }

    $hooked = Join-Path $ExeDir 'bink2w64Hooked.dll'
    $loader = Join-Path $ExeDir 'bink2w64.dll'
    if (Test-Path $hooked) {
        # Reverse our install: drop the loader's bink2w64.dll and restore the game's original.
        Do-Action "Restore original bink2w64.dll in $ExeDir" {
            if (Test-Path $loader) { Remove-Item $loader -Force }
            Move-Item $hooked $loader -Force
        }
        Good "Original ASI loader restored in $ExeDir"
    } else {
        Warn "No bink2w64Hooked.dll backup in $ExeDir; leaving bink2w64.dll as-is to avoid deleting a game file."
    }
}

function Test-Uninstall {
    param([string[]]$ExeDirs, [string]$ModsDir)
    if ($DryRun) { return }
    $ok = $true
    foreach ($m in $ModFolders) {
        if (Test-Path (Join-Path $ModsDir $m)) { Warn "Mod still present: $m"; $ok = $false }
    }
    foreach ($d in $ExeDirs) {
        if (Test-Path (Join-Path $d "plugins\$PluginFile")) { Warn "Plugin still present in $d"; $ok = $false }
        if (-not $SkipAsiLoader -and (Test-Path (Join-Path $d 'bink2w64Hooked.dll'))) { Warn "Loader backup still present in $d"; $ok = $false }
    }
    if ($ok) { Good "Uninstall verification passed." } else { Warn "Uninstall verification found leftovers (see above)." }
}

function Invoke-Uninstall {
    param([string[]]$ExeDirs, [string]$ModsDir)
    Step "1/3  Remove mod files"
    Uninstall-Mods -ModsDir $ModsDir

    Step "2/3  Remove native plugin"
    foreach ($d in $ExeDirs) { Uninstall-Plugin -ExeDir $d }

    Step "3/3  Restore ASI loader"
    foreach ($d in $ExeDirs) { Uninstall-AsiLoader -ExeDir $d }

    Step "Verify"
    Test-Uninstall -ExeDirs $ExeDirs -ModsDir $ModsDir
}

# ---------- main ----------
Assert-Environment
$title = if ($Uninstall) { "Hades II Co-op Mod Uninstaller" } else { "Hades II Co-op Mod Installer" }
Step $title
if ($DryRun) { Warn "DRY-RUN mode: no files will be changed." }

$root = Find-GameRoot
$exeDirs = Get-ExeDirs -Root $root
$modsDir = Join-Path $root 'Content\Mods'
Good "Game root : $root"
Good "Renderers : $($exeDirs -join '; ')"
Good "Mods dir  : $modsDir"

if ($Uninstall) {
    Invoke-Uninstall -ExeDirs $exeDirs -ModsDir $modsDir
    Step "Done"
    Good "Hades II co-op mod uninstalled."
    Warn "Save games were left untouched ($env:USERPROFILE\Saved Games\Hades II)."
    if (-not $NoPrompt -and -not $DryRun) { Read-Host "`nPress Enter to exit" | Out-Null }
    return
}

$work = Join-Path $env:TEMP ("h2coop-" + [Guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
    Step "1/5  Back up save games"
    Backup-Saves

    Step "2/5  Acquire mod bundle"
    if ($LocalBundle) {
        if (-not (Test-Path $LocalBundle)) { Die "LocalBundle '$LocalBundle' not found." }
        $bundleRoot = Resolve-BundleRoot -Path (Resolve-Path $LocalBundle).Path
        Good "Using local bundle: $bundleRoot"
    } else {
        $extract = Download-Bundle -WorkDir $work
        $bundleRoot = Resolve-BundleRoot -Path $extract
    }

    Step "3/5  Install ASI loader prerequisite"
    foreach ($d in $exeDirs) { Install-AsiLoader -ExeDir $d -WorkDir $work }

    Step "4/5  Install native plugin"
    foreach ($d in $exeDirs) { Install-Plugin -ExeDir $d -BundleRoot $bundleRoot }

    Step "5/5  Install mod files"
    Install-Mods -ModsDir $modsDir -BundleRoot $bundleRoot

    Step "Verify"
    Test-Install -ExeDirs $exeDirs -ModsDir $modsDir
}
finally {
    if (-not $DryRun) { Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue }
}

Step "Done"
Good "Hades II co-op mod installed."
Warn "Reminder: this mod requires a GAMEPAD to play, and is early-development (may crash)."
Warn "If you use Steam and are prompted for DirectX vs Vulkan at launch, the loader is installed for both."
if (-not $NoPrompt -and -not $DryRun) { Read-Host "`nPress Enter to exit" | Out-Null }
