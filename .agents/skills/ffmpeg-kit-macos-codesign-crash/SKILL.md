---
name: ffmpeg-kit-macos-codesign-crash
description: |
  Fix Flutter macOS app crash at launch due to FFmpeg Kit library loading failure. Use when:
  (1) macOS app builds successfully but crashes immediately on launch, (2) Crash log shows
  "Library not loaded: libfontconfig.1.dylib" or similar homebrew library, (3) Error mentions
  "code signature not valid for use in process" with "different Team IDs", (4) Using
  ffmpeg_kit_flutter_new (Full GPL variant). The Full GPL variant has external dependencies
  on homebrew libraries that fail macOS code signing. Switch to ffmpeg_kit_flutter_new_min.
author: Claude Code
version: 1.0.0
date: 2025-01-25
---

# FFmpeg Kit macOS Code Signing Crash

## Problem

Flutter macOS app builds successfully but crashes immediately at launch with a library
loading failure. The crash is caused by FFmpeg Kit's Full GPL variant having runtime
dependencies on homebrew-installed libraries (like fontconfig) that fail macOS code
signature validation.

## Context / Trigger Conditions

- **Platform**: macOS only (iOS and Android are not affected)
- **Package**: Using `ffmpeg_kit_flutter_new` (Full GPL variant)
- **Symptom**: App builds successfully but crashes on launch
- **Crash log shows**:
  ```
  Library not loaded: /opt/homebrew/*/libfontconfig.1.dylib
  Referenced from: .../libswresample.framework/...
  Reason: code signature in (.../libfontconfig.1.dylib) not valid for use in process:
  mapping process and mapped file (non-platform) have different Team IDs
  ```

## Root Cause

The `ffmpeg_kit_flutter_new` package is the "Full GPL" variant which includes many
FFmpeg libraries for advanced features like text rendering (drawtext filter). These
libraries have external dependencies on system fonts via `libfontconfig`.

On macOS, when the app tries to load `libswresample.framework`, it attempts to also
load `libfontconfig.1.dylib` from homebrew. macOS code signing validation rejects
this because the homebrew library has a different Team ID than your app.

## Solution

Switch from `ffmpeg_kit_flutter_new` (Full GPL) to `ffmpeg_kit_flutter_new_min` (Minimal).

**Step 1: Update pubspec.yaml**
```yaml
# Before
ffmpeg_kit_flutter_new: ^3.2.0

# After
ffmpeg_kit_flutter_new_min: ^3.1.0
```

**Step 2: Update imports in all Dart files**
```dart
// Before
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

// After
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
```

**Step 3: Clean and rebuild**
```bash
flutter clean
rm -f macos/Podfile.lock
flutter pub get
flutter run -d macos
```

## What Features Are Preserved

The minimal variant includes everything needed for typical video apps:
- h264/libx264 video encoding
- AAC audio encoding
- VideoToolbox hardware acceleration (Apple platforms)
- Standard filters: overlay, crop, scale, concat, amix
- FFprobe for media information

## What Features Are Removed

The minimal variant does NOT include:
- `drawtext` filter (font rendering) - use PNG overlays instead
- Advanced codec libraries with external dependencies
- Features requiring fontconfig, freetype, etc.

## Verification

After the fix:
1. `flutter run -d macos` should launch the app without crashing
2. Video encoding/decoding operations should work normally
3. iOS builds continue to work (they weren't affected)

## Example

**Find files needing import updates:**
```bash
grep -r "ffmpeg_kit_flutter_new" lib/ --include="*.dart" -l
```

**Update all imports (sed example):**
```bash
find lib -name "*.dart" -exec sed -i '' \
  's/ffmpeg_kit_flutter_new/ffmpeg_kit_flutter_new_min/g' {} \;
```

## Notes

- This issue only affects macOS; iOS and Android don't have the same code signing restrictions
- The error message is misleading - it mentions fontconfig but the fix is changing FFmpeg Kit variants
- If you actually need `drawtext` filter on macOS, you'd need to bundle fontconfig with proper signing (complex)
- Alternative: Use the official `ffmpeg_kit_flutter` from arthenica if you need more control over variants

## References

- [ffmpeg_kit_flutter_new on pub.dev](https://pub.dev/packages/ffmpeg_kit_flutter_new)
- [ffmpeg_kit_flutter_new_min on pub.dev](https://pub.dev/packages/ffmpeg_kit_flutter_new_min)
- [Apple Code Signing Documentation](https://developer.apple.com/documentation/security/code_signing_services)
