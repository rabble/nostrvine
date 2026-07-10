// ABOUTME: Unit tests for AccountStateResumeRefresher TTL-guarded resume refetch
// ABOUTME: Verifies min-interval gating, auth gating, and both-provider invalidation

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/minor_account_review_status.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/providers/minor_account_review_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/services/account_state_resume_refresher.dart';

void main() {
  group(AccountStateResumeRefresher, () {
    late int protectedMinorInvalidations;
    late int reviewInvalidations;
    late DateTime now;

    AccountStateResumeRefresher build({
      Duration minInterval = const Duration(minutes: 15),
    }) {
      return AccountStateResumeRefresher(
        invalidateProtectedMinorStatus: () => protectedMinorInvalidations++,
        invalidateReviewStatus: () => reviewInvalidations++,
        minInterval: minInterval,
        now: () => now,
      );
    }

    setUp(() {
      protectedMinorInvalidations = 0;
      reviewInvalidations = 0;
      now = DateTime(2026, 7, 10, 12);
    });

    test('refreshes both providers on the first authenticated resume', () {
      build().refreshOnResume(authenticated: true);

      expect(protectedMinorInvalidations, 1);
      expect(reviewInvalidations, 1);
    });

    test('does not refresh when unauthenticated', () {
      build().refreshOnResume(authenticated: false);

      expect(protectedMinorInvalidations, isZero);
      expect(reviewInvalidations, isZero);
    });

    test('skips a second resume within the min-interval', () {
      final refresher = build();

      refresher.refreshOnResume(authenticated: true);
      now = now.add(const Duration(minutes: 14, seconds: 59));
      refresher.refreshOnResume(authenticated: true);

      expect(protectedMinorInvalidations, 1);
      expect(reviewInvalidations, 1);
    });

    test('refreshes again once the min-interval has elapsed', () {
      final refresher = build();

      refresher.refreshOnResume(authenticated: true);
      now = now.add(const Duration(minutes: 15));
      refresher.refreshOnResume(authenticated: true);

      expect(protectedMinorInvalidations, 2);
      expect(reviewInvalidations, 2);
    });

    test('an unauthenticated resume does not start the interval clock', () {
      final refresher = build();

      // No-op: must not record a timestamp that would suppress the next
      // authenticated resume.
      refresher.refreshOnResume(authenticated: false);
      now = now.add(const Duration(minutes: 1));
      refresher.refreshOnResume(authenticated: true);

      expect(protectedMinorInvalidations, 1);
      expect(reviewInvalidations, 1);
    });
  });

  group('accountStateResumeRefresherProvider', () {
    test(
      'invalidates the real account-state providers on resume, and the '
      'interval guard suppresses a rapid second resume',
      () async {
        var protectedBuilds = 0;
        var reviewBuilds = 0;
        final container = ProviderContainer(
          overrides: [
            protectedMinorStatusProvider.overrideWith((ref) async {
              protectedBuilds++;
              return ProtectedMinorStatus.notProtected();
            }),
            currentMinorAccountReviewStatusProvider.overrideWith((ref) async {
              reviewBuilds++;
              return MinorAccountReviewStatus.active();
            }),
          ],
        );
        addTearDown(container.dispose);

        // First resolution.
        await container.read(protectedMinorStatusProvider.future);
        await container.read(currentMinorAccountReviewStatusProvider.future);
        expect(protectedBuilds, 1);
        expect(reviewBuilds, 1);

        // Resume invalidates both; re-reading forces the rebuild.
        container
            .read(accountStateResumeRefresherProvider)
            .refreshOnResume(authenticated: true);
        await container.read(protectedMinorStatusProvider.future);
        await container.read(currentMinorAccountReviewStatusProvider.future);
        expect(protectedBuilds, 2);
        expect(reviewBuilds, 2);

        // A second resume within the 15-minute default is suppressed.
        container
            .read(accountStateResumeRefresherProvider)
            .refreshOnResume(authenticated: true);
        await container.read(protectedMinorStatusProvider.future);
        await container.read(currentMinorAccountReviewStatusProvider.future);
        expect(protectedBuilds, 2);
        expect(reviewBuilds, 2);
      },
    );
  });
}
