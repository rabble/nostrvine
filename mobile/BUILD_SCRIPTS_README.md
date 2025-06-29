# Build Scripts for iOS and macOS

This directory contains build scripts that ensure CocoaPods dependencies are properly synced before building, preventing the common "sandbox is not in sync with Podfile.lock" errors.

## Automatic Xcode Integration

The iOS and macOS Xcode projects have been modified to automatically run `pod install` when needed during builds. The default CocoaPods check scripts have been replaced with enhanced versions that:

1. Check if pods need to be installed
2. Automatically run `pod install` if needed
3. Continue with the build process

**No manual configuration needed!** Just build in Xcode and it will handle CocoaPods automatically.

## Scripts Overview

### Command Line Building

- **`build_native.sh`** - Universal build script for both iOS and macOS
- **`build_ios.sh`** - iOS-specific build script  
- **`build_macos.sh`** - macOS-specific build script

### Xcode Integration Scripts

- **`ios/Scripts/check_pods.sh`** - Auto-installed iOS CocoaPods check (runs automatically)
- **`macos/Scripts/check_pods.sh`** - Auto-installed macOS CocoaPods check (runs automatically)
- **`pre_build_ios.sh`** - Optional pre-build script for custom Xcode iOS builds
- **`pre_build_macos.sh`** - Optional pre-build script for custom Xcode macOS builds

## Usage

### Command Line Builds

```bash
# Interactive build (asks for platform)
./build_native.sh

# Build iOS debug
./build_native.sh ios debug

# Build iOS release  
./build_native.sh ios release

# Build macOS debug
./build_native.sh macos debug

# Build macOS release
./build_native.sh macos release

# Build both platforms
./build_native.sh both debug
```

Or use platform-specific scripts:

```bash
# iOS builds
./build_ios.sh debug
./build_ios.sh release

# macOS builds  
./build_macos.sh debug
./build_macos.sh release
```

### Xcode Integration (Already Configured!)

**The Xcode projects have been pre-configured to automatically handle CocoaPods!**

When you build in Xcode, the projects now:
1. Automatically check if `pod install` is needed
2. Run `pod install` if dependencies are out of sync
3. Continue with the normal build process

No manual setup required - just open the `.xcworkspace` file and build!

#### Optional: Adding Custom Pre-Build Actions

If you need additional pre-build steps, you can still add the pre-build scripts:

1. Open `ios/Runner.xcworkspace` or `macos/Runner.xcworkspace` in Xcode
2. Select the "Runner" scheme
3. Click "Edit Scheme..."
4. Go to "Build" → "Pre-actions"
5. Click "+" and select "New Run Script Action"
6. Set "Provide build settings from" to "Runner"
7. Add the appropriate script path

## What These Scripts Do

1. **Run `flutter pub get`** to ensure Flutter dependencies are current
2. **Check CocoaPods status** in the respective platform directory
3. **Run `pod install`** if needed to sync dependencies
4. **Build the Flutter app** for the specified platform and configuration

## Troubleshooting

If you still get CocoaPods errors:

1. **Clean build folders:**
   ```bash
   flutter clean
   rm -rf ios/Pods ios/Podfile.lock
   rm -rf macos/Pods macos/Podfile.lock
   ```

2. **Update CocoaPods:**
   ```bash
   sudo gem update cocoapods
   ```

3. **Update pod repo:**
   ```bash
   pod repo update
   ```

4. **Then run the build scripts again**

## Notes

- These scripts automatically handle the timing of `pod install` relative to Flutter builds
- They check if CocoaPods installation is actually needed before running it
- Safe to run multiple times - they won't reinstall pods unnecessarily
- Pre-build scripts can be added to Xcode schemes to fix builds from within Xcode