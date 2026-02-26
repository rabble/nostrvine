// ABOUTME: Tests for LanguagePreferenceService
// ABOUTME: Verifies language preference storage, device default fallback, and
// custom language override behavior

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/language_preference_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(LanguagePreferenceService, () {
    late LanguagePreferenceService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = LanguagePreferenceService();
    });

    group('contentLanguage', () {
      test('returns device language code when no custom language is set', () {
        final deviceLang = PlatformDispatcher.instance.locale.languageCode;
        expect(service.contentLanguage, equals(deviceLang));
      });

      test(
        'returns device language after initialize with empty prefs',
        () async {
          await service.initialize();
          final deviceLang = PlatformDispatcher.instance.locale.languageCode;
          expect(service.contentLanguage, equals(deviceLang));
        },
      );

      test(
        'returns saved language after initialize with existing preference',
        () async {
          SharedPreferences.setMockInitialValues({
            LanguagePreferenceService.prefsKey: 'es',
          });
          service = LanguagePreferenceService();
          await service.initialize();

          expect(service.contentLanguage, equals('es'));
        },
      );
    });

    group('setContentLanguage', () {
      test('persists and returns the set value', () async {
        await service.initialize();

        await service.setContentLanguage('pt');
        expect(service.contentLanguage, equals('pt'));

        // Verify it persisted to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString(LanguagePreferenceService.prefsKey),
          equals('pt'),
        );
      });

      test('overrides device default', () async {
        await service.initialize();
        final deviceLang = PlatformDispatcher.instance.locale.languageCode;

        // Before setting, returns device default
        expect(service.contentLanguage, equals(deviceLang));

        // After setting, returns custom value
        await service.setContentLanguage('ja');
        expect(service.contentLanguage, equals('ja'));
      });
    });

    group('clearContentLanguage', () {
      test('reverts to device default after clearing', () async {
        await service.initialize();

        // Set a custom language
        await service.setContentLanguage('fr');
        expect(service.contentLanguage, equals('fr'));

        // Clear it
        await service.clearContentLanguage();
        final deviceLang = PlatformDispatcher.instance.locale.languageCode;
        expect(service.contentLanguage, equals(deviceLang));
      });

      test('removes the key from SharedPreferences', () async {
        await service.initialize();

        await service.setContentLanguage('de');
        await service.clearContentLanguage();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(LanguagePreferenceService.prefsKey), isNull);
      });
    });

    group('isCustomLanguageSet', () {
      test('returns false when no custom language is set', () {
        expect(service.isCustomLanguageSet, isFalse);
      });

      test('returns false after initialize with empty prefs', () async {
        await service.initialize();
        expect(service.isCustomLanguageSet, isFalse);
      });

      test('returns true after setting a custom language', () async {
        await service.initialize();
        await service.setContentLanguage('ko');
        expect(service.isCustomLanguageSet, isTrue);
      });

      test('returns false after clearing a custom language', () async {
        await service.initialize();
        await service.setContentLanguage('ko');
        expect(service.isCustomLanguageSet, isTrue);

        await service.clearContentLanguage();
        expect(service.isCustomLanguageSet, isFalse);
      });

      test('returns true after initialize with existing preference', () async {
        SharedPreferences.setMockInitialValues({
          LanguagePreferenceService.prefsKey: 'zh',
        });
        service = LanguagePreferenceService();
        await service.initialize();

        expect(service.isCustomLanguageSet, isTrue);
      });
    });

    group('displayNameFor', () {
      test('returns display name for known language codes', () {
        expect(
          LanguagePreferenceService.displayNameFor('en'),
          equals('English'),
        );
        expect(
          LanguagePreferenceService.displayNameFor('es'),
          equals('Spanish'),
        );
        expect(
          LanguagePreferenceService.displayNameFor('pt'),
          equals('Portuguese'),
        );
        expect(
          LanguagePreferenceService.displayNameFor('ja'),
          equals('Japanese'),
        );
      });

      test('returns uppercased code for unknown language codes', () {
        expect(LanguagePreferenceService.displayNameFor('xx'), equals('XX'));
      });
    });
  });
}
