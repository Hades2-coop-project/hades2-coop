# Install-Hades2Coop.ps1

One-shot Windows installer/uninstaller for the Hades II co-op mod. It automates every
manual step: finds your Hades II install, downloads the mod release bundle (verifying its
SHA-256), wires up the Ultimate ASI Loader prerequisite for **both** the DirectX and Vulkan
renderers, installs the native plugin + mods, and backs up your saves first. It is
re-runnable (idempotent) and can cleanly remove itself.

## Requirements

- Windows with **PowerShell 5.0+** (the built-in Windows PowerShell is fine).
- Hades II installed (Steam, Epic, or Xbox/Game Pass).
- A **gamepad** — the co-op mod requires one to play.
- Internet access on first install (to download the bundle + ASI loader), unless you use
  `-LocalBundle` and `-SkipAsiLoader`.

## Quick start

Open PowerShell in this folder and run:

```powershell
# If scripts are blocked, allow this one for the current session only:
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

# Install (auto-detects the game, downloads the latest release):
.\Install-Hades2Coop.ps1
```

To remove the mod later:

```powershell
.\Install-Hades2Coop.ps1 -Uninstall
```

## Parameters

| Parameter         | Type   | Description |
|-------------------|--------|-------------|
| `-GamePath`       | string | Path to the Hades II install root (the folder containing `Content`) **or** directly to a `Hades2.exe`. If omitted, the script auto-detects Steam library folders, Epic manifests, and common paths, then falls back to a file picker. |
| `-Version`        | string | Release tag to install (e.g. `v0.1.6`). Defaults to the latest published release. |
| `-LocalBundle`    | string | Path to an already-unpacked release folder or a local CMake `bin` output (must contain `HadesModNativeExtension.asi`, `TN_Core`, `TN_CoopMod`). Skips the GitHub download. |
| `-SkipAsiLoader`  | switch | Do not download/install the Ultimate ASI Loader (use if you already have a loader such as ReturnOfModding / Hell2Modding). On `-Uninstall`, leaves the loader untouched. |
| `-SkipSaveBackup` | switch | Skip the automatic save-game backup taken before installing. |
| `-DryRun`         | switch | Print every action without touching disk. Works for both install and uninstall. |
| `-NoPrompt`       | switch | Never show interactive dialogs (no file picker, no "press Enter"). Fails instead of prompting — use for unattended/scripted runs. |
| `-Uninstall`      | switch | Remove the mod instead of installing it (see below). No download is performed. |

## What it does

**Install**

1. **Back up saves** — zips `%USERPROFILE%\Saved Games\Hades II` to a timestamped archive (unless `-SkipSaveBackup`).
2. **Acquire bundle** — downloads `HadesCoopMod.zip` from the GitHub release and verifies its SHA-256 against the digest published by the Releases API (or uses `-LocalBundle`).
3. **ASI loader** — for each `Hades2.exe` folder, renames the game's `bink2w64.dll` to `bink2w64Hooked.dll` and drops in the Ultimate ASI Loader (skipped if `ReturnOfModding` is already present or `-SkipAsiLoader`).
4. **Native plugin** — copies `HadesModNativeExtension.asi` into each renderer's `plugins\` folder.
5. **Mods** — installs `TN_Core` and `TN_CoopMod` into `Content\Mods`.
6. **Verify** — confirms the loader, plugin, and mod folders are all in place.

**Uninstall** (`-Uninstall`)

1. Removes `TN_Core` / `TN_CoopMod` from `Content\Mods`.
2. Deletes `HadesModNativeExtension.asi` from each renderer's `plugins\` folder (and prunes the folder if it becomes empty).
3. Restores the original `bink2w64.dll` by renaming `bink2w64Hooked.dll` back. If no backup exists, it leaves `bink2w64.dll` alone to avoid deleting a genuine game file. Honors `-SkipAsiLoader` and skips folders containing `ReturnOfModding`.
4. **Save games are never touched.**

## Examples

```powershell
# Auto-detect, download the latest release, and install:
.\Install-Hades2Coop.ps1

# Preview an install without changing anything:
.\Install-Hades2Coop.ps1 -DryRun

# Point at a specific Steam library and skip the save backup:
.\Install-Hades2Coop.ps1 -GamePath "D:\SteamLibrary\steamapps\common\Hades II" -SkipSaveBackup

# Install a pinned version:
.\Install-Hades2Coop.ps1 -Version v0.1.6

# Fully offline install using a pre-downloaded/unpacked bundle and an existing loader:
.\Install-Hades2Coop.ps1 -LocalBundle "C:\Downloads\HadesCoopMod" -SkipAsiLoader

# Unattended install (no dialogs, fail rather than prompt):
.\Install-Hades2Coop.ps1 -GamePath "C:\Hades II" -NoPrompt

# Uninstall (preview first, then for real):
.\Install-Hades2Coop.ps1 -Uninstall -DryRun
.\Install-Hades2Coop.ps1 -Uninstall
```

## Notes & troubleshooting

- **Steam DirectX vs Vulkan prompt:** the loader and plugin are installed for *both* renderer
  folders, so either choice at launch works.
- **Auto-detection failed:** pass `-GamePath` pointing at your `Hades2.exe` or the install root.
- **"running scripts is disabled":** run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`
  in the same window before launching the script.
- **Early development:** the mod may crash; the installer backs up your saves before touching anything.
- **Restore a backup:** unzip the `Saved Games\Hades II.backup-<timestamp>.zip` archive back over
  `%USERPROFILE%\Saved Games\Hades II`.
