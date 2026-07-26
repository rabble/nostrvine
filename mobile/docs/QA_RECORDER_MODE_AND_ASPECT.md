# Device QA — recorder mode wheel & capture aspect ratio

Manual test guide for the camera mode wheel, the shape it imposes on captures,
and the post/metadata screen it selects. Written for #6200 (portrait videos
previewing as square) and the related #6148 / #6163 (blank post screen), but
kept topic-scoped because this whole area is sticky, cross-screen, and easy to
regress.

**Run this on a real device.** The defects here depend on fling physics and on
`SharedPreferences` surviving an app restart — neither reproduces reliably in a
simulator or in widget tests.

---

## 1. What was actually wrong

One value — the **last-used recorder mode**, persisted as
`camera_last_used_recorder_mode` — controlled three unrelated things:

1. which mode the camera opens in,
2. the **aspect ratio** stamped onto every clip you record,
3. which **entire post screen UI** you get after recording.

The mode wheel could select a mode you never scrolled onto: an over-fling
resolved to the first or last slot. Because the mode is persisted and re-applied
on every cold start, **one careless swipe changed your recording shape
permanently** — closing and reopening the app did not clear it.

In the 1.0.16 build both end slots were hazards:

| over-swipe | mode selected | what you saw |
|---|---|---|
| hard **left** | `Upload` | post screen renders nothing — black, no back button, had to force-quit |
| hard **right** | `Classic` | portrait recordings previewed as **square** |

The exported/published video was still correct portrait — only the preview lied.
That is why affected users' posted videos look fine on the relay.

---

## 2. Before you start

**Build**: this branch, on a physical iPhone and (ideally) a physical Android
device. iOS 26.x is where it was reported.

**Resetting state between runs — read this, it is the main gotcha.**
The mode is sticky. If a test leaves you in `Classic`, the next test starts in
`Classic`. To get back to a known state, do one of:

- open the camera and **tap** (do not swipe) the `Capture` label, or
- delete and reinstall the app for a genuinely clean slate.

Record which mode you are in at the start of every test below. If a result looks
wrong, check the mode first.

**Recording shape reference**: `Classic` is the 1:1 Vine format and is *supposed*
to be square. Every other mode should give you portrait unless you deliberately
toggle the shape in Capture mode.

---

## 3. Test matrix

### T1 — the wheel cannot jump to an end slot *(the core fix)*

1. Open the camera. Tap `Capture` so you start from a known slot.
2. **Fling the mode wheel hard to the right** (a fast flick, not a slow drag).
3. Observe which mode ends up selected.
4. Repeat with a **hard fling to the left**.
5. Repeat both from every other starting mode.

**Expected**: each fling advances **one slot at a time**. You never land on the
far end of the wheel from a single gesture.
**Pre-fix**: a hard fling jumped straight to the last (or first) mode.

> Tapping a mode label directly should still jump anywhere instantly — that path
> is deliberately unrestricted. Verify tapping a distant mode still works.

### T2 — switching modes does not silently change your shape

> The shape toggle in `Capture` mode (the square/portrait crop icon) is
> **disabled once you have recorded clips** — it only works on an empty
> timeline. Discard any clips before starting this test, or the control will
> look broken.

1. In `Capture` mode with no clips recorded, tap the crop icon to select
   **square**.
2. Switch to `Lip Sync`, then back to `Capture`.

**Expected**: still square — your explicit choice survived.
**Pre-fix**: every mode change reset the shape to the mode's default.

3. Now from `Capture` (portrait), switch to `Classic`.

**Expected**: square — Classic legitimately forces 1:1.

4. Switch from `Classic` back to `Capture`.

**Expected**: back to portrait. Classic's square must not leak into Capture.

### T3 — the shape does not survive a restart it shouldn't

1. Put the wheel on `Capture` with portrait selected.
2. Force-quit the app completely (swipe it away, not just background it).
3. Reopen and go to the camera.

**Expected**: still `Capture`, still portrait.
**Pre-fix**: if the persisted mode was `Classic`, every launch silently re-forced
square, with no way to notice except the viewfinder shape.

### T4 — portrait recording previews as portrait *(the reported bug)*

1. In `Capture` mode with portrait selected, record a short video.
2. Continue to the post/metadata screen.
3. Tap the preview (eye) control if present.

**Expected**: the video is previewed **portrait**, matching the viewfinder and
matching what gets published. No square letterbox or square crop anywhere in the
flow — viewfinder, editor, cover picker, post screen, full-screen preview.

4. Now switch to `Classic`, record, and go to the post screen.

**Expected**: previewed **square** — correct for Classic.

### T5 — no blank post screen *(#6148 / #6163)*

1. Try to reach the post/metadata screen from every mode: `Capture`, `Lip Sync`,
   `Stop Motion`, `Classic`, and after restoring a saved draft from the Library.

**Expected**: you always get a real post screen with a visible app bar and a way
back. Never a blank/black screen that traps you.
**Pre-fix**: with `Upload` persisted, the post screen rendered nothing and the
only escape was force-quitting the app.

### T6 — "Square only" feed filter actually filters *(#3882)*

1. Settings → General Settings → video shape → **"Square videos only"**
   (*"Keep feeds in the classic square format"*).
2. Return to the feed and scroll a good distance (For You, and the other tabs).

**Expected**: portrait videos are actually hidden; you see square content only.
**Pre-fix**: the setting did nothing at all — the app never received video
dimensions from the API, so it could not tell the shapes apart.

3. Switch back to **"Square and portrait"** (*"Show the full mix of Divine
   videos"*) and confirm portrait videos return.

> This one needs network. It is the only test here that depends on live API
> responses rather than local state.

### T7 — publishing is unchanged (regression guard)

1. Record and publish one portrait video and one Classic (square) video.
2. Check both on another client or the web app.

**Expected**: the portrait one is portrait (1080×1920), the Classic one is
square. Publishing behaviour must not have changed — only the preview was ever
wrong.

---

## 4. What to report

For any failure, capture:

- the **mode** the wheel was on and how you got there (tap vs swipe direction),
- whether the app had been **force-quit** since that mode was chosen,
- a **screenshot or screen recording** — for shape bugs the width of the video
  box distinguishes the surfaces, and the app's own logs cannot tell us which
  screen you were on,
- the exported video, if it disagrees with the preview.

A screenshot is worth more than a log export here: the bug-report log capture
keeps only errors and warnings from before the last few seconds, so it does not
record which screen was on-screen when you noticed the problem.
