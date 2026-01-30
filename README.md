# diVine

<img src="https://devine.video/og.png" alt="diVine logo and screenshot"/>

### diVine is a decentralized, short-form video sharing mobile application built on the Nostr protocol, inspired by the simplicity and creativity of Vine.

**Try it:** https://divine.video/discovery

_Feed navigation • Hashtag filtering • Video interactions • Social sharing • Real-time content discovery_

<br>

## Features

### Core Features
- **Decentralized**: Built on Nostr protocol for censorship resistance
- **Vine-Style Recording**: Short-form video content (6.3 seconds like original Vine)
- **Cross-Platform**: Flutter app for iOS, Android, and macOS
- **Real-Time Social**: Follow, like, comment, repost, and share videos
- **Open Source**: Fully open source and transparent
- **Dark Mode Only**: Sleek dark aesthetic optimized for video viewing

### Video Features
- **Multi-Platform Camera**: Supports iOS, Android, macOS recording
- **Segmented Recording**: Press-and-hold recording with pause/resume capability
- **Thumbnail Generation**: Automatic video thumbnail creation
- **Progressive Loading**: Smart video preloading and caching

### Social Features
- **Activity Feed**: Real-time notifications for likes, follows, and interactions
- **Video Sharing**: Comprehensive sharing menu with external app support
- **Content Curation**: Create and manage curated video lists (NIP-51)
- **Direct Messaging**: Share videos privately with other users

## Build It Yourself

Want to build diVine and install it on your phone? This guide will walk you through everything, even if you've never built an app before.

### Step 1: Install Flutter

Flutter is the framework diVine is built with. You need to install it first.

**macOS:**
```bash
# Install Homebrew if you don't have it
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Flutter
brew install flutter

# Verify installation
flutter doctor
```

**Windows:**
1. Download Flutter from https://flutter.dev/docs/get-started/install/windows
2. Extract the zip to `C:\flutter`
3. Add `C:\flutter\bin` to your PATH environment variable
4. Open a new terminal and run `flutter doctor`

**Linux:**
```bash
# Using snap (easiest)
sudo snap install flutter --classic

# Verify installation
flutter doctor
```

### Step 2: Platform-Specific Setup

#### For iOS (requires a Mac)

1. **Install Xcode** from the Mac App Store
2. **Accept Xcode license:**
   ```bash
   sudo xcodebuild -license accept
   ```
3. **Install CocoaPods:**
   ```bash
   sudo gem install cocoapods
   ```
4. **Set up Xcode command-line tools:**
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
   ```

#### For Android

1. **Install Android Studio** from https://developer.android.com/studio
2. **Open Android Studio** and complete the setup wizard
3. **Install Android SDK:** Go to Settings → SDK Manager → Install the latest Android SDK
4. **Enable USB debugging on your phone:**
   - Go to Settings → About Phone
   - Tap "Build Number" 7 times to enable Developer Options
   - Go to Settings → Developer Options → Enable USB Debugging

### Step 3: Clone and Build diVine

```bash
# Clone the repository
git clone https://github.com/divinevideo/divine-mobile.git
cd divine-mobile

# Navigate to the mobile app
cd mobile

# Install dependencies
flutter pub get

# Check everything is set up correctly
flutter doctor
```

### Step 4: Install on Your Phone

#### Option A: iOS (iPhone/iPad)

**Using a physical device (recommended):**

1. Connect your iPhone to your Mac with a USB cable
2. Trust the computer on your iPhone when prompted
3. Open `mobile/ios/Runner.xcworkspace` in Xcode
4. Select your Apple ID in Xcode → Preferences → Accounts
5. In Xcode, select the "Runner" project, go to "Signing & Capabilities", and:
   - Select your "Team" (your Apple ID)
   - Change the "Bundle Identifier" to something unique like `com.yourname.divine`
6. Build and run:
   ```bash
   flutter run -d <your-device-id>
   ```
   Or press the Play button in Xcode

**First time on device:** You need to trust the developer certificate on your iPhone:
- Go to Settings → General → VPN & Device Management
- Tap your developer certificate and tap "Trust"

**Using iOS Simulator:**
```bash
# List available simulators
flutter devices

# Run on a simulator
flutter run -d "iPhone 15 Pro"
```

#### Option B: Android

**Using a physical device (recommended):**

1. Connect your Android phone to your computer with a USB cable
2. Make sure USB debugging is enabled (see Step 2)
3. Accept the "Allow USB debugging" prompt on your phone
4. Build and install:
   ```bash
   # List connected devices
   flutter devices

   # Run on your device (replace with your device ID)
   flutter run -d <your-device-id>
   ```

**Build an APK to share:**
```bash
# Build a release APK
flutter build apk --release

# The APK will be at: build/app/outputs/flutter-apk/app-release.apk
# Transfer this file to any Android phone and open it to install
```

**Using Android Emulator:**
```bash
# Open Android Studio → Tools → Device Manager → Create Device
# Start the emulator, then:
flutter run
```

#### Option C: macOS Desktop

```bash
flutter run -d macos
```

### Troubleshooting

**"flutter: command not found"**
- Make sure Flutter is in your PATH. Run `export PATH="$PATH:/path/to/flutter/bin"` or restart your terminal.

**"No connected devices"**
- For iOS: Make sure your device is unlocked and you've trusted the computer
- For Android: Enable USB debugging and accept the prompt on your phone
- Run `flutter devices` to see what's connected

**iOS build fails with signing error**
- Open the project in Xcode (`ios/Runner.xcworkspace`)
- Go to Runner → Signing & Capabilities
- Select your Team and change the Bundle Identifier to something unique

**Android build fails with "license not accepted"**
```bash
flutter doctor --android-licenses
# Accept all licenses by typing 'y'
```

**Dependencies fail to install**
```bash
cd mobile
flutter clean
flutter pub get
```

**CocoaPods errors (iOS/macOS)**
```bash
cd ios  # or cd macos
pod deintegrate
pod install
cd ..
flutter run
```

## Development

For detailed development instructions, testing guidelines, and code standards, see **[CONTRIBUTING.md](CONTRIBUTING.md)**.

### Quick Commands

```bash
cd mobile
flutter run                    # Run the app
flutter test                   # Run tests
flutter analyze                # Check for issues
dart format lib/ test/         # Format code
```

## Architecture

- **Framework**: Flutter with Dart
- **Protocol**: Nostr for decentralized social networking
- **Platforms**: iOS, Android, macOS
- **State Management**: Riverpod with reactive data flow
- **Storage**: Hive for local data persistence

**Nostr Integration:**
- Event Types: Kind 34236 (videos), Kind 6 (reposts), Kind 0 (profiles)
- NIPs Supported: NIP-01, NIP-02, NIP-18, NIP-25, NIP-71, NIP-94, NIP-98
- Multi-relay support for redundancy and performance

## Bug Reporting

diVine includes an encrypted bug reporting system. Navigate to **Settings → Support → Report a Bug** to send diagnostic information directly to developers via NIP-17 encrypted messages.

All sensitive data (private keys, tokens, credentials) is automatically removed before sending.

## Contributing

We welcome contributions! Please see **[CONTRIBUTING.md](CONTRIBUTING.md)** for:
- Development environment setup
- Code standards and testing requirements
- Pull request process

## License

Mozilla Public License 2.0

This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.
