# background_uploader

OS-backed background file uploads for Android and iOS. Once a file is enqueued,
the operating system owns the transfer and keeps it running while the app is
backgrounded or suspended — unlike an in-process HTTP client, whose sockets the
OS tears down on suspension.

This is a **data-layer client**: it speaks plain HTTP (method + headers + a file
body) and knows nothing about Blossom, Nostr, or any domain concern. The caller
builds the request — including any signed authorization header — and maps
`BackgroundUploadEvent`s onto its own state model.

## Usage

```dart
import 'package:background_uploader/background_uploader.dart';

final uploader = BackgroundUploader.instance;

uploader.events
    .where((e) => e.taskId == 'video-123')
    .listen((e) {
  switch (e.status) {
    case BackgroundUploadStatus.running:   // e.progress in [0, 1]
    case BackgroundUploadStatus.completed: // e.httpStatusCode / e.responseBody
    case BackgroundUploadStatus.failed:    // e.httpStatusCode or e.error
    case BackgroundUploadStatus.cancelled:
  }
});

await uploader.enqueue(
  BackgroundUploadRequest(
    taskId: 'video-123',
    url: Uri.parse('https://media.divine.video/upload'),
    filePath: '/path/to/divine_123.mp4',
    method: 'PUT',
    headers: {'Authorization': signedBlossomAuthHeader},
  ),
);
```

On startup, reconcile uploads that may have completed while the app was not
running:

```dart
final stillRunning = await uploader.activeTaskIds();
```

## Platform notes

- **Apple (iOS + macOS)** — a shared Darwin background `URLSession`
  (`uploadTask(with:fromFile:)`). On iOS the app-delegate forwarding hook
  (`handleEventsForBackgroundURLSession`) lets the OS relaunch the app to finish
  a transfer; that relaunch path is iOS-only (`#if os(iOS)`), since macOS apps
  are not suspended the same way. Requires no extra entitlements.
- **Android** — a foreground service streams the upload. The plugin manifest
  contributes `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`,
  `POST_NOTIFICATIONS`, and `INTERNET`. On Android 13+ the ongoing notification
  only shows if the app holds the (runtime) notification permission; the upload
  runs regardless.

The Apple side ships **both** a `Package.swift` (Swift Package Manager) and a
`.podspec` (CocoaPods) over the same shared `darwin/` sources, so it builds
under SPM when the app has it enabled and falls back to CocoaPods otherwise.

## Design notes / limitations

- **Single request, not chunked-resumable.** An OS background transfer is one
  request the OS owns; it cannot drive a multi-step resumable chunk protocol
  whose every step needs a freshly-signed header while the app is suspended.
  Pair this with a single-PUT endpoint (e.g. Blossom BUD-01 `PUT /upload`).
- **Terminal events are buffered until claimed.** When the OS reports a
  transfer's terminal event before any `events` listener has subscribed — e.g.
  it finished while the app was dead and the engine has only just attached — the
  event is retained (bounded, keyed by `taskId`) and recoverable via
  `takeBufferedTerminalEvent(taskId)` during startup reconciliation, rather than
  being silently dropped by the broadcast stream. If the OS completes a transfer
  while *no* Flutter engine is attached at all, reconcile with `activeTaskIds()`
  (and, on the caller side, by checking the resource the upload would have
  created). The `taskId` is the stable correlation handle.
- **Auth-header expiry.** A signed header is built at enqueue time; if the OS
  defers the transfer for a long time the header can expire. Keep the header's
  lifetime comfortably longer than expected queueing, or re-enqueue on failure.

The Dart surface is unit-tested. The native implementations still need on-device
build and behavioural verification (`pod install` / Gradle) before wiring into
the app.
