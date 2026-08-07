---
name: macos-tcc-sigkill-missing-usage-description
description: |
  Fix macOS app hard crashes (EXC_CRASH / SIGKILL) caused by accessing TCC-protected
  APIs without the matching Info.plist usage description key. Use when: (1) App
  crashes immediately when touching Photos, Contacts, Calendar, Reminders, Location,
  Microphone, Camera, Screen Recording, etc., (2) Crash report shows
  `Exception: EXC_CRASH (SIGKILL)` with `Termination namespace: TCC`, (3) Crash
  stack includes `TCC.__TCC_CRASHING_DUE_TO_PRIVACY_VIOLATION__`, (4) Termination
  details contain "This app has crashed because it attempted to access
  privacy-sensitive data without a usage description", (5) Flutter macOS publish /
  gallery-save flow crashes on Gal.putVideo, PHPhotoLibrary, CNContactStore, etc.
  Critical distinction: macOS does NOT return a deny error — it SIGKILLs the
  process. This skill also covers the NSPhotoLibraryUsageDescription vs
  NSPhotoLibraryAddUsageDescription distinction that trips many apps.
author: Claude Code
version: 1.0.0
date: 2026-04-05
---

# macOS TCC SIGKILL: Missing Info.plist Usage Description

## Problem

A macOS app crashes with `EXC_CRASH (SIGKILL)` the instant it calls a
privacy-protected API. There is no chance to handle the error, no permission
prompt, no deny response — just immediate process termination by the OS.

The crash is caused by macOS TCC enforcement: if your app links against or
calls an API that accesses a privacy-protected resource and your Info.plist
does NOT contain the matching usage-description key, the OS kills the process
for privacy violation.

## Context / Trigger Conditions

Crash report (`~/Library/Logs/DiagnosticReports/<App>-*.ips`) has all of these:

- `"exception": { "type": "EXC_CRASH", "signal": "SIGKILL" }`
- `"termination": { "namespace": "TCC", ... }`
- Termination details string contains: **"This app has crashed because it
  attempted to access privacy-sensitive data without a usage description"**
- The crashed thread stack includes `TCC.__TCC_CRASHING_DUE_TO_PRIVACY_VIOLATION__`
- Frames below that are usually `TCC.__TCCAccessRequest_block_invoke`,
  `libxpc.dylib._xpc_connection_reply_callout`, dispatch queue machinery

The termination details string tells you exactly which key is missing — read it.

## The Info.plist Key Map

| Resource | Info.plist key | Entitlement (sandboxed apps) |
|---|---|---|
| Camera | `NSCameraUsageDescription` | `com.apple.security.device.camera` |
| Microphone | `NSMicrophoneUsageDescription` | `com.apple.security.device.audio-input` |
| Photos (read/write) | `NSPhotoLibraryUsageDescription` | `com.apple.security.personal-information.photos-library` |
| Photos (add-only) | `NSPhotoLibraryAddUsageDescription` | `com.apple.security.photos.library.add-only` |
| Contacts | `NSContactsUsageDescription` | `com.apple.security.personal-information.addressbook` |
| Calendar | `NSCalendarsUsageDescription` | `com.apple.security.personal-information.calendars` |
| Reminders | `NSRemindersUsageDescription` | `com.apple.security.personal-information.reminders` |
| Location | `NSLocationUsageDescription` (+ `WhenInUse` / `Always` variants) | `com.apple.security.personal-information.location` |
| Speech recognition | `NSSpeechRecognitionUsageDescription` | — |
| Desktop folder | `NSDesktopFolderUsageDescription` | `com.apple.security.files.user-selected.read-only` etc. |
| Documents folder | `NSDocumentsFolderUsageDescription` | — |
| Downloads folder | `NSDownloadsFolderUsageDescription` | `com.apple.security.files.downloads.read-write` |

### The Photos trap (critical)

`NSPhotoLibraryAddUsageDescription` is **not** a substitute for
`NSPhotoLibraryUsageDescription`. They cover different permission scopes:

- **Add-only** (`NSPhotoLibraryAddUsageDescription` + `com.apple.security.photos.library.add-only`):
  sufficient for APIs that only *save* an asset, like `PHAssetCreationRequest`
  from a file, or `Gal.putVideo(path)` with no album.
- **Full access** (`NSPhotoLibraryUsageDescription`):
  required for any read, any query, any album lookup/creation, and notably for
  `Gal.putVideo(path, album: 'SomeAlbum')` — because "put into album X" has to
  read or create the album, which is a library-level operation.

Symptom of getting this wrong: save-without-album works, save-with-album crashes.

## Solution

1. Read the crash report's termination details — it names the exact key.
2. Add the key to your app's Info.plist:
   - Flutter macOS: `mobile/macos/Runner/Info.plist`
   - Native macOS: `<target>/Info.plist` or the target's `INFOPLIST_FILE` build setting
3. If the app is sandboxed (`com.apple.security.app-sandbox` = true in release),
   also add the matching entitlement to both
   `Runner/DebugProfile.entitlements` and `Runner/Release.entitlements`.
4. Rebuild. Info.plist changes do not hot-reload in Flutter — a full
   `flutter build macos --debug` is required.
5. Relaunch the app.

## Example patch

Flutter macOS app crashing on `gal.putVideo(path, album: 'MyAlbum')`:

```xml
<!-- mobile/macos/Runner/Info.plist -->
<key>NSPhotoLibraryAddUsageDescription</key>
<string>MyApp needs access to save videos to your Photos library.</string>
<!-- ADD THIS: -->
<key>NSPhotoLibraryUsageDescription</key>
<string>MyApp needs access to your Photos library to organize videos into albums.</string>
```

Then:
```bash
cd mobile
flutter build macos --debug
open build/macos/Build/Products/Debug/MyApp.app
```

## Verification

1. No crash on the action that previously crashed.
2. macOS shows a permission prompt the first time (if status is `.notDetermined`).
3. Check the new crash reports directory — no new `.ips` files should appear
   after the action:
   ```bash
   ls -t ~/Library/Logs/DiagnosticReports/<AppName>-*.ips 2>/dev/null | head -3
   ```
4. Verify the built .app bundle contains the key (Info.plist is copied in during
   build, but sanity-check):
   ```bash
   grep -A1 NSPhotoLibrary build/macos/Build/Products/Debug/MyApp.app/Contents/Info.plist
   ```
5. `log show --last 2m --predicate 'subsystem == "com.apple.TCC"'` should show
   an authorization grant for the app's bundle ID instead of a crash.

## Diagnosing from the crash report

A fast one-liner to extract the key info from a .ips crash report:

```bash
python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    f.readline()  # skip header JSON line
    d = json.loads(f.read())
print('Signal:', d.get('exception', {}).get('signal'))
print('Namespace:', d.get('termination', {}).get('namespace'))
print('Details:', d.get('termination', {}).get('details'))
" ~/Library/Logs/DiagnosticReports/MyApp-*.ips
```

If `namespace == 'TCC'` and details mention "usage description", this skill
applies.

## Notes

- **Why SIGKILL and not a graceful deny?** Apple decided privacy violations
  are a policy failure of the developer, not a runtime condition to handle.
  The OS terminates the process so there is no way for an app to "try anyway"
  or log workarounds. There is no API to catch this.
- **It applies even to code paths you do not call.** If a linked framework or
  plugin touches a protected resource on your behalf (e.g. a media plugin that
  probes Photos on init), you need the usage description even if your own code
  never touches Photos. This is why the key should be added whenever you
  include a plugin that *might* access the resource.
- **Hot reload will not rescue you.** Flutter hot reload and hot restart do
  not update Info.plist in the running bundle. You must fully rebuild.
- **iOS vs macOS:** The same keys exist on iOS, but on iOS a missing key
  usually results in a silent deny rather than SIGKILL on older iOS versions.
  Recent iOS versions align with macOS and will crash. Either way, always set
  the key.
- **The "Add" vs full Photos distinction was tightened in macOS 14/15/26.**
  Earlier macOS versions let you do some album operations with add-only; recent
  releases do not. If an app that worked on older macOS starts crashing after
  a macOS upgrade, check for this first.
- **Related but different:** `flutter-macos-tcc-responsible-process-camera-denial`
  covers TCC denying camera access when the responsible process attribution
  is wrong (no crash, just silent denial). That is a different TCC failure
  mode than the SIGKILL covered here.

## References

- Apple: [Requesting access to protected resources](https://developer.apple.com/documentation/bundleresources/information_property_list/protected_resources)
- Apple: [`NSPhotoLibraryUsageDescription`](https://developer.apple.com/documentation/bundleresources/information_property_list/nsphotolibraryusagedescription)
- Apple: [`NSPhotoLibraryAddUsageDescription`](https://developer.apple.com/documentation/bundleresources/information_property_list/nsphotolibraryaddusagedescription)
- Apple Developer Forums search: "TCC privacy violation SIGKILL Info.plist"
- `log show --predicate 'subsystem == "com.apple.TCC"'` for live TCC decisions.
