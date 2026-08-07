---
name: flutter-macos-tcc-responsible-process-camera-denial
description: |
  Fix black camera/microphone preview in Flutter macOS apps launched via `flutter run`
  from a terminal emulator (cmux, iTerm, Terminal.app, VS Code integrated terminal,
  Cursor, etc.). Use when: (1) camera plugin reports initialized but preview is black
  with no frames, (2) logs show "initialization completed via timeout" or similar
  first-frame timeout fallback, (3) AVCaptureSession.startRunning() returns without
  error but zero frames arrive, (4) the app's Info.plist has NSCameraUsageDescription
  and entitlements (com.apple.security.device.camera, audio-input) are correctly set,
  (5) no permission dialog ever appears, (6) same failure mode for microphone. Root
  cause is macOS TCC attributing camera/mic requests to the *responsible process*
  (the parent terminal) rather than the Flutter app itself. TCC refuses to prompt
  because the terminal is hardened-runtime without a camera entitlement, and silently
  denies. Not a bug in the camera plugin — would reproduce with ANY camera code.
author: Claude Code
version: 1.0.0
date: 2026-04-05
---

# Flutter macOS TCC Responsible-Process Camera Denial

## Problem

A Flutter macOS app that should have camera/microphone access shows a black preview
(or returns zero frames) even though:

- `NSCameraUsageDescription` and `NSMicrophoneUsageDescription` are present in
  `macos/Runner/Info.plist`.
- `com.apple.security.device.camera` and `com.apple.security.device.audio-input`
  are `true` in both `DebugProfile.entitlements` and `Release.entitlements`.
- The native camera plugin reports `isInitialized: true` and returns a texture ID.
- No permission dialog ever appears.
- No errors are logged by the camera plugin or AVFoundation.

The symptom is usually a "timeout fallback" firing in the plugin (e.g.
`DivineCamera macOS: Initialization completed via timeout`, or similar 2-second
init guards) because the plugin is waiting for a first sample buffer that never
arrives. Camera metadata from the plugin shows `iso: 0.0, exposureDuration: 0.0,
aperture: 0.0` — the device was enumerated but never actually started delivering
samples.

## Context / Trigger Conditions

All of the following are true:

1. App was launched via `flutter run -d macos` (or via `flutter run` from an IDE
   that wraps flutter in a terminal — VS Code, Cursor, Android Studio, cmux).
2. The terminal emulator is a hardened-runtime app **without** camera/mic
   entitlements in its own code signature.
3. macOS version is 10.15+ (TCC enforcement tightened; affects Big Sur onwards,
   intensifies on Sequoia/Tahoe).
4. No explicit `AVCaptureDevice.requestAccess(for: .video)` call in the plugin,
   OR the call is being attributed to the wrong process.

Specifically, this is NOT:

- `flutter-macos-permission-handler-camera-failure` (that's about permission_handler
  plugin silently failing to bridge to TCC).
- `flutter-macos-duplicate-camera-plugin` (that's a build error).
- A missing Info.plist entry (the usage description IS present).
- A missing entitlement (the entitlement IS present).

## Root Cause

macOS TCC attributes permission requests to the **responsible process**, not the
accessing process. When `flutter run` launches the .app as a child of the terminal,
TCC walks the process tree and picks the terminal as the "responsible" party for
any protected resource access. This is the same mechanism that causes "Terminal
wants access to ..." prompts instead of prompts for individual scripts.

For camera/microphone specifically, TCC enforces that the responsible process has
the matching entitlement. If cmux / iTerm / VS Code / etc. is the responsible
process and it's hardened-runtime without `com.apple.security.device.camera`,
TCC logs:

```
tccd: Prompting policy for hardened runtime;
  service: kTCCServiceCamera requires entitlement com.apple.security.device.camera
  but it is missing for responsible={identifier=<terminal>, ...}
  accessing={identifier=<YourApp>, binary_path=.../YourApp.app/Contents/MacOS/YourApp}
tccd: Policy disallows prompt for Sub:{<terminal>}; access to kTCCServiceCamera denied
```

Critically: **TCC will not even show the user a prompt.** It silently denies. From
the app's perspective, `AVCaptureSession.startRunning()` returns without error but
zero sample buffers are ever produced, so any first-frame timeout in the plugin
fires eventually.

## Diagnosis

Run this while (or just after) reproducing the failure:

```bash
/usr/bin/log show --last 10m --predicate 'subsystem == "com.apple.TCC"' --info 2>&1 \
  | grep -iE "camera|microphone|<YourAppName>|Runner" \
  | tail -40
```

You are looking for the phrase:

```
Policy disallows prompt for Sub:{<terminal.bundle.id>}...;
access to kTCCServiceCamera denied
```

and the `AttributionChain` showing `responsible={identifier=<terminal>}` and
`accessing={identifier=<YourApp>}`. Presence of these lines confirms the diagnosis.

Reading the TCC database directly (`~/Library/Application Support/com.apple.TCC/TCC.db`)
will fail with "authorization denied" unless Terminal has Full Disk Access — the
`log show` approach is the reliable way.

## Solution

### Immediate fix (smoke test)

Launch the .app bundle via Launch Services instead of `flutter run`. Launch Services
makes the app its own responsible process, so TCC will prompt the user and attribute
the request to the app itself (which does have the entitlement).

```bash
# Build once via flutter
cd <project>/mobile
flutter build macos --debug

# Then launch via `open` — NOT via `flutter run`
open build/macos/Build/Products/Debug/<YourApp>.app
```

`open` routes through `launchd`/LaunchServices, so the responsible process becomes
`<YourApp>` rather than the terminal. On first launch from a state where TCC has no
entry for the app, macOS will show the standard permission prompt.

### If TCC already cached the denied state

If you had previously launched via `flutter run`, TCC may have cached a denied entry
attributed to the terminal. Reset it:

```bash
# Narrow scope: reset only this app's permissions
tccutil reset Camera <your.app.bundle.id>
tccutil reset Microphone <your.app.bundle.id>

# Or broad reset (re-prompts for EVERY app that uses camera/mic):
tccutil reset Camera
tccutil reset Microphone
```

Then relaunch via `open`.

### Long-term fix (shipping apps)

This issue only affects `flutter run` from a terminal. Production .app bundles
distributed to end users (via DMG, Mac App Store, notarized download) launch via
LaunchServices and don't hit this. No code fix is needed for release builds.

For a better developer experience, plugins should call
`AVCaptureDevice.requestAccess(for: .video)` (and `.audio`) explicitly before
starting the capture session. This doesn't change the `flutter run` TCC outcome
(TCC still attributes to the terminal), but it provides a clear `granted=false`
error path instead of a silent frame-timeout.

```swift
AVCaptureDevice.requestAccess(for: .video) { videoGranted in
    guard videoGranted else {
        completion(nil, "Camera permission denied")
        return
    }
    AVCaptureDevice.requestAccess(for: .audio) { _ in
        // audio denial can be non-fatal; continue without audio input
        self.sessionQueue.async { self.setupCamera(completion: completion) }
    }
}
```

## Verification

After launching via `open`:

1. macOS should show a standard system prompt: "YourApp would like to access the
   camera." Grant it.
2. Camera preview should appear in the app within ~1 second (no timeout fallback).
3. `log show --last 2m --predicate 'subsystem == "com.apple.TCC"'` should show
   `authorized` instead of `denied`, and the responsible process should be the app
   itself.
4. Plugin metadata should report non-zero `iso` and `exposureDuration` values —
   confirming the AVCaptureDevice is actually running.

If the preview is still black after all this, investigate separately (it's a
real bug in the plugin code, not a TCC issue).

## Example Session

**Symptom observed:** Flutter macOS app under review (PR adding native macOS camera
support) launched via `flutter run` from cmux. Camera UI rendered, plugin reported
`isInitialized: true`, but preview was black and log showed
`DivineCamera macOS: Initialization completed via timeout`. Initial (wrong)
hypothesis: the plugin's Swift code was missing an `AVCaptureDevice.requestAccess`
call.

**Diagnostic run:**
```bash
/usr/bin/log show --last 15m --predicate 'subsystem == "com.apple.TCC"' --info \
  | grep -iE "camera|Divine"
```

**Evidence found:**
```
tccd: Prompting policy for hardened runtime; service: kTCCServiceCamera
  requires entitlement com.apple.security.device.camera but it is missing for
  responsible={identifier=com.cmuxterm.app, ...}
  accessing={identifier=Divine, binary_path=.../Divine.app/.../Divine}
tccd: Policy disallows prompt for Sub:{com.cmuxterm.app}...;
  access to kTCCServiceCamera denied
```

**Conclusion:** cmux was the responsible process, not Divine. The plugin was
innocent — same failure would have occurred with any camera plugin.

**Fix applied:**
```bash
cd mobile && flutter build macos --debug
open build/macos/Build/Products/Debug/Divine.app
```

App prompted for camera permission on first launch, user granted, preview worked.

## Notes

- **Which terminal emulators are affected:** Any hardened-runtime terminal that
  doesn't request the camera entitlement. cmux, iTerm2, Terminal.app, Warp, VS Code
  integrated terminal, Cursor integrated terminal, Android Studio integrated
  terminal. Essentially all of them.
- **Does giving the terminal camera access help?** In principle yes (System
  Settings > Privacy & Security > Camera > enable the terminal), but most terminals
  are hardened-runtime-signed without the camera entitlement so the checkbox isn't
  offered. The `open` workaround is more reliable.
- **Why the error message is misleading:** The plugin logs "initialization completed
  via timeout" — that log is technically true (the 2-second init guard fired) but
  says nothing about WHY no frames arrived. The real answer is only in the TCC
  subsystem log, which most developers never check.
- **Also affects:** Microphone (`kTCCServiceMicrophone`), screen recording
  (`kTCCServiceScreenCapture`), contacts, calendar — any TCC-protected resource
  when launched via a terminal without the matching entitlement. The same
  `log show` + `open` workflow applies.
- **Does `flutter run` have a fix?** No. The Flutter tool invokes the app as a
  subprocess; there's no way to make Flutter-the-tool drop out of the
  responsibility chain. Apple provides no API for an app to claim its own TCC
  responsibility. You either use `open`, or accept the first-launch friction in
  development.
- **Related but different:** `flutter-macos-permission-handler-camera-failure`
  covers the permission_handler Dart plugin failing to bridge to TCC. That's a
  different failure mode where the plugin itself is silent; this skill covers
  TCC being silent before the plugin ever gets a chance to ask.

## References

- Apple Developer Forums: "App launched from Terminal inherits Terminal's TCC
  responsibility" (search DTS / Quinn "The Eskimo!" posts on TCC).
- Apple Technical Note TN3127: "Inside Code Signing: Requirements" — covers
  responsible-process attribution.
- `man tccutil` — `reset [service] [bundleID]` syntax.
- `log show --predicate 'subsystem == "com.apple.TCC"'` — the authoritative
  source of truth for what TCC actually did.
