# Linux Desktop Support (Experimental)

divine-mobile can be built and run on Linux desktop for browsing and watching videos. Camera recording is **not available** on Linux.

## Status

| Feature | Status |
|---------|--------|
| Browse / discover videos | Works |
| Watch videos | Works (requires GStreamer) |
| Login / auth (bunker, nsec) | Works |
| Notifications | Works (requires libnotify) |
| Video recording | Not available |
| Gallery save | Skipped on desktop |
| Firebase / Crashlytics | Gracefully disabled |

## System Dependencies

Install these before building:

```bash
# Ubuntu / Debian
sudo apt install libgtk-3-dev libsecret-1-dev libjsoncpp-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev gstreamer1.0-plugins-good libnotify-dev

# Fedora
sudo dnf install gtk3-devel libsecret-devel jsoncpp-devel gstreamer1-devel gstreamer1-plugins-base-devel gstreamer1-plugins-good libnotify-devel
```

| Package | Used by |
|---------|---------|
| `libgtk-3-dev` | Flutter Linux embedding |
| `libsecret-1-dev` | `flutter_secure_storage` (keychain) |
| `libjsoncpp-dev` | `flutter_secure_storage` |
| `gstreamer1.0-*` | `video_player` (video playback) |
| `libnotify-dev` | `flutter_local_notifications` |

## Building

```bash
cd mobile
flutter build linux
```

> **Note:** You must build on a Linux host. Cross-compilation from macOS is not supported.

## How Camera Degradation Works

`CameraLinuxService` is a stub that:
- Reports `isInitialized: false` and `canRecord: false`
- Provides an `initializationError` message shown in the camera placeholder UI
- All recording methods are safe no-ops

The existing `VideoRecorderCameraPlaceholder` widget renders the error message automatically.

## Known Limitations

- **No Firebase** — `firebase_options.dart` throws `UnsupportedError` for Linux, but `CrashReportingService.initialize()` catches it. Analytics, Crashlytics, and remote config are unavailable.
- **No camera permissions API** — `permission_handler` doesn't support Linux. The permission check is bypassed on desktop (same as macOS).
- **Audio session** — `audio_session` has no Linux backend. Calls are wrapped in try/catch and degrade silently.
- **Window manager** — `window_manager` supports Linux. Window sizing and positioning work normally.
