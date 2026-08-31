// ABOUTME: Identifies platforms where Divine can close its own process.
// ABOUTME: Keeps unsupported startup screens from offering dead close actions.

import 'package:flutter/foundation.dart';

/// Whether the current platform lets Divine end its own process.
///
/// Android, Linux, and macOS terminate the application. iOS cannot close the
/// root application view, Windows and Fuchsia do not implement the method, and
/// web only pops browser history.
bool get platformCanCloseApp =>
    !kIsWeb &&
    const {
      TargetPlatform.android,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);
