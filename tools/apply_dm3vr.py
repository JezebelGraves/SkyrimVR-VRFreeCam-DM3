#!/usr/bin/env python3
"""Apply the DM3VR edits to YOUR OWN copy of Display Model SE 3.0 "gamma1"
scripts/source/dse_dm_ActiPlaceableBase.psc.

Copyright (c) 2026 Jezebel Graves. MIT License (see LICENSE).

Usage:
    python apply_dm3vr.py <path to stock dse_dm_ActiPlaceableBase.psc> <output .psc>

The input is never modified. The script refuses to run unless the input is the
unmodified gamma1 file (sha256 below). Every edit is anchored on exact gamma1
text and must match the expected number of times, otherwise nothing is written.
Line endings of the input are preserved.
"""
import hashlib
import os
import sys

GAMMA1_SHA256 = "3a7689bb13ed1779879cbc63878b4bfd2eaeac67e70a8a1de9aa675b545f35a5"
HERE = os.path.dirname(os.path.abspath(__file__))
BLOCK = os.path.join(HERE, "..", "src", "DM3VR_added_functions.psc")

TRANSLATE_OLD = (
    "\tWho.SetAngle(0.0,0.0,self.GetAngleZ())\n"
    "\tWho.TranslateTo(               \\\n"
    "\t\tself.GetPositionX(),       \\\n"
    "\t\tself.GetPositionY(),       \\\n"
    "\t\tself.GetPositionZ(),       \\\n"
    "\t\tself.GetAngleX(),          \\\n"
    "\t\tself.GetAngleY(),          \\\n"
    "\t\t(self.GetAngleZ() + 0.01), \\\n"
    "\t\t10000,0.000001             \\\n"
    "\t)\n"
)


def translate_new():
    inner = "".join("\t" + ln + "\n" for ln in TRANSLATE_OLD.rstrip("\n").split("\n"))
    return (
        "\t; DM3VR: never rotate/translate the player; VRIK pins the body instead.\n"
        "\tIf(Who != Main.Player)\n" + inner + "\tEndIf\n"
    )


def replace_nth(text, old, new_list):
    """Replace each occurrence of old, in order, with new_list[i]."""
    if text.count(old) != len(new_list):
        raise SystemExit("anchor count mismatch (%d != %d) for: %r"
                         % (text.count(old), len(new_list), old[:60]))
    out, pos = [], 0
    for new in new_list:
        i = text.index(old, pos)
        out.append(text[pos:i])
        out.append(new)
        pos = i + len(old)
    out.append(text[pos:])
    return "".join(out)


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]
    raw = open(src, "rb").read()
    digest = hashlib.sha256(raw).hexdigest()
    if digest != GAMMA1_SHA256:
        raise SystemExit("input is not the stock gamma1 file (sha256 %s); refusing." % digest)
    crlf = b"\r\n" in raw
    t = raw.decode("utf-8").replace("\r\n", "\n")

    # 1) MountActor + InteractActor: skip SetAngle/TranslateTo for the player.
    t = replace_nth(t, TRANSLATE_OLD, [translate_new(), translate_new()])

    # 2) claim the route before DM3 changes controls (mount = FALSE, interact = TRUE).
    a = "If(Who == Main.Player)\n\t\tself.RegisterForControl(\"Jump\")"
    t = replace_nth(t, a, [
        "If(Who == Main.Player)\n\t\tself.DM3VR_Begin(Who,FALSE) ; DM3VR\n\t\tself.RegisterForControl(\"Jump\")",
        "If(Who == Main.Player)\n\t\tself.DM3VR_Begin(Who,TRUE) ; DM3VR\n\t\tself.RegisterForControl(\"Jump\")",
    ])

    # 3) replace ForceThirdPerson (spins/breaks the VR camera) with the VRFreeCam lock.
    t = replace_nth(t, "\t\tGame.ForceThirdPerson()\n", [
        "\t\tself.DM3VR_Lock(Who,Task,FALSE) ; DM3VR\n",
        "\t\tself.DM3VR_Lock(Who,Task,TRUE) ; DM3VR\n",
    ])

    # 4) ReleaseActorSlot: unlock BEFORE DM3's SetPosition move-away.
    a = "\tself.NotifyConnectedObjectsActorReleased(self.Actors[Slot],Slot)\n"
    t = replace_nth(t, a, [a +
        "\n\t; DM3VR: drop the VRIK pin before the move-away below.\n"
        "\tIf(self.Actors[Slot] == Main.Player)\n"
        "\t\tself.DM3VR_Unlock(self.Actors[Slot],Pos[1],Pos[2],Pos[3]) ; DM3VR\n"
        "\tEndIf\n"])

    # 5) DetractActor: same ordering.
    a = ("Function DetractActor(Actor Who)\n{stop an interaction.}\n\n"
         "\tFloat[] Pos = Main.Util.GetPositionAtDistance(self,50)\n")
    t = replace_nth(t, a, [a +
        "\n\t; DM3VR: drop the VRIK pin before the move-away below.\n"
        "\tIf(Who == Main.Player)\n"
        "\t\tself.DM3VR_Unlock(Who,Pos[1],Pos[2],Pos[3]) ; DM3VR\n"
        "\tEndIf\n"])

    # 6) belt and braces after DM3's own EnablePlayerControls (VRFreeCam.Unlock already does this).
    a = "\tIf(self.Actors[Slot] == Main.Player)\n\t\tself.UnregisterForControl(\"Jump\")\n\t\tGame.EnablePlayerControls()\n"
    t = replace_nth(t, a, [a + "\t\tself.Actors[Slot].SetDontMove(FALSE) ; DM3VR\n\t\tVRIK.VrikRestoreSettings() ; DM3VR\n"])
    a = "\tIf(Who == Main.Player)\n\t\tself.UnregisterForControl(\"Jump\")\n\t\tGame.EnablePlayerControls()\n"
    t = replace_nth(t, a, [a + "\t\tWho.SetDontMove(FALSE) ; DM3VR\n\t\tVRIK.VrikRestoreSettings() ; DM3VR\n"])

    # 7) periodic watch while the device is in use (notices a ZaZ VR Lock core release).
    a = "\t\t\tUpdateFreq = self.UpdateFreqUsed\n"
    t = replace_nth(t, a, [a + "\t\t\tself.DM3VR_Watch() ; DM3VR\n"])

    # 8) append the DM3VR block (from the BEGIN marker on).
    block = open(BLOCK, "rb").read().decode("utf-8").replace("\r\n", "\n")
    i = block.index(";; BEGIN DM3VR BLOCK")
    i = block.rindex("\n", 0, i) + 1  # include the ;;;; rule line above the marker
    i = block.rindex("\n", 0, i - 1) + 1
    t = t.rstrip("\n") + "\n\n" + block[i:].rstrip("\n") + "\n"

    if crlf:
        t = t.replace("\n", "\r\n")
    with open(dst, "wb") as f:
        f.write(t.encode("utf-8"))
    print("wrote", dst)


if __name__ == "__main__":
    main()
