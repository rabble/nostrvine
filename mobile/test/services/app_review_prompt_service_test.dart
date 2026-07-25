// ABOUTME: Tests for AppReviewPromptService eligibility gate + cooldown.
// ABOUTME: Covers every false branch, the all-true branch, cooldown expiry,
// ABOUTME: and per-user key isolation.

import 'package:app_update_repository/app_update_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/app_review_prompt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const pubkey = 'pubkey-a';

  ReviewEligibilityInputs eligibleInputs({
    String pubkey = pubkey,
    int videoCount = 50,
    InstallSource installSource = InstallSource.playStore,
    int sessionCount = 20,
    int daysSinceFirstLaunch = 30,
  }) {
    return ReviewEligibilityInputs(
      pubkey: pubkey,
      videoCount: videoCount,
      installSource: installSource,
      sessionCount: sessionCount,
      daysSinceFirstLaunch: daysSinceFirstLaunch,
    );
  }

  group(AppReviewPromptService, () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
    });

    group('shouldShow', () {
      test('returns true when every condition is met (Play Store)', () {
        final service = AppReviewPromptService(sharedPreferences: prefs);
        expect(service.shouldShow(eligibleInputs()), isTrue);
      });

      test('returns true when every condition is met (App Store)', () {
        final service = AppReviewPromptService(sharedPreferences: prefs);
        expect(
          service.shouldShow(
            eligibleInputs(installSource: InstallSource.appStore),
          ),
          isTrue,
        );
      });

      test('returns false for TestFlight installs', () {
        final service = AppReviewPromptService(sharedPreferences: prefs);
        expect(
          service.shouldShow(
            eligibleInputs(installSource: InstallSource.testFlight),
          ),
          isFalse,
        );
      });

      test('returns false for Zapstore installs', () {
        final service = AppReviewPromptService(sharedPreferences: prefs);
        expect(
          service.shouldShow(
            eligibleInputs(installSource: InstallSource.zapstore),
          ),
          isFalse,
        );
      });

      test('returns false for sideloaded installs', () {
        final service = AppReviewPromptService(sharedPreferences: prefs);
        expect(
          service.shouldShow(
            eligibleInputs(installSource: InstallSource.sideload),
          ),
          isFalse,
        );
      });

      test('returns false when videoCount equals the minimum (10)', () {
        final service = AppReviewPromptService(sharedPreferences: prefs);
        expect(
          service.shouldShow(eligibleInputs(videoCount: 10)),
          isFalse,
        );
      });

      test('returns false when videoCount is below the minimum', () {
        final service = AppReviewPromptService(sharedPreferences: prefs);
        expect(
          service.shouldShow(eligibleInputs(videoCount: 5)),
          isFalse,
        );
      });

      test('returns true when videoCount is one above the minimum', () {
        final service = AppReviewPromptService(sharedPreferences: prefs);
        expect(
          service.shouldShow(eligibleInputs(videoCount: 11)),
          isTrue,
        );
      });

      test(
        'returns true when sessions are sufficient even if days are low',
        () {
          final service = AppReviewPromptService(sharedPreferences: prefs);
          expect(
            service.shouldShow(
              eligibleInputs(sessionCount: 10, daysSinceFirstLaunch: 1),
            ),
            isTrue,
          );
        },
      );

      test(
        'returns true when days are sufficient even if sessions are low',
        () {
          final service = AppReviewPromptService(sharedPreferences: prefs);
          expect(
            service.shouldShow(
              eligibleInputs(sessionCount: 1, daysSinceFirstLaunch: 14),
            ),
            isTrue,
          );
        },
      );

      test('returns false when neither sessions nor days are sufficient', () {
        final service = AppReviewPromptService(sharedPreferences: prefs);
        expect(
          service.shouldShow(
            eligibleInputs(sessionCount: 5, daysSinceFirstLaunch: 7),
          ),
          isFalse,
        );
      });

      test('returns false for videoCount of 0', () {
        final service = AppReviewPromptService(sharedPreferences: prefs);
        expect(
          service.shouldShow(eligibleInputs(videoCount: 0)),
          isFalse,
        );
      });
    });

    group('cooldown', () {
      test('returns false immediately after recordShown', () async {
        final now = DateTime(2026, 7, 25);
        final service = AppReviewPromptService(
          sharedPreferences: prefs,
          now: () => now,
        );
        await service.recordShown(pubkey);

        expect(service.shouldShow(eligibleInputs()), isFalse);
      });

      test('returns true again after the default cooldown elapses', () async {
        final shownAt = DateTime(2026, 1, 15);
        final service = AppReviewPromptService(
          sharedPreferences: prefs,
          now: () => shownAt,
        );
        await service.recordShown(pubkey);

        // Re-evaluate well past the 180-day default cooldown.
        final laterService = AppReviewPromptService(
          sharedPreferences: prefs,
          now: () => DateTime(2026, 12, 15),
        );
        expect(laterService.shouldShow(eligibleInputs()), isTrue);
      });

      test('respects a custom cooldown via now injection', () async {
        final shownAt = DateTime(2026, 1, 15);
        final service = AppReviewPromptService(
          sharedPreferences: prefs,
          cooldown: const Duration(days: 30),
          now: () => shownAt,
        );
        await service.recordShown(pubkey);

        // 20 days later: still within the 30-day cooldown.
        final within = AppReviewPromptService(
          sharedPreferences: prefs,
          cooldown: const Duration(days: 30),
          now: () => DateTime(2026, 2, 4),
        );
        expect(within.shouldShow(eligibleInputs()), isFalse);

        // 31 days later: past the cooldown.
        final past = AppReviewPromptService(
          sharedPreferences: prefs,
          cooldown: const Duration(days: 30),
          now: () => DateTime(2026, 2, 15),
        );
        expect(past.shouldShow(eligibleInputs()), isTrue);
      });
    });

    group('completed flag', () {
      test('returns false once recordCompleted is set', () async {
        final service = AppReviewPromptService(sharedPreferences: prefs);
        await service.recordCompleted(pubkey);

        expect(service.shouldShow(eligibleInputs()), isFalse);
      });

      test(
        'completed flag short-circuits even after the cooldown elapses',
        () async {
          final service = AppReviewPromptService(
            sharedPreferences: prefs,
            now: () => DateTime(2026, 1, 15),
          );
          await service.recordShown(pubkey);
          await service.recordCompleted(pubkey);

          final laterService = AppReviewPromptService(
            sharedPreferences: prefs,
            now: () => DateTime(2026, 12, 15),
          );
          expect(laterService.shouldShow(eligibleInputs()), isFalse);
        },
      );
    });

    group('per-user key isolation', () {
      test('a cooldown on pubkey-a does not block pubkey-b', () async {
        final now = DateTime(2026, 7, 25);
        final service = AppReviewPromptService(
          sharedPreferences: prefs,
          now: () => now,
        );
        await service.recordShown('pubkey-a');

        expect(
          service.shouldShow(eligibleInputs(pubkey: 'pubkey-b')),
          isTrue,
        );
      });

      test('reset clears the cooldown for that pubkey only', () async {
        final now = DateTime(2026, 7, 25);
        final service = AppReviewPromptService(
          sharedPreferences: prefs,
          now: () => now,
        );
        await service.recordShown('pubkey-a');
        await service.recordShown('pubkey-b');
        await service.reset('pubkey-a');

        expect(service.shouldShow(eligibleInputs()), isTrue);
        expect(
          service.shouldShow(eligibleInputs(pubkey: 'pubkey-b')),
          isFalse,
        );
      });
    });

    group('recordShown uses the injected clock', () {
      test('persists the injected now, not wall-clock time', () async {
        final fixed = DateTime(2025, 6, 15, 10, 30);
        final service = AppReviewPromptService(
          sharedPreferences: prefs,
          now: () => fixed,
        );
        await service.recordShown(pubkey);

        final stored = prefs.getInt('review_prompt_dismissed_at_$pubkey');
        expect(stored, fixed.millisecondsSinceEpoch);
      });
    });
  });
}
