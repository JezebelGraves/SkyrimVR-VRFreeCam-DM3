# SkyrimVR-VRFreeCam-DM3 (DM3 VR Contraption Lock)

> **18+ only.** This patch targets Display Model SE (DM3), an adult furniture
> framework. This repository holds only camera and VRIK logic. **No DM3 files
> are included**, and none are covered by this repository's license.

A **Skyrim VR**, player-only camera patch for **Display Model SE 3.0 "gamma1"**.
When you are mounted on a DM3 device, or interacting with one, VRIK pins your body on
the device and your character becomes a free third-person camera. On the chair's
main seat (`DSE-Chair01`) you get a first-person eyes view instead. Getting off the
device releases everything.

It works the way SexLab VR's third-person mode and OStim VR's VRIK pinning do.
**It never uses `SetVehicle`, `tfc` or `ForceThirdPerson` on the player**, because in
Skyrim VR those spin the camera or crash the game.

NPCs are not touched. DM3's packages, menus, Jump release and cleanup work as before.

## This is a source patch, not a drop-in mod
The patch has to change DM3's own script `dse_dm_ActiPlaceableBase`, which belongs
to DM3's authors. This repository therefore ships:

| Path | What it is |
|---|---|
| `src/DM3VR_added_functions.psc` | The original DM3VR function block. It is appended to **your own** copy of the DM3 script and does not compile on its own. |
| `tools/apply_dm3vr.py` | Applies all edits to your own unmodified gamma1 `dse_dm_ActiPlaceableBase.psc`: adds the call sites and appends the block. It refuses any other file (sha256 check). |
| `docs/MERGE-BY-HAND.md` | The same edits listed by line and anchor, for doing it by hand. |
| `VRFreeCam-core/Scripts/VRFreeCam.pex` + `Scripts/Source/VRFreeCam.psc` | The shared VR free-camera helper the block calls. It is byte-identical to the copy in the ZaZ VR Lock release, so an MO2 conflict on it is harmless. |

You build the final `dse_dm_ActiPlaceableBase.pex` yourself, for your own use.

## What it does
- **Mount or interact (player):** claims a camera route before DM3 changes your controls.
  - **Route 2, ZaZ VR Lock core** (when `ZazVRLock.esp` with API v2 is installed): the
    core holds your body on the device and plays the device pose (read from DM3's
    package with Papyrus Extender). VRIK arms and HIGGS hands are blocked. You get the
    held third-person camera with "next view" and a guaranteed release gesture.
  - **Route 1, plain VRFreeCam** (no core, or the core refuses): VRIK pins the body at
    the device's position and facing (`lockPosition=2`), collision is off, and the
    thumbstick moves you as the camera.
  - **Route 4, chair main seat:** first-person eyes view. HIGGS hands are off while
    seated and restored afterwards.
  - If the core is already holding you on another device, the camera is left alone.
- **Release / detract:** the VRIK pin is dropped **before** DM3 moves you off the device,
  then DM3's own release runs. A release started by the core (gesture, `x812zl.Release`,
  rescue, panic) runs DM3's own release too, and a periodic watch catches a core release
  that never reached DM3.
- **For NPCs on devices:** DM3 behaves as stock.

## Requirements
- **Skyrim VR** with **SKSEVR**: https://skse.silverlock.org/
- **Display Model SE 3.0 "gamma1"** (v3.0.0-gamma1) by darkconsole, with its own requirements:
  - releases: https://github.com/darkconsole/dse-display-model/releases/tag/v3.0.0-gamma1
  - release notes: https://github.com/darkconsole/dse-display-model/wiki/Release-Notes:-Gamma-1
  - This build only. The apply script checks for the gamma1 file.
- **VRIK Player Avatar** (tested with 0.8.8): https://www.nexusmods.com/skyrimspecialedition/mods/23416
- **PapyrusUtil**, the build that matches Skyrim VR (`StorageUtil`): https://www.nexusmods.com/skyrimspecialedition/mods/13048
- **HIGGS** (`HiggsVR`, chair seat and core route): https://www.nexusmods.com/skyrimspecialedition/mods/43930
- **Papyrus Extender VR** (`PO3_SKSEFunctions.GetPackageIdles` / `GetAnimationEventName`, core route): https://www.nexusmods.com/skyrimspecialedition/mods/58296
- **ZaZ VR Lock** (`x812zl`), optional at runtime but **its source is needed to compile**: https://github.com/JezebelGraves/SkyrimVR-VRFreeCam-ZaZ
- UIExtensions, SkyUI, RaceMenu and the rest are DM3's own requirements, not added by this patch.

## Build
1. Download the DM3 gamma1 zip and take `scripts/source/dse_dm_ActiPlaceableBase.psc`
   from it. Don't edit it.
2. Create the patched source (Python 3, no extra packages):
   ```
   python tools/apply_dm3vr.py "<path>\dse_dm_ActiPlaceableBase.psc" "<work>\dse_dm_ActiPlaceableBase.psc"
   ```
   Or follow `docs/MERGE-BY-HAND.md`.
3. Compile `<work>\dse_dm_ActiPlaceableBase.psc` with the Creation Kit's
   `PapyrusCompiler.exe` or Caprica (https://github.com/Orvid/Caprica), using
   `TESV_Papyrus_Flags.flg`. Import folders, in this order:
   - `<work>` (your patched copy, first so it wins)
   - `VRFreeCam-core/Scripts/Source` (this repo)
   - ZaZ VR Lock `Scripts/Source` (`x812zl*.psc`)
   - DM3's `scripts/source` (the other `dse_dm_*` scripts)
   - SKSEVR's Papyrus sources and the vanilla `Scripts/Source`
   - the `.psc` sources from PapyrusUtil, Papyrus Extender, VRIK (`VRIK.psc`), HIGGS
     (`HiggsVR.psc`), SkyUI SDK, UIExtensions, RaceMenu (`NiOverride`) and ConsoleUtil
4. Expect one warning for the custom mod event `OnDM3VRCoreRelease` (Caprica W7000); it is harmless.

## Install
MO2 recommended.
1. Get off any device and save.
2. Create a mod containing `Scripts/dse_dm_ActiPlaceableBase.pex` (your build) and
   `Scripts/VRFreeCam.pex` (from `VRFreeCam-core/`). Sources are optional.
3. Place it **below** (higher priority than) Display Model SE.
4. Disable any other mod that ships `dse_dm_ActiPlaceableBase`, such as older
   "VRFreeCam - Display Model DM3" packs.
5. Fully restart the game.

### Console escape
```
cgf "x812zl.Release" "test"    ; if the ZaZ VR Lock core is holding you
cgf "x812zl.Panic"             ; force-restore through the core
cgf "VRFreeCam.PanicReset"     ; no core, or if you are still stuck
```

## Uninstall
1. Get off every DM3 device. If the camera is still odd, run `cgf "VRFreeCam.PanicReset"`.
2. Save, disable or remove your built mod, so DM3's stock `dse_dm_ActiPlaceableBase.pex`
   wins again. Leave `VRFreeCam.pex` if another VRFreeCam patch still uses it.
3. Fully restart the game. No plugin (`.esp`) is added, so nothing is left in your load order.

## Known limitations
- **Testing.** The original v0.2 build's own README says "v0.2 TEST (runtime UNTESTED)".
  A later note says the build was confirmed in a headset on the chair and the rocking
  horse. This repository's code matches that build line for line apart from comments
  and the ZaZ VR Lock plugin name (`ZazVRLock.esp`, as in the public ZaZ VR Lock release).
  The output of `apply_dm3vr.py` compiles with Caprica against compile-only interfaces,
  but this exact output **has not been run in a headset**. Treat it as beta.
- **Gamma1 only.** Other DM3 versions are refused by the script and are not supported.
- **Player only.** NPCs on devices behave as stock DM3.
- **First-person chair seat.** The core's "next view" and release gesture don't apply
  there. Jump or the DM3 menu still releases you.
- **Moving the camera.** On route 1, the thumbstick moves your character, which is the
  camera; the body stays pinned on the device.
- **Other DM3 add-ons.** Mods that replace `dse_dm_ActiPlaceableBase` (for example
  extension packs) conflict. Only one copy can win.
- **Compile requirement.** Building needs the ZaZ VR Lock source even if you never install
  the ZaZ VR Lock plugin.

## Credits
- **Display Model SE (DM3):** darkconsole and the DM3 contributors. All credit for DM3 is theirs; respect their permissions.
- Method follows SexLab VR's third-person mode and OStim VR's VRIK pinning.
- VRIK by prog; HIGGS by FlyingParticle; PapyrusUtil by exiledviper and meh321;
  Papyrus Extender by powerofthree, VR build by alandtse; SKSEVR by the SKSE team.
- Patch: Jezebel Graves (with AI assistants).

## License
MIT, copyright Jezebel Graves, for the **original files in this repository only**.
See [LICENSE](LICENSE). Display Model SE and every other mod named here belong to
their authors. **DM3 itself is not included and is not covered by this license.**
