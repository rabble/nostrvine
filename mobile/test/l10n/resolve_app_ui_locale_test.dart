// ABOUTME: Tests for resolveAppUiLocale (device locale vs supported list)

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/resolve_app_ui_locale.dart';

void main() {
  const supported = AppLocalizations.supportedLocales;

  group('resolveAppUiLocale', () {
    test('keeps English first for Flutter framework fallback', () {
      expect(supported.first.languageCode, 'en');
    });

    test('uses English when device language is not supported (Russian)', () {
      final locale = resolveAppUiLocale(const [Locale('ru')], supported);
      expect(locale.languageCode, 'en');
    });

    test('uses English when device language is not supported (Chinese)', () {
      final locale = resolveAppUiLocale(const [Locale('zh', 'CN')], supported);
      expect(locale.languageCode, 'en');
    });

    test(
      'does not pick Arabic as implicit fallback for unsupported device',
      () {
        final locale = resolveAppUiLocale(const [Locale('ru')], supported);
        expect(locale.languageCode, isNot('ar'));
      },
    );

    test('matches supported German', () {
      final locale = resolveAppUiLocale(const [Locale('de', 'DE')], supported);
      expect(locale.languageCode, 'de');
    });

    test('matches supported Bulgarian', () {
      final locale = resolveAppUiLocale(const [Locale('bg', 'BG')], supported);
      expect(locale.languageCode, 'bg');
    });

    test('matches English when preferred', () {
      final locale = resolveAppUiLocale(const [Locale('en', 'US')], supported);
      expect(locale.languageCode, 'en');
    });

    test('uses later preferred locale when earlier is unsupported', () {
      final locale = resolveAppUiLocale(const [
        Locale('zh'),
        Locale('es'),
      ], supported);
      expect(locale.languageCode, 'es');
    });

    test('uses Arabic when device prefers Arabic', () {
      final locale = resolveAppUiLocale(const [Locale('ar')], supported);
      expect(locale.languageCode, 'ar');
    });

    test('falls back to English when preferred list is empty', () {
      final locale = resolveAppUiLocale(const <Locale>[], supported);
      expect(locale.languageCode, 'en');
    });

    test('treats null preferred list like empty (English)', () {
      final locale = resolveAppUiLocale(null, supported);
      expect(locale.languageCode, 'en');
    });
  });
}
