; ============================================================================
; SkyrimVR-VRFreeCam-DM3 v1.0 - added function block (original code only).
; Copyright (c) 2026 Jezebel Graves. MIT License (see LICENSE).
;
; NOT a complete script and NOT a drop-in replacement. It is appended to YOUR
; OWN copy of Display Model SE 3.0 "gamma1" dse_dm_ActiPlaceableBase.psc
; (Display Model SE is not included here). tools/apply_dm3vr.py does that and
; adds the call sites; README.md describes the same edits by hand.
;
; These functions must live inside dse_dm_ActiPlaceableBase: they use its
; Main.Player, DeviceID, DetractActor and ReleaseActor members and the
; device's own position.
; Compile-time imports: VRFreeCam (this repo), x812zl (ZaZ VR Lock source,
; github.com/JezebelGraves/SkyrimVR-VRFreeCam-ZaZ), StorageUtil (PapyrusUtil),
; PO3_SKSEFunctions (Papyrus Extender), HiggsVR (HIGGS).
; Logic is the v0.2 build; the only change is the ZaZ VR Lock plugin name,
; which matches the public ZaZ VR Lock release (ZazVRLock.esp).
; ============================================================================

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; BEGIN DM3VR BLOCK (SkyrimVR-VRFreeCam-DM3): player-only camera/hold routing.
;; Route 2 = ZaZ VR Lock core (external hold API v2) when installed: held camera with
;; view cycle, VRIK body pin, arms + HIGGS hands blocked, guaranteed self-release gesture.
;; Route 1 = plain VRFreeCam (the proven v1.1 behaviour, unchanged) when the core is absent
;; or refuses. DM3 keeps its own packages, menus, Jump release and cleanup in both routes.
;; Never SetVehicle / tfc on the player.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

Int DM3VR_Route = 0
Bool DM3VR_Interact = FALSE
Bool DM3VR_Releasing = FALSE
Bool DM3VR_Locked = FALSE
Int DM3VR_HiggsSnap = 0

Bool Function DM3VR_CoreOK()
	If(Game.GetFormFromFile(0x805,"ZazVRLock.esp") == None)
		Return FALSE
	EndIf
	Return x812zl.ApiVersion() >= 2
EndFunction

Bool Function DM3VR_FirstPerson(Bool Interact)
	; chair main seat (not the interactions) uses the first-person eyes view on plain VRFreeCam.
	Return !Interact && self.DeviceID == "DSE-Chair01"
EndFunction

Function DM3VR_Begin(Actor Who, Bool Interact)
	If(Who != Main.Player || DM3VR_Route != 0)
		Return
	EndIf
	If(self.DM3VR_FirstPerson(Interact))
		If(self.DM3VR_CoreOK() && x812zl.IsLocked())
			Debug.Trace("DM3VR: core busy with another device; no camera change")
			DM3VR_Route = -1
			Return
		EndIf
		DM3VR_Route = 4
		Debug.Trace("DM3VR: first-person eyes route (VRFreeCam)")
		Return
	EndIf
	If(self.DM3VR_CoreOK())
		If(x812zl.ExtBegin(self,"dm3"))
			DM3VR_Route = 2
			self.RegisterForModEvent("x812zl_ExtRelease","OnDM3VRCoreRelease")
			Debug.Trace("DM3VR: core hold claimed on " + self)
			Return
		EndIf
		If(x812zl.IsLocked())
			Debug.Trace("DM3VR: core busy with another device; no camera change")
			DM3VR_Route = -1
			Return
		EndIf
	EndIf
	DM3VR_Route = 1
	Debug.Trace("DM3VR: plain VRFreeCam route")
EndFunction

String Function DM3VR_Event(Package Task)
	If(Task == None)
		Return ""
	EndIf
	Idle[] Idles = PO3_SKSEFunctions.GetPackageIdles(Task)
	If(Idles.Length != 1 || Idles[0] == None)
		Return ""
	EndIf
	Return PO3_SKSEFunctions.GetAnimationEventName(Idles[0])
EndFunction

Function DM3VR_Lock(Actor Who, Package Task, Bool Interact)
	If(Who != Main.Player)
		Return
	EndIf
	DM3VR_Interact = Interact
	If(DM3VR_Route == 0)
		self.DM3VR_Begin(Who,Interact)
	EndIf
	If(DM3VR_Route == 4)
		If(StorageUtil.GetIntValue(None,"VRFreeCam.Active",0) == 1)
			Return ; remount on the same seat: already locked
		EndIf
		VRFreeCam.Lock(Who,self)
		VRFreeCam.SetEyes(Who)
		DM3VR_HiggsSnap = (HiggsVR.IsDisabled(TRUE) as Int) + 2 * (HiggsVR.IsDisabled(FALSE) as Int) + 4
		HiggsVR.DisableHand(TRUE)
		HiggsVR.DisableHand(FALSE)
		Debug.Trace("DM3VR: eyes view locked, HIGGS hands off")
		Return
	EndIf
	If(DM3VR_Route == 2)
		String Ev = self.DM3VR_Event(Task)
		If(Ev != "")
			If(DM3VR_Locked && x812zl.IsExtHeld(self))
				x812zl.ExtSetLoop(Ev)
				Debug.Trace("DM3VR: loop -> " + Ev)
				Return
			EndIf
			Utility.Wait(2.0)
			If(x812zl.ExtLock(self.GetPositionX(),self.GetPositionY(),self.GetPositionZ(),self.GetAngleZ(),Ev))
				; the core enables Activate etc. when it pins: re-apply DM3's own control rule.
				DM3VR_Locked = TRUE
				Game.DisablePlayerControls(FALSE,TRUE,TRUE,FALSE,FALSE,FALSE,TRUE,FALSE,0)
				Debug.Trace("DM3VR: core locked, loop " + Ev)
				Return
			EndIf
			Debug.Trace("DM3VR: core ExtLock failed -> VRFreeCam fallback")
		Else
			Debug.Trace("DM3VR: no single package idle -> VRFreeCam fallback")
		EndIf
		self.UnregisterForModEvent("x812zl_ExtRelease")
		x812zl.ExtRelease("dm3-lock-failed")
		DM3VR_Route = 1
	EndIf
	If(DM3VR_Route == 1)
		VRFreeCam.Lock(Who,self)
	EndIf
EndFunction

Function DM3VR_Unlock(Actor Who, Float PX, Float PY, Float PZ)
	Int Route = DM3VR_Route
	DM3VR_Route = 0
	DM3VR_Locked = FALSE
	If(Route == 2)
		self.UnregisterForModEvent("x812zl_ExtRelease")
		x812zl.ExtRelease("dm3")
	ElseIf(Route == 1)
		VRFreeCam.Unlock(Who,PX,PY,PZ)
	ElseIf(Route == 4)
		VRFreeCam.Unlock(Who,PX,PY,PZ)
		self.DM3VR_HiggsRestore()
	ElseIf(Route == 0)
		If(!(self.DM3VR_CoreOK() && x812zl.IsLocked()))
			VRFreeCam.Unlock(Who,PX,PY,PZ)
		EndIf
	EndIf
EndFunction

Function DM3VR_NativeRelease()
	If(DM3VR_Releasing)
		Return
	EndIf
	DM3VR_Releasing = TRUE
	If(DM3VR_Interact)
		self.DetractActor(Main.Player)
	Else
		self.ReleaseActor(Main.Player)
	EndIf
	DM3VR_Releasing = FALSE
EndFunction

; the core is releasing the player (x812zl.Release hook, rescue, self-release gesture, panic):
; run DM3's own release; its DM3VR_Unlock -> x812zl.ExtRelease is the ack.
Event OnDM3VRCoreRelease(String EvName, String StrArg, Float NumArg, Form Sender)
	If(Sender != self)
		Return
	EndIf
	If(DM3VR_Route == 2)
		Debug.Trace("DM3VR: core release (" + StrArg + ") -> DM3 release")
		self.DM3VR_NativeRelease()
	EndIf
	x812zl.ExtCleanupDone()
EndEvent

; every DM3 update while used: keep the registration and notice a core release that never reached us.
Function DM3VR_Watch()
	If(DM3VR_Route != 2)
		Return
	EndIf
	self.RegisterForModEvent("x812zl_ExtRelease","OnDM3VRCoreRelease")
	If(!x812zl.IsExtHeld(self) && !DM3VR_Releasing)
		Debug.Trace("DM3VR: core no longer holds the player -> DM3 release")
		DM3VR_Route = 3 ; core already restored the player: DM3 cleanup only
		DM3VR_Locked = FALSE
		self.DM3VR_NativeRelease()
	EndIf
EndFunction

Function DM3VR_HiggsRestore()
	If(DM3VR_HiggsSnap == 0)
		Return
	EndIf
	If(Math.LogicalAnd(DM3VR_HiggsSnap,1) == 0)
		HiggsVR.EnableHand(TRUE)
	EndIf
	If(Math.LogicalAnd(DM3VR_HiggsSnap,2) == 0)
		HiggsVR.EnableHand(FALSE)
	EndIf
	DM3VR_HiggsSnap = 0
EndFunction
;; END DM3VR BLOCK
