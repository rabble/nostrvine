import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group(ContentFilterService, () {
    late ContentFilterService service;
    late AgeVerificationService ageService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      ageService = AgeVerificationService();
      service = ContentFilterService(ageVerificationService: ageService);
    });

    group('initialization', () {
      test('initializes with default preferences', () async {
        await service.initialize();

        expect(service.isInitialized, isTrue);
        expect(
          service.getPreference(ContentLabel.nudity),
          equals(ContentFilterPreference.hide),
        );
        expect(
          service.getPreference(ContentLabel.violence),
          equals(ContentFilterPreference.warn),
        );
        expect(
          service.getPreference(ContentLabel.drugs),
          equals(ContentFilterPreference.show),
        );
      });

      test('only initializes once', () async {
        await service.initialize();
        await service.setPreference(
          ContentLabel.drugs,
          ContentFilterPreference.warn,
        );
        await service.initialize(); // Should not reset

        expect(
          service.getPreference(ContentLabel.drugs),
          equals(ContentFilterPreference.warn),
        );
      });
    });

    group('default preferences', () {
      test('adult categories default to hide', () async {
        await service.initialize();

        for (final label in ContentFilterService.adultCategories) {
          expect(
            service.getPreference(label),
            equals(ContentFilterPreference.hide),
            reason: '${label.displayName} should default to hide',
          );
        }
      });

      test('violence categories default to warn', () async {
        await service.initialize();

        expect(
          service.getPreference(ContentLabel.graphicMedia),
          equals(ContentFilterPreference.warn),
        );
        expect(
          service.getPreference(ContentLabel.violence),
          equals(ContentFilterPreference.warn),
        );
        expect(
          service.getPreference(ContentLabel.selfHarm),
          equals(ContentFilterPreference.warn),
        );
      });

      test('substance categories default to show', () async {
        await service.initialize();

        expect(
          service.getPreference(ContentLabel.drugs),
          equals(ContentFilterPreference.show),
        );
        expect(
          service.getPreference(ContentLabel.alcohol),
          equals(ContentFilterPreference.show),
        );
      });
    });

    group('setPreference', () {
      test('updates preference for a category', () async {
        await service.initialize();

        await service.setPreference(
          ContentLabel.violence,
          ContentFilterPreference.hide,
        );

        expect(
          service.getPreference(ContentLabel.violence),
          equals(ContentFilterPreference.hide),
        );
      });

      test('persists preference across instances', () async {
        await service.initialize();
        await service.setPreference(
          ContentLabel.profanity,
          ContentFilterPreference.warn,
        );

        // Create new instance
        final newService = ContentFilterService(
          ageVerificationService: ageService,
        );
        await newService.initialize();

        expect(
          newService.getPreference(ContentLabel.profanity),
          equals(ContentFilterPreference.warn),
        );
      });
    });

    group('age gate enforcement', () {
      test('adult categories locked to hide when not age verified', () async {
        await ageService.initialize();
        await service.initialize();

        // Not verified - should be locked
        expect(ageService.isAdultContentVerified, isFalse);
        expect(
          service.getPreference(ContentLabel.nudity),
          equals(ContentFilterPreference.hide),
        );
        expect(
          service.getPreference(ContentLabel.sexual),
          equals(ContentFilterPreference.hide),
        );
        expect(
          service.getPreference(ContentLabel.porn),
          equals(ContentFilterPreference.hide),
        );
      });

      test(
        'cannot set adult category to show without age verification',
        () async {
          await ageService.initialize();
          await service.initialize();

          await service.setPreference(
            ContentLabel.nudity,
            ContentFilterPreference.show,
          );

          // Should still be hide since not age verified
          expect(
            service.getPreference(ContentLabel.nudity),
            equals(ContentFilterPreference.hide),
          );
        },
      );

      test('can set adult category to show when age verified', () async {
        await ageService.initialize();
        await ageService.setAdultContentVerified(true);
        await service.initialize();

        await service.setPreference(
          ContentLabel.nudity,
          ContentFilterPreference.show,
        );

        expect(
          service.getPreference(ContentLabel.nudity),
          equals(ContentFilterPreference.show),
        );
      });

      test('non-adult categories not affected by age gate', () async {
        await ageService.initialize();
        await service.initialize();

        await service.setPreference(
          ContentLabel.violence,
          ContentFilterPreference.show,
        );

        expect(
          service.getPreference(ContentLabel.violence),
          equals(ContentFilterPreference.show),
        );
      });
    });

    group('getPreferenceForLabels', () {
      test('returns show when no labels match', () async {
        await service.initialize();

        final result = service.getPreferenceForLabels(['unknown-label']);
        expect(result, equals(ContentFilterPreference.show));
      });

      test('returns show for empty list', () async {
        await service.initialize();

        final result = service.getPreferenceForLabels([]);
        expect(result, equals(ContentFilterPreference.show));
      });

      test('returns most restrictive preference', () async {
        await service.initialize();

        // drugs=show, violence=warn -> should return warn
        final result = service.getPreferenceForLabels(['drugs', 'violence']);
        expect(result, equals(ContentFilterPreference.warn));
      });

      test('returns hide when any label is hide', () async {
        await service.initialize();

        // drugs=show, nudity=hide -> should return hide
        final result = service.getPreferenceForLabels(['drugs', 'nudity']);
        expect(result, equals(ContentFilterPreference.hide));
      });
    });

    group('lockAdultCategories', () {
      test('resets all adult categories to hide', () async {
        await ageService.initialize();
        await ageService.setAdultContentVerified(true);
        await service.initialize();

        // Set adult categories to show (allowed when verified)
        await service.setPreference(
          ContentLabel.nudity,
          ContentFilterPreference.show,
        );
        await service.setPreference(
          ContentLabel.sexual,
          ContentFilterPreference.warn,
        );

        // Lock them back
        await service.lockAdultCategories();

        for (final label in ContentFilterService.adultCategories) {
          expect(
            service.getPreference(label),
            equals(ContentFilterPreference.hide),
            reason: '${label.displayName} should be locked to hide',
          );
        }
      });
    });

    group('allPreferences', () {
      test('returns unmodifiable map of all preferences', () async {
        await service.initialize();

        final prefs = service.allPreferences;

        // Should have entries for all labels except other
        expect(prefs.length, greaterThanOrEqualTo(17));
        expect(
          () => (prefs as Map)[ContentLabel.nudity] =
              ContentFilterPreference.show,
          throwsUnsupportedError,
        );
      });
    });

    group('migration from old preferences', () {
      test('migrates alwaysShow to show for adult categories', () async {
        SharedPreferences.setMockInitialValues({
          // AdultContentPreference.alwaysShow = index 0
          'adult_content_preference': 0,
        });

        await ageService.initialize();
        await ageService.setAdultContentVerified(true);
        final migrationService = ContentFilterService(
          ageVerificationService: ageService,
        );
        await migrationService.initialize();

        // After migration, adult categories should be show
        // (but only visible when age-verified)
        expect(
          migrationService.getPreference(ContentLabel.nudity),
          equals(ContentFilterPreference.show),
        );
      });

      test('migrates askEachTime to warn for adult categories', () async {
        SharedPreferences.setMockInitialValues({
          // AdultContentPreference.askEachTime = index 1
          'adult_content_preference': 1,
        });

        await ageService.initialize();
        await ageService.setAdultContentVerified(true);
        final migrationService = ContentFilterService(
          ageVerificationService: ageService,
        );
        await migrationService.initialize();

        expect(
          migrationService.getPreference(ContentLabel.nudity),
          equals(ContentFilterPreference.warn),
        );
      });

      test('migrates neverShow to hide for adult categories', () async {
        SharedPreferences.setMockInitialValues({
          // AdultContentPreference.neverShow = index 2
          'adult_content_preference': 2,
        });

        final migrationService = ContentFilterService(
          ageVerificationService: ageService,
        );
        await migrationService.initialize();

        expect(
          migrationService.getPreference(ContentLabel.nudity),
          equals(ContentFilterPreference.hide),
        );
      });

      test('only migrates once', () async {
        SharedPreferences.setMockInitialValues({
          'adult_content_preference': 0, // alwaysShow
        });

        await ageService.initialize();
        await ageService.setAdultContentVerified(true);

        // First initialization migrates
        final firstService = ContentFilterService(
          ageVerificationService: ageService,
        );
        await firstService.initialize();

        // Change preference after migration
        await firstService.setPreference(
          ContentLabel.nudity,
          ContentFilterPreference.hide,
        );

        // Second initialization should NOT re-migrate
        final secondService = ContentFilterService(
          ageVerificationService: ageService,
        );
        await secondService.initialize();

        expect(
          secondService.getPreference(ContentLabel.nudity),
          equals(ContentFilterPreference.hide),
        );
      });
    });
  });
}
