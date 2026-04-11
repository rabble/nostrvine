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
      test('exposes every shipped locale in the picker', () {
        // The picker iterates this map. Every locale that ships an ARB
        // file belongs here; users can pick any of them and untranslated
        // keys fall back to English through AppLocalizations.
        expect(
          LocalePreferenceService.supportedLocales.keys,
          unorderedEquals(<String>[
            'en',
            'ar',
            'de',
            'es',
            'fr',
            'id',
            'it',
            'ja',
            'ko',
            'nl',
            'pl',
            'pt',
            'ro',
            'sv',
            'tr',
          ]),
        );
        expect(LocalePreferenceService.supportedLocales['en'], 'English');
        expect(LocalePreferenceService.supportedLocales['ar'], 'العربية');
        expect(LocalePreferenceService.supportedLocales['ko'], '한국어');
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
