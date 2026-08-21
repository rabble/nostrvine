// ABOUTME: Riverpod provider for the app documents directory path.
// ABOUTME: Resolved once at startup and overridden in DeviceScope so every
// ABOUTME: account container shares the same synchronous value.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Absolute path of the application documents directory, resolved once during
/// startup (see `main.dart`) and injected into every account container via
/// [DeviceScope.overrides].
///
/// iOS rewrites the app container path on every app update, so a persisted
/// absolute path has to be rebased against the *current* documents directory
/// on read. `getDocumentsPath()` is a `Future`, which synchronous readers such
/// as `SavedSoundsService.loadSavedSounds` cannot await, so the value is
/// resolved once at bootstrap and carried device-wide instead.
///
/// Throws by default; `main.dart` overrides it before `runApp`. Reading it
/// without that override is a wiring error, not a runtime condition to handle.
/// Empty string is a legitimate value on web, where there is no documents
/// directory (see `getDocumentsPath`).
final documentsPathProvider = Provider<String>(
  (_) => throw StateError('documentsPathProvider must be overridden'),
);
