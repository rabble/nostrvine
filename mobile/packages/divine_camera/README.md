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
  suppression-timer callbacks (`VolumeKeyHandler`) and the audio-session
  interruption observer plus the sample-buffer delegate's first-frame /
  writer-start breadcrumbs (`CameraController`). Those native sources only ever
  exist on the UI engine.
- **macOS** — no remote-record / volume-key path and no audio-session
  interruption observer, so there are no UI-only native camera events. Every
  diagnostic is emitted inside a method call that already re-asserts the sink.

Teardown is always ownership-guarded: a plugin instance only clears the sink
when it still points at that instance, so one engine cannot silence another's
diagnostics.
