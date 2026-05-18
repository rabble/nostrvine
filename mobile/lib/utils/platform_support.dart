// ABOUTME: Web-safe platform support checks that avoid `dart:io`.
// ABOUTME: Use these helpers from code that is compiled for web as well.

import 'package:flutter/foundation.dart';

/// Whether Firebase (and Firebase-dependent services like Crashlytics and
/// Firebase Messaging) is supported on the current platform.
///
/// Firebase supports Android, iOS, macOS, and web. It does NOT support
/// Linux or Windows — `DefaultFirebaseOptions.currentPlatform` throws
/// `UnsupportedError` on those platforms.
///
/// Uses [defaultTargetPlatform] instead of `dart:io`'s `Platform` so the
/// check is safe on web builds.
bool get isFirebaseSupported =>
    kIsWeb ||
    (defaultTargetPlatform != TargetPlatform.linux &&
        defaultTargetPlatform != TargetPlatform.windows);

/// Whether the `divine_video_player` plugin has a native implementation on
/// the current platform.
///
/// The plugin only ships native code for Android, iOS, and macOS, so callers
/// must skip native-only startup work on web, Linux, and Windows.
bool get hasNativeVideoPlayer =>
    !kIsWeb &&
    defaultTargetPlatform != TargetPlatform.linux &&
    defaultTargetPlatform != TargetPlatform.windows;
