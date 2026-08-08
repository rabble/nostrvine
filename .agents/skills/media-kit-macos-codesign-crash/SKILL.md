---
name: media-kit-macos-codesign-crash
description: |
  Fix Flutter macOS app crash at launch due to media_kit library loading failure. Use when:
  (1) macOS app builds successfully but crashes immediately on launch, (2) Crash log shows
  "Library not loaded: @rpath/Ass.framework" or similar media_kit framework, (3) Error says
  "code signature not valid for use in process: Trying to load an unsigned library",
  (4) Problem appears after flutter clean or fresh clone, (5) Codesign script exists in
  Podfile but frameworks are still unsigned after build - check build phase ORDER.
  Fixes unsigned media_kit native frameworks (Ass.framework, Avcodec.framework, etc.)
  by adding post-build codesigning AND ensuring correct build phase ordering.
author: Claude Code
version: 2.0.0
date: 2026-02-22
---

# Media Kit macOS Codesign Crash Fix

## Problem

Flutter macOS apps using `media_kit` (video player library) crash immediately at launch after
a clean build. The app builds successfully but fails to start due to unsigned native frameworks.

## Context / Trigger Conditions

- macOS Flutter app using `media_kit` or `media_kit_video` package
- App builds without errors: "Built build/macos/Build/Products/Debug/divine.app"
- App crashes immediately on launch with no UI appearing
- Crash report or console shows:
  ```
  Library not loaded: @rpath/Ass.framework/Versions/A/Ass
  Reason: code signature in '...' not valid for use in process: Trying to load an unsigned library
  ```
- Often occurs after `flutter clean`, `pod deintegrate` + `pod install`, or fresh git clone
- **CRITICAL**: Can also occur when the codesign script EXISTS but runs in the wrong order

## Root Cause: Build Phase Ordering

The most common cause (especially after `pod deintegrate` + `pod install`) is that the Xcode
build phases end up in the wrong order:

**WRONG order** (codesign runs before frameworks are copied):
```
1. [CP] Check Pods Manifest.lock
2. Sources
3. Frameworks
4. Resources
5. Bundle Framework
6. ShellScript (Flutter assemble)
7. Codesign media_kit frameworks    ← SIGNS NOTHING (frameworks not embedded yet)
8. [CP] Embed Pods Frameworks       ← copies frameworks into app bundle
```

**CORRECT order** (embed first, then codesign):
```
1. [CP] Check Pods Manifest.lock
2. Sources
3. Frameworks
4. Resources
5. Bundle Framework
6. ShellScript (Flutter assemble)
7. [CP] Embed Pods Frameworks       ← copies frameworks into app bundle
8. Codesign media_kit frameworks    ← signs the embedded frameworks
9. FlutterFire upload symbols        ← (if applicable, should be last)
```

## Solution

### Step 1: Add Codesign Phase via Podfile (if missing)

Add this block inside the `post_install do |installer|` section:

```ruby
post_install do |installer|
  # Add script phase to codesign media_kit frameworks (fixes unsigned library crash)
  installer.pods_project.targets.each do |target|
    if target.name == 'media_kit_libs_macos_video'
      target.build_configurations.each do |config|
        config.build_settings['CODE_SIGN_IDENTITY'] = '-'
      end
    end
  end

  # Also add codesigning to the main project's frameworks
  main_project = installer.aggregate_targets.first.user_project
  main_project.targets.each do |target|
    if target.name == 'Runner'
      # Check if script phase already exists
      phase_name = 'Codesign media_kit frameworks'
      existing_phase = target.shell_script_build_phases.find { |p| p.name == phase_name }

      unless existing_phase
        phase = target.new_shell_script_build_phase(phase_name)
        phase.shell_script = <<-SCRIPT
# Codesign media_kit frameworks with ad-hoc signature
for framework in "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app/Contents/Frameworks"/*.framework; do
  if [ -d "$framework" ]; then
    codesign --force --deep --sign - "$framework" 2>/dev/null || true
  fi
done
        SCRIPT
        phase.shell_path = '/bin/bash'
      end
    end
  end
  main_project.save

  # ... rest of your existing post_install code ...
```

### Step 2: Verify Build Phase Ordering (CRITICAL)

The Podfile adds the codesign phase but **cannot guarantee ordering**. After `pod install`,
check `macos/Runner.xcodeproj/project.pbxproj` for the Runner target's `buildPhases` array.

Search for the `buildPhases` block in the Runner native target section. Ensure this order:

```
[CP] Embed Pods Frameworks          ← MUST be BEFORE codesign
Codesign media_kit frameworks       ← MUST be AFTER embed
FlutterFire: upload symbols         ← SHOULD be last (if present)
```

If the order is wrong, swap the lines in the `buildPhases` array. Example fix:

```diff
 buildPhases = (
     ...
     3399D490228B24CF009A79C7 /* ShellScript */,
-    9AD7FD721DF2C6A84F6A1FC3 /* Codesign media_kit frameworks */,
-    51BD49356784271F7E3B2B6C /* [CP] Embed Pods Frameworks */,
-    BBC532B406767D40236ED3DB /* FlutterFire: "flutterfire upload-crashlytics-symbols" */,
+    51BD49356784271F7E3B2B6C /* [CP] Embed Pods Frameworks */,
+    9AD7FD721DF2C6A84F6A1FC3 /* Codesign media_kit frameworks */,
+    BBC532B406767D40236ED3DB /* FlutterFire: "flutterfire upload-crashlytics-symbols" */,
 );
```

### Step 3: Rebuild

```bash
flutter clean
flutter pub get
cd macos && pod install && cd ..
flutter run -d macos
```

### Emergency Quick Fix (Manual Codesign)

If you need the app running NOW before fixing build phases:

```bash
for fw in build/macos/Build/Products/Debug/<app>.app/Contents/Frameworks/*.framework; do
  codesign --force --deep --sign - "$fw"
done
codesign --force --deep --sign - "build/macos/Build/Products/Debug/<app>.app"
open "build/macos/Build/Products/Debug/<app>.app"
```

## Verification

1. Build output should show: "warning: Run script build phase 'Codesign media_kit frameworks' will be run during every build"
2. App should launch without crash
3. Verify frameworks are signed: `codesign -v build/macos/.../app.app/Contents/Frameworks/Ass.framework`

## Diagnosing Build Phase Order Issues

If the codesign script exists but frameworks are still unsigned, check ordering:

```bash
# Check which frameworks are unsigned in the built app
for fw in build/macos/Build/Products/Debug/<app>.app/Contents/Frameworks/*.framework; do
  result=$(codesign -v "$fw" 2>&1)
  if echo "$result" | grep -q "not signed"; then
    echo "UNSIGNED: $(basename $fw)"
  fi
done
```

If ALL media_kit frameworks (Ass, Avcodec, Avformat, etc.) are unsigned but the codesign
script exists in the project, it's almost certainly a build phase ordering problem.

## Notes

- This affects debug builds primarily; release builds with proper code signing may not need this
- The `-` sign identity means ad-hoc signing (no certificate required)
- Affected frameworks from media_kit include: `Ass.framework`, `Avcodec.framework`,
  `Avformat.framework`, `Avutil.framework`, `Dav1d.framework`, `Freetype.framework`,
  `Fribidi.framework`, `Harfbuzz.framework`, `Mbedcrypto.framework`, `Mbedtls.framework`,
  `Mbedx509.framework`, `Mpv.framework`, `Png16.framework`, `Swresample.framework`,
  `Swscale.framework`, `Uchardet.framework`, `Xml2.framework`
- The `|| true` in the script prevents build failures if codesigning fails for any framework
- Build phase ordering can silently break after `pod deintegrate` + `pod install` cycles
- The `new_shell_script_build_phase` CocoaPods API appends to the end of build phases, which
  may be AFTER CocoaPods' own embed phase—but after pod reinstalls, the embed phase can get
  re-added at the very end, pushing it AFTER your codesign phase

## Related: Duplicate Mpv.framework Warning

If you see ObjC runtime warnings like:
```
Class Application is implemented in both .../Mpv.framework/Versions/A/Mpv (0xADDR1) and
.../Mpv.framework/Versions/A/Mpv (0xADDR2). This may cause spurious casting failures.
```

This indicates Mpv.framework is loaded twice, often caused by using a git fork of
`media_kit_video` alongside pub.dev `media_kit_libs_macos_video`. The fork's podspec
links `-framework Mpv` directly while the libs package also vendors it. This can cause
mpv config cache corruption and crashes like:
```
Assertion failed: (group_index >= 0), function m_config_cache_from_shadow, file m_config_core.c
```

A clean build usually resolves this. If persistent, consider switching to the released
version of media_kit_video.

## References

- media_kit GitHub: https://github.com/media-kit/media-kit
- Apple Code Signing Guide: https://developer.apple.com/documentation/security/code_signing_services
