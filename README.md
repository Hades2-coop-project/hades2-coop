# Hades II coop mod

Play Hades 2 with a friend!
This mod adds local cooperative multiplayer to Hades 2, allowing two players to fight through the Underworld together on the same PC.

For online play: Use a streaming tool like [Parsec](https://parsec.app/) to share your game session with a remote friend.

The mod supports the **Steam** and **Epic Games Store** versions of the gamme

**Warning**

You need a gamepad to play this mod.

# Intalling

## Recommended: one-shot installer (Windows)

The easiest way to install on Windows is the bundled bootstrapper, which auto-detects your
Hades II install (Steam / Epic / Xbox), downloads and SHA-256 verifies the mod bundle, wires
up the required Ultimate ASI Loader for both the DirectX and Vulkan renderers, backs up your
saves, and installs everything in one step:

```powershell
# In the install/ folder (allow scripts for this session if needed):
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Install-Hades2Coop.ps1
```

To remove the mod again (restores the original loader, leaves saves untouched):

```powershell
.\Install-Hades2Coop.ps1 -Uninstall
```

See [`install/README.md`](install/README.md) for all parameters (`-GamePath`, `-Version`,
`-LocalBundle`, `-SkipAsiLoader`, `-DryRun`, `-NoPrompt`, `-Uninstall`) and examples.

## Manual

1. Download the latest release of this mod from the [releases page](https://github.com/Hades2-coop-project/hades2-coop/releases)
2. Unpack the archive
3. Run `install.ps1` with powershell

# Co-op fork changes

This fork carries fixes on top of upstream:

- **Boss shield-phase softlock on player death ([#36](https://github.com/Hades2-coop-project/hades2-coop/issues/36)).**
  If Player 1 died during a staged boss's shield phase (e.g. Hecate), the boss's AI thread
  stayed parked on the now-dead hero and never re-queried its target, leaving the boss
  permanently shielded and idle so Player 2 could not progress. The fix force-retargets staged
  bosses onto the surviving hero and wakes the parked stage thread (`notifyExistingWaiters`)
  rather than tearing it down — which would have stranded the invulnerability flag. See
  `game/scripts/logic/RunEx.lua` (`RefreshEnemyAI`) and `game/scripts/hooks/RunHooks.lua`.
- **Windows one-shot installer / uninstaller** — see above.

# Build

## Using CMake for Windows x64

```powershell
cmake -A x64 . -B build_msvc
cmake --build build_msvc --config Release
```

Copy files from `build_msvc/bin` to the `Hades II/Mods/TN_CoopMod` folder.

## Using [Visual Studio](https://visualstudio.microsoft.com/) GUI

You need to install cmake in the Visual Studio Installer to build the project.
Open the project in VS and click Build -> Install HadesCoop in the top menu.

Copy files from `build_msvc/bin` to the `Hades II/Mods/TN_CoopMod` folder.

# Suppoort

You can support development using crypto. See [my page](https://thenormalnij.de/donate) for details
