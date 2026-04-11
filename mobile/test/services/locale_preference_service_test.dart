// ABOUTME: Tests for LocalePreferenceService
// ABOUTME: Verifies SharedPreferences persistence and picker locale lookup.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/locale_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(LocalePreferenceService, () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    Future<LocalePreferenceService> build() async {
      final prefs = await SharedPreferences.getInstance();
      return LocalePreferenceService(sharedPreferences: prefs);
    }

    group('getLocale', () {
      test('returns null when no locale has been saved', () async {
        final service = await build();

        expect(service.getLocale(), isNull);
      });

      test('returns the value that was previously written', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          LocalePreferenceService.prefsKey: 'tr',
        });
        final service = await build();

        expect(service.getLocale(), 'tr');
      });
    });

    group('setLocale', () {
      test('persists the value so subsequent reads return it', () async {
        final service = await build();

        await service.setLocale('es');

        expect(service.getLocale(), 'es');
      });

      test('overwrites a previously stored locale', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          LocalePreferenceService.prefsKey: 'es',
        });
        final service = await build();

        await service.setLocale('tr');

        expect(service.getLocale(), 'tr');
      });
    });

    group('clearLocale', () {
      test('removes a previously stored locale', () async {
        SharedPreferences.setMockInitialValues(<String, Object>{
          LocalePreferenceService.prefsKey: 'es',
        });
        final service = await build();

        await service.clearLocale();

        expect(service.getLocale(), isNull);
      });

      test('is a no-op when no locale is stored', () async {
        final service = await build();

        await service.clearLocale();

        expect(service.getLocale(), isNull);
      });
    });

    group('supportedLocales', () {
      test('only exposes fully translated locales in the picker', () {
        // The picker iterates this map. Keep it intentionally narrow —
        // only locales with near-full coverage should appear. Partial
        // translations ship via `AppLocalizations.supportedLocales` but
        // must stay hidden from the user-facing switcher until coverage
        // catches up.
        //
        // If this list changes, double-check coverage by running
        // `flutter gen-l10n` and reviewing the untranslated-message
        // counts — anything below ~99% should stay out of the picker.
        expect(
          LocalePreferenceService.supportedLocales.keys,
          unorderedEquals(<String>[
            'en',
            'de',
            'es',
            'fr',
            'id',
            'it',
            'ja',
            'nl',
            'pl',
            'pt',
            'ro',
            'sv',
            'tr',
          ]),
        );
        expect(LocalePreferenceService.supportedLocales['en'], 'English');
      });

      test('partial locales are not exposed in the picker', () {
        // app_ar.arb and app_ko.arb only cover ~34–38% of keys. Re-add
        // once coverage is materially higher.
        expect(
          LocalePreferenceService.supportedLocales.keys,
          isNot(contains('ar')),
        );
        expect(
          LocalePreferenceService.supportedLocales.keys,
          isNot(contains('ko')),
        );
      });
    });

    group('nativeNameFor', () {
      test('returns the native name for a known locale', () {
        expect(LocalePreferenceService.nativeNameFor('en'), 'English');
      });

      test('falls back to the uppercased code for unknown locales', () {
        expect(LocalePreferenceService.nativeNameFor('xx'), 'XX');
      });
    });
  });
}
