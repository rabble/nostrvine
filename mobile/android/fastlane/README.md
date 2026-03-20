# Android Fastlane Notes

Status: Current
Validated against: `mobile/deploy_android.sh` on 2026-03-19.

This directory supports the optional Play Console upload helper used by `mobile/deploy_android.sh`.

## Prerequisites

- Fastlane installed locally
- `android/play-store-service-account.json` present
- a built release AAB or a working local release build environment

## Common Usage

From `mobile/`:

```bash
./deploy_android.sh internal
./deploy_android.sh closed
./deploy_android.sh production
```

If the helper is unavailable or misconfigured, fall back to manual Play Console upload with the AAB produced by `./build_android.sh release`.
