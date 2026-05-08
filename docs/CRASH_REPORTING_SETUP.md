# iOS TestFlight Crash Reporting Setup

## Problem Solved
The app was crashing on iOS TestFlight but working fine in the Xcode simulator. Root causes identified:
1. **SQLite database initialization failures** on iOS due to sandbox restrictions
2. **No crash reporting** - flying blind without visibility into production crashes
3. **Poor error handling** during service initialization

## Solution Implemented

### 1. Firebase Crashlytics Integration
Added comprehensive crash reporting to capture all production crashes with:
- Stack traces
- Device information
- Custom logging of initialization steps
- Startup performance metrics

### 2. Robust Error Handling
- Embedded relay gracefully handles SQLite failures on iOS
- NostrService continues with limited functionality if initialization fails
- All service failures are logged to Crashlytics

### 3. Diagnostic Logging
- Each initialization step is logged
- Startup time is tracked and reported
- Failures include context about what was being attempted

## Setup Instructions

### 1. Create Firebase Project
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Create new project
firebase projects:create openvine-production

# Configure Flutter app
flutterfire configure
```

### 2. Enable Crashlytics
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to Crashlytics
4. Follow setup instructions

### 3. Replace Placeholder Config
The current config is a placeholder. Replace these files with real Firebase config:
- `ios/Runner/GoogleService-Info.plist`
- `lib/firebase_options.dart`

### 4. Build for TestFlight
```bash
./build_ios.sh release
```

### 5. Monitor Crashes
View crash reports at:
https://console.firebase.google.com/project/[YOUR-PROJECT]/crashlytics

## Debugging TestFlight Crashes

### What Gets Logged
- App startup time
- Each service initialization (success/failure)
- Embedded relay initialization status
- SQLite database creation attempts
- Network connection status
- Memory warnings

### Custom Keys Set
- `environment`: testflight/production
- `build_mode`: debug/release
- `startup_time_ms`: Total startup duration

### Reading Crash Reports
1. **Crash-free rate**: Shows percentage of users without crashes
2. **Issues**: Groups similar crashes together
3. **Stack trace**: Shows exact line where crash occurred
4. **Breadcrumbs**: Shows initialization steps before crash
5. **Device info**: iOS version, device model, available memory

## Common iOS Issues

### SQLite Permission Errors
- **Symptom**: Database initialization fails
- **Cause**: iOS sandbox restrictions
- **Solution**: App now uses in-memory fallback

### Memory Pressure
- **Symptom**: Crash after loading many videos
- **Cause**: iOS aggressive memory management
- **Solution**: Implement proper cleanup in VideoManager

### Network Restrictions
- **Symptom**: Can't connect to relays
- **Cause**: iOS App Transport Security
- **Solution**: Already configured in Info.plist

## Testing Checklist

Before TestFlight deployment:
- [ ] Run `flutter analyze` - fix all errors
- [ ] Test on physical iOS device via Xcode
- [ ] Verify Firebase project is configured
- [ ] Check bundle ID matches Firebase config
- [ ] Increment build number in pubspec.yaml
- [ ] Archive and upload via Xcode

## Emergency Rollback

If crashes persist after deployment:
1. **Immediate**: Stop TestFlight testing
2. **Analyze**: Check Firebase Crashlytics for patterns
3. **Debug**: Use logged initialization steps to identify failure point
4. **Fix**: Apply targeted fix based on crash data
5. **Test**: Deploy to internal testers first

## Support

For crash analysis help:
1. Share crash report from Firebase
2. Include device model and iOS version
3. Note any specific user actions before crash
4. Check initialization logs in Crashlytics
