# Applying the DM3VR edits by hand

`tools/apply_dm3vr.py` makes exactly these edits. Use this page if you can't run
Python, or to check what the script did. Line numbers are for the **unmodified**
Display Model SE 3.0 "gamma1" file `scripts/source/dse_dm_ActiPlaceableBase.psc`
(sha256 `3a7689bb13ed1779879cbc63878b4bfd2eaeac67e70a8a1de9aa675b545f35a5`,
the same in the release zip and in the `v3.0.0-gamma1` tag on GitHub).
They shift as you edit, so work from the bottom up or search for the anchor text.

All call sites are **player only**: they sit inside DM3's existing
`If(Who == Main.Player)` / `If(self.Actors[Slot] == Main.Player)` branches or
add their own.

| # | Function (gamma1 line) | Edit |
|---|---|---|
| 1 | `MountActor`, the `Who.SetAngle(...)` + `Who.TranslateTo(...)` pair (~625-634) | Wrap both statements in `If(Who != Main.Player)` ... `EndIf`. In VR a live TranslateTo drags the free camera back to the device, and VRIK pins the body instead. NPCs are unchanged. |
| 2 | `MountActor`, inside `If(Who == Main.Player)` after `Who.MoveTo(self)` (~674; the branch starts ~679) | Add `self.DM3VR_Begin(Who,FALSE)` as the **first** line of that branch, before `RegisterForControl("Jump")`. |
| 3 | `MountActor`, same branch (~682) | Replace `Game.ForceThirdPerson()` with `self.DM3VR_Lock(Who,Task,FALSE)`. |
| 4 | `ReleaseActorSlot`, right after `self.NotifyConnectedObjectsActorReleased(self.Actors[Slot],Slot)` (~729) | Add `If(self.Actors[Slot] == Main.Player)` / `self.DM3VR_Unlock(self.Actors[Slot],Pos[1],Pos[2],Pos[3])` / `EndIf`. This must come **before** DM3's `SetPosition` move-away, or the VRIK pin fights the move. |
| 5 | `ReleaseActorSlot`, in the player branch after `Game.EnablePlayerControls()` (~749) | Optional, for parity with the tested build: add `self.Actors[Slot].SetDontMove(FALSE)` and `VRIK.VrikRestoreSettings()`. (`VRFreeCam.Unlock` already does both.) |
| 6 | `InteractActor`, the second `SetAngle` + `TranslateTo` pair (~813-822) | Same wrap as edit 1. |
| 7 | `InteractActor`, inside `If(Who == Main.Player)` after `Who.MoveTo(self)` (~833; the branch starts ~835) | Add `self.DM3VR_Begin(Who,TRUE)` as the first line of the branch. |
| 8 | `InteractActor`, same branch (~838) | Replace `Game.ForceThirdPerson()` with `self.DM3VR_Lock(Who,Task,TRUE)`. |
| 9 | `DetractActor`, right after `Float[] Pos = Main.Util.GetPositionAtDistance(self,50)` (~848) | Add `If(Who == Main.Player)` / `self.DM3VR_Unlock(Who,Pos[1],Pos[2],Pos[3])` / `EndIf`, before the move-away. |
| 10 | `DetractActor`, in the player branch after `Game.EnablePlayerControls()` (~859) | Optional, as edit 5: `Who.SetDontMove(FALSE)` and `VRIK.VrikRestoreSettings()`. |
| 11 | `OnUpdate` inside `State Idle` (~1921), right after `UpdateFreq = self.UpdateFreqUsed` (~1926) | Add `self.DM3VR_Watch()`. |
| 12 | End of file (after the final `EndState`) | Append `src/DM3VR_added_functions.psc` from the `;;;;` rule line above `BEGIN DM3VR BLOCK` to the end. You can skip the header comment above it. |

Never add `SetVehicle`, `tfc`, `ForceThirdPerson` or `TranslateTo` for the player.
