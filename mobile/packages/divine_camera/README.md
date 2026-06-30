# divine_camera

Status: Current
Validated against: `pubspec.yaml` on 2026-03-19.

Purpose: Flutter camera plugin used by Divine for recording video on supported platforms.

Used by: recording and capture flows in the mobile app.

Test locally:

```bash
cd mobile/packages/divine_camera
flutter test
```

Android native unit tests (run in CI, see `.github/workflows/divine_camera.yaml`):

```bash
cd mobile/android
gradle :divine_camera:testDebugUnitTest
```

## Native diagnostics sink ownership

Curated native diagnostics are forwarded to Dart's `UnifiedLogger` through a
process-wide sink (`DivineCameraLog.sink`). Because the app also runs a
background Flutter engine (Firebase Messaging) that can register this plugin,
that singleton must always be owned by the **UI engine**, or native-only events
(e.g. a volume-key callback, an audio-session interruption) could be routed to
the wrong isolate or dropped.

Ownership is bound to the UI lifecycle as closely as each platform allows:

- **Android** — ownership is tied to the `ActivityAware` lifecycle. The sink is
  claimed in `onAttachedToActivity` / `onReattachedToActivityForConfigChanges`
  and released (ownership-guarded) in `onDetachedFromActivity`. A background
  engine attaches to the engine but never to an Activity, so it can never own
  the sink — not even transiently. `onMethodCall` re-claims as defense-in-depth.
- **iOS** — `FlutterPlugin` has no Activity-attachment lifecycle, so the sink is
  re-asserted at every UI-bound entry point: each method call, plus the
  native-only callbacks that fire without one — the volume/Bluetooth and
  suppression-timer callbacks (`VolumeKeyHandler`) and, in `CameraController`,
  the audio-session interruption observer, the sample-buffer delegate's
  first-frame / writer-start breadcrumbs, the frame watchdog and init-timeout
  timers, and the max-duration auto-stop's recording-finalization breadcrumbs
  (including the #4779 "WITHOUT audio track" warning). Those native sources only
  ever exist on the UI engine.
- **macOS** — no native-only reclaim is needed, but not because every diagnostic
  is method-driven (the init-timeout and max-duration auto-stop timers do emit
  outside a method call). The reason is that desktop has no background
  `FlutterEngine` (no FCM isolate) that could register the plugin and steal the
  sink, so a single engine owns it from `register()` and re-asserting on each
  method call is enough.

Teardown is always ownership-guarded: a plugin instance only clears the sink
when it still points at that instance, so one engine cannot silence another's
diagnostics.
