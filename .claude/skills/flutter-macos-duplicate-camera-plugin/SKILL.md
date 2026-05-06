---
name: flutter-macos-duplicate-camera-plugin
description: |
  Fix Flutter macOS build failure caused by duplicate camera plugins. Use when: (1) macOS build
  fails with "Ambiguous use of 'CameraMacosPlugin.register(with:)'" error, (2) Both camera_macos
  and camera_macos_plus are in pubspec.yaml, (3) Build worked before adding a new camera package.
  The plugins define the same class name causing Swift registration conflicts.
author: Claude Code
version: 1.0.0
date: 2025-01-28
---

# Flutter macOS Duplicate Camera Plugin Fix

## Problem
Flutter macOS builds fail when both `camera_macos` and `camera_macos_plus` packages are present
in pubspec.yaml. Both packages define the same `CameraMacosPlugin` class, causing Swift
registration ambiguity.

## Context / Trigger Conditions

**Error message:**
```
Ambiguous use of 'CameraMacosPlugin.register(with:)'
```

**Symptoms:**
- macOS build fails during Swift compilation
- iOS build may still succeed (different plugin implementations)
- Error occurs in the generated plugin registration code
- May be accompanied by Xcode build system crashes or "stat cache file not found" errors

**Common scenarios:**
- Project has `camera_macos` for basic camera support
- Added `camera_macos_plus` for additional features
- Transitive dependency pulled in duplicate plugin
- Copied pubspec.yaml from another project with different camera requirements

## Solution

1. **Identify the duplicates** - Check pubspec.yaml for both packages:
   ```yaml
   # Look for these:
   camera_macos: ^0.0.9
   camera_macos_plus: ^0.0.3
   ```

2. **Choose one to keep** - `camera_macos_plus` is generally preferred as it's a
   more feature-complete fork of `camera_macos`

3. **Remove the duplicate** from pubspec.yaml:
   ```yaml
   # Keep only one:
   camera_macos_plus: ^0.0.3  # macOS camera support
   ```

4. **Clean thoroughly** - The Xcode build system may be in a corrupted state:
   ```bash
   flutter clean
   rm -rf build/
   rm -rf macos/Pods/
   rm -f macos/Podfile.lock
   rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-*
   flutter pub get
   ```

5. **Rebuild:**
   ```bash
   flutter build macos
   ```

## Verification

After the fix:
- `flutter build macos` completes successfully
- No "Ambiguous use" errors in build output
- The macOS app launches and camera functionality works

## Example

**Before (broken):**
```yaml
dependencies:
  camera_macos_plus: ^0.0.3
  divine_camera:
    path: packages/divine_camera
  camera_macos: ^0.0.9  # DUPLICATE - causes conflict
```

**After (fixed):**
```yaml
dependencies:
  camera_macos_plus: ^0.0.3  # macOS camera support (replaces camera_macos)
  divine_camera:
    path: packages/divine_camera
  # camera_macos removed
```

## Notes

- `camera_macos_plus` is a community fork with additional features
- If you specifically need `camera_macos` instead, remove `camera_macos_plus`
- Check transitive dependencies with `flutter pub deps` if duplicates reappear
- The Xcode build system can get into corrupted states after this error;
  thorough cleaning (including DerivedData) may be required
- This is specific to macOS - iOS uses different camera plugin implementations

## References

- [camera_macos_plus on pub.dev](https://pub.dev/packages/camera_macos_plus)
- [camera_macos on pub.dev](https://pub.dev/packages/camera_macos)
- [Flutter macOS plugin registration](https://docs.flutter.dev/packages-and-plugins/developing-packages#macos)
