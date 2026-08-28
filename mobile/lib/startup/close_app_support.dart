// ABOUTME: Identifies platforms where Divine can close its own process.
// ABOUTME: Keeps unsupported startup screens from offering dead close actions.

import 'package:flutter/foundation.dart';

/// Whether the current platform lets Divine end its own process.
///
/// Android is deliberately allowlisted. Other platforms either cannot honor
/// `SystemNavigator.pop` from the app root or have not been verified here.
bool get platformCanCloseApp =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
