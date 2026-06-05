// ABOUTME: Firebase option validation used before initializing Firebase SDKs.
// ABOUTME: Prevents placeholder configs from starting broken web/native clients.

import 'package:firebase_core/firebase_core.dart';
import 'package:openvine/firebase_options.dart';
import 'package:openvine/utils/platform_support.dart';

/// Returns the current platform Firebase options only when they are usable.
///
/// Several non-production targets intentionally carry placeholder values in
/// [DefaultFirebaseOptions]. Initializing Firebase with those values makes web
/// preview builds throw repeated Firebase Installations/Analytics errors, so
/// callers should treat a null value as "Firebase disabled for this build".
FirebaseOptions? get usableDefaultFirebaseOptions {
  if (!isFirebaseSupported) return null;

  try {
    final options = DefaultFirebaseOptions.currentPlatform;
    return hasUsableFirebaseOptions(options) ? options : null;
  } catch (_) {
    return null;
  }
}

bool hasUsableFirebaseOptions(FirebaseOptions options) =>
    _hasRealValue(options.apiKey) &&
    _hasRealValue(options.appId) &&
    _hasRealValue(options.messagingSenderId) &&
    _hasRealValue(options.projectId);

bool _hasRealValue(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return false;

  final lower = trimmed.toLowerCase();
  return !lower.contains('placeholder');
}
