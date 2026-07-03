# Crash Reporting Setup (Firebase Crashlytics)

Divine uses **Firebase Crashlytics** for production crash and non-fatal error
reporting. The active Firebase project is **`openvine-co`** (bundle id
`co.openvine.app`).

> This file is the operational setup / runbook. For the *error-handling
> contract* — what gets forwarded to Crashlytics vs logged locally — see
> [`mobile/docs/ERROR_HANDLING.md`](../mobile/docs/ERROR_HANDLING.md) and
> `.claude/rules/error_handling.md`.

## Supported platforms

| Platform | Firebase config | Symbol upload | Status |
|----------|-----------------|---------------|--------|
| iOS | `openvine-co` — `firebase_options.dart`, `ios/Runner/GoogleService-Info.plist` | ✅ dSYMs via Codemagic | Production |
| macOS | `openvine-co` — `macos/Runner/GoogleService-Info.plist` | — | Production (reuses the iOS appId — see note below) |
| Android | `openvine-co` — `android/app/google-services.json` | ⚠️ R8 mapping upload wired via Gradle; native-symbol upload configured but unverified | `firebase_options.dart` Android options are still being reconciled in #3343 |
| Web / Windows / Linux | none | — | Not supported; init is gated off |

`isFirebaseSupported` (`mobile/lib/utils/platform_support.dart`) is a
coarse-grained platform helper for Firebase-backed services. Crash reporting is
currently initialized only when startup passes both `isFirebaseSupported` and
`!kIsWeb`, so web remains intentionally gated off in app startup.

> **macOS note:** `firebase_options.dart` currently gives macOS the same appId
> as iOS (`1:972941478875:ios:…`). Confirm this is intentional during the
> #3343 config reconciliation; a distinct macOS app may warrant its own appId.

> **Android note:** `google-services.json` already points at `openvine-co`, but
> `DefaultFirebaseOptions.android` is still a placeholder, so
> `Firebase.initializeApp` does not yet initialise Android against the real
> project. The Crashlytics Gradle plugin is already applied and release builds
> now enable R8, so an obfuscation mapping file is produced and uploaded;
> native-symbol upload is configured but not yet verified end-to-end.
> Reconciling the Android options is tracked in #3343.

## Configuration files

| File | Role |
|------|------|
| `mobile/lib/firebase_options.dart` | `DefaultFirebaseOptions.currentPlatform`, passed to `Firebase.initializeApp` in `CrashReportingService.initialize()` |
| `mobile/firebase.json` | FlutterFire platform manifest (`uploadDebugSymbols: true` for iOS/macOS) |
| `mobile/ios/Runner/GoogleService-Info.plist` | iOS native config |
| `mobile/macos/Runner/GoogleService-Info.plist` | macOS native config |
| `mobile/android/app/google-services.json` | Android native config (`openvine-co`) |

## Regenerating config

Config is managed by FlutterFire and requires access to the `openvine-co`
Firebase console:

```bash
# from mobile/
dart pub global activate flutterfire_cli
flutterfire configure --project=openvine-co
```

This rewrites `firebase_options.dart`, `firebase.json`, and the native config
files for the selected platforms. Avoid hand-editing generated values except
as a documented stopgap.

## iOS/macOS dSYM upload (Codemagic)

Release builds upload Crashlytics debug symbols automatically. See
`codemagic.yaml` → the **Upload dSYMs to Firebase Crashlytics** step
(`&upload_dsyms_to_crashlytics`), which:

1. Locates `build/ios/archive/Runner.xcarchive/dSYMs` (fails the build if absent).
2. Finds the Crashlytics `upload-symbols` tool from the SPM / Pods build under
   `~/Library/Developer/Xcode/DerivedData` (or a `FirebaseCrashlytics` path).
3. Runs:
   ```bash
   upload-symbols -gsp ios/Runner/GoogleService-Info.plist -p ios "$DSYM_DIR"
   ```

Without this, iOS crash stacks arrive in Crashlytics unsymbolicated.

> **Android note:** Crashlytics upload wiring is present in Gradle and release
> builds generate an R8 mapping file for symbolication. Android Firebase options
> still need reconciliation under #3343.

## Custom keys on every report

Set by `CrashReportingService.initialize()` and follow-up helpers:

- `environment` — `ENVIRONMENT` build define (default `production`)
- `build_mode` — `debug` / `release`
- `cache_hit_rate`, `cache_total_lookups` — set by
  `updateCacheMetricsKeys()` when the app backgrounds

Bloc/Cubit errors are additionally annotated by `DivineBlocObserver`, which
forwards to Crashlytics **only** when the error implements `ReportableError`
(see `ERROR_HANDLING.md` for the decision matrix and the enriched per-error
context keys).

## Verifying a crash lands

1. Build a release (or profile) build on a supported platform — collection is
   **disabled in debug builds** (`setCrashlyticsCollectionEnabled(!kDebugMode)`).
2. Trigger a test non-fatal — e.g. `FirebaseCrashlytics.instance.recordError(...)`
   or a `Reportable` Bloc error.
3. Confirm it appears at
   <https://console.firebase.google.com/project/openvine-co/crashlytics>.

## Debugging crashes

Crashlytics groups by issue and shows the stack, breadcrumbs (initialisation
steps logged via `logInitializationStep`), custom keys, and device info.
Historical iOS-specific failure modes (SQLite sandbox restrictions, memory
pressure, App Transport Security) and their fixes are in this file's git
history.
