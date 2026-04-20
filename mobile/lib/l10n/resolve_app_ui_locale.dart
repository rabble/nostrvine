// ABOUTME: Resolves app UI locale from device preferences with English fallback
// ABOUTME: Used by MaterialApp.localeListResolutionCallback in main.dart

import 'package:flutter/widgets.dart';

/// Picks a [Locale] using [basicLocaleListResolution], except when Flutter
/// would fall back to [supportedLocales.first] without any of the device's
/// preferred [Locale.languageCode] values matching that locale — then English
/// is used instead (today [supportedLocales.first] is Arabic).
///
/// Usable as [MaterialApp.localeListResolutionCallback] (a non-null
/// [Locale] is assignable where [Locale?] is expected).
Locale resolveAppUiLocale(
  List<Locale>? preferredLocales,
  Iterable<Locale> supportedLocales,
) {
  final preferred = preferredLocales ?? const <Locale>[];
  final supported = List<Locale>.from(supportedLocales);
  final deviceLanguageCodes = preferred
      .map((locale) => locale.languageCode)
      .toSet();

  final resolved = basicLocaleListResolution(preferred, supported);
  // [basicLocaleListResolution] ends with supported.first when nothing matched.
  if (resolved.languageCode == supported.first.languageCode &&
      !deviceLanguageCodes.contains(resolved.languageCode)) {
    return _englishLocale(supported);
  }
  return resolved;
}

Locale _englishLocale(List<Locale> supported) {
  return supported.firstWhere(
    (locale) => locale.languageCode == 'en',
    orElse: () => const Locale('en'),
  );
}
