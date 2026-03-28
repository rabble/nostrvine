Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file is not the current release path for Divine and may reference older OpenVine or web-first deployment flows. Start with docs/P1_LAUNCH_HUB.md and docs/RELEASE_CHECKLIST.md for current guidance.

# Cloudflare Stream Configuration Guide

## Overview

OpenVine has migrated from the legacy `api.openvine.co` backend to **Cloudflare Stream** for video uploads. This document covers the complete setup and configuration of the CF_STREAM_TOKEN.

## Token Configuration

### Current Token
```
CF_STREAM_TOKEN="uJDzTLyLMd8dgUfmH65jkOwD-jeFYNog3MvVQsNW"
```

### Configuration Locations

1. **AppConfig** (`lib/config/app_config.dart`)
   ```dart
   static const String cfStreamToken = String.fromEnvironment(
     'CF_STREAM_TOKEN',
     defaultValue: '',
   );
   ```

2. **CloudflareStreamService** (`lib/services/cloudflare_stream_service.dart`)
   ```dart
   _bearerToken = bearerToken ?? AppConfig.cfStreamToken;
   ```

3. **Build Scripts** (All production builds)
   - `build_native.sh`
   - `build_testflight.sh`
   - `build_web_optimized.sh`
   - `build_ios.sh`
   - `build_macos.sh`

## Development Setup

### Option 1: Development Script (Recommended)
```bash
# Use the provided development script
./run_dev.sh                    # Chrome debug
./run_dev.sh chrome release     # Chrome release
./run_dev.sh ios debug          # iOS simulator
```

### Option 2: Manual Flutter Run
```bash
flutter run -d chrome --release --dart-define=CF_STREAM_TOKEN="uJDzTLyLMd8dgUfmH65jkOwD-jeFYNog3MvVQsNW"
```

### ⚠️ Common Mistake
**DO NOT** use plain `flutter run` without `--dart-define`:
```bash
# ❌ This will fail - no token included
flutter run -d chrome --release

# ✅ This works - token included
flutter run -d chrome --release --dart-define=CF_STREAM_TOKEN="..."
```

## Production Builds

All production build scripts automatically include the token:

```bash
./build_native.sh ios release   # iOS App Store
./build_testflight.sh           # TestFlight
./build_web_optimized.sh        # Web deployment
./build_macos.sh release        # macOS App Store
```

## Service Integration

### Upload Flow
```
Flutter App
    ↓
UploadManager (selects CloudflareStream)
    ↓
CloudflareStreamService (uses CF_STREAM_TOKEN)
    ↓
CF Stream API (https://cf-stream-service-prod.protestnet.workers.dev)
    ↓
Cloudflare Stream CDN
    ↓
VideoEventPublisher (creates Nostr event with CDN URLs)
```

### Key Services

1. **CloudflareStreamService**
   - Handles direct uploads to CF Stream
   - Uses CF_STREAM_TOKEN for authentication
   - Returns CDN URLs (HLS, MP4, thumbnails)

2. **UploadManager**
   - Default target: `UploadTarget.cloudflareStream`
   - Proper error handling for failed CF Stream uploads
   - Fallback to deprecated backend if CF Stream fails

3. **VideoEventPublisher**
   - Creates NIP-32222 compliant Nostr events
   - Includes CDN URLs in imeta tags
   - Generates blurhash from thumbnails

## Deprecated Services

The following services are marked as deprecated and will be removed:

- `DirectUploadService` → Use CloudflareStreamService
- `BlossomUploadService` → Use CloudflareStreamService
- `api.openvine.co` endpoints → Direct CF Stream integration

## Troubleshooting

### Upload Not Starting
**Symptom**: No upload logs appear when publishing videos.
**Cause**: CF_STREAM_TOKEN not configured.
**Solution**: Use `./run_dev.sh` or add `--dart-define` flag.

### Upload Fails Silently
**Symptom**: Upload appears to succeed but video doesn't publish.
**Cause**: Missing success checking in UploadManager.
**Solution**: Fixed in latest version - now shows clear error messages.

### Invalid Token Error
**Symptom**: HTTP 401/403 errors from CF Stream API.
**Cause**: Invalid or expired CF_STREAM_TOKEN.
**Solution**: Verify token value and update if necessary.

## Testing Upload Integration

1. **Start Development Server**:
   ```bash
   ./run_dev.sh chrome release
   ```

2. **Test Video Upload**:
   - Navigate to camera screen
   - Record short video
   - Attempt to publish
   - Check browser console for logs

3. **Expected Logs**:
   ```
   🎬 Using Cloudflare Stream service
   📊 Upload progress: 50.0%
   ✅ Cloudflare Stream upload successful
   ✅ Event successfully published to X relay(s)
   ```

4. **Error Logs** (if misconfigured):
   ```
   ❌ Cloudflare Stream upload failed: HTTP 401: Unauthorized
   ❌ Event broadcast failed to all relays
   ```

## Security Notes

- CF_STREAM_TOKEN is compiled into the app binary via `--dart-define`
- Token is not stored in plaintext in the source code
- Production builds automatically include the token
- Development requires manual token inclusion

## Migration Benefits

Moving to Cloudflare Stream provides:
- **Faster Uploads**: Direct to CDN, no backend proxy
- **Better Reliability**: CF's global infrastructure
- **Built-in Transcoding**: Automatic HLS/MP4/DASH generation
- **Thumbnail Generation**: Automatic thumbnail creation
- **Blurhash Support**: Built-in blurhash generation
- **Simpler Architecture**: Fewer moving parts, less complexity