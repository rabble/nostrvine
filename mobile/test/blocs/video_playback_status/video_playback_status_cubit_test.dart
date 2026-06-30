import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart'
    show VideoErrorType;
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';

void main() {
  group(VideoPlaybackStatusCubit, () {
    const id1 =
        '1111111111111111111111111111111111111111111111111111111111111111';
    const id2 =
        '2222222222222222222222222222222222222222222222222222222222222222';

    blocTest<VideoPlaybackStatusCubit, VideoPlaybackStatusState>(
      'records status for an event ID',
      build: VideoPlaybackStatusCubit.new,
      act: (cubit) => cubit.report(id1, PlaybackStatus.forbidden),
      verify: (cubit) {
        expect(cubit.state.statusFor(id1), PlaybackStatus.forbidden);
        expect(cubit.state.statusFor(id2), PlaybackStatus.ready);
      },
    );

    blocTest<VideoPlaybackStatusCubit, VideoPlaybackStatusState>(
      'emits a new state on each status change',
      build: VideoPlaybackStatusCubit.new,
      act: (cubit) {
        cubit.report(id1, PlaybackStatus.ageRestricted);
        cubit.report(id2, PlaybackStatus.forbidden);
      },
      expect: () => hasLength(2),
    );

    blocTest<VideoPlaybackStatusCubit, VideoPlaybackStatusState>(
      'clear() resets all statuses',
      build: VideoPlaybackStatusCubit.new,
      act: (cubit) {
        cubit.report(id1, PlaybackStatus.forbidden);
        cubit.clear();
      },
      verify: (cubit) {
        expect(cubit.state.statusFor(id1), PlaybackStatus.ready);
      },
    );

    test('evicts oldest entry when maxEntries is exceeded', () {
      final cubit = VideoPlaybackStatusCubit(maxEntries: 2);
      cubit.report(id1, PlaybackStatus.forbidden);
      cubit.report(id2, PlaybackStatus.ageRestricted);
      cubit.report(
        '3333333333333333333333333333333333333333333333333333333333333333',
        PlaybackStatus.notFound,
      );

      expect(cubit.state.statusFor(id1), PlaybackStatus.ready); // evicted
      expect(cubit.state.statusFor(id2), PlaybackStatus.ageRestricted);
    });

    test('states with same entries but different LRU order are not equal', () {
      const idA =
          '5555555555555555555555555555555555555555555555555555555555555555';
      const idB =
          '6666666666666666666666666666666666666666666666666666666666666666';

      final a = VideoPlaybackStatusState()
          .withStatus(idA, PlaybackStatus.forbidden)
          .withStatus(idB, PlaybackStatus.ageRestricted);
      final b = VideoPlaybackStatusState()
          .withStatus(idB, PlaybackStatus.ageRestricted)
          .withStatus(idA, PlaybackStatus.forbidden);

      expect(a, isNot(equals(b)));
    });

    test('reporting same id twice moves it to most-recent', () {
      final cubit = VideoPlaybackStatusCubit(maxEntries: 2);
      cubit.report(id1, PlaybackStatus.forbidden);
      cubit.report(id2, PlaybackStatus.ageRestricted);
      // Use a different status to avoid the no-op short-circuit while
      // still exercising the LRU refresh semantics.
      cubit.report(id1, PlaybackStatus.generic); // refresh id1
      cubit.report(
        '4444444444444444444444444444444444444444444444444444444444444444',
        PlaybackStatus.notFound,
      );

      // id2 should be evicted now, id1 survived.
      expect(cubit.state.statusFor(id2), PlaybackStatus.ready);
      expect(cubit.state.statusFor(id1), PlaybackStatus.generic);
    });

    blocTest<VideoPlaybackStatusCubit, VideoPlaybackStatusState>(
      'does not emit when reporting the same status twice in a row',
      build: VideoPlaybackStatusCubit.new,
      act: (cubit) {
        cubit.report(id1, PlaybackStatus.forbidden);
        cubit.report(id1, PlaybackStatus.forbidden);
      },
      expect: () => hasLength(1),
    );

    group('verifying', () {
      test('markVerifying / clearVerifying toggle the flag', () {
        final cubit = VideoPlaybackStatusCubit();
        expect(cubit.state.isVerifying(id1), isFalse);

        cubit.markVerifying(id1);
        expect(cubit.state.isVerifying(id1), isTrue);
        expect(cubit.state.isVerifying(id2), isFalse);

        cubit.clearVerifying(id1);
        expect(cubit.state.isVerifying(id1), isFalse);
      });

      blocTest<VideoPlaybackStatusCubit, VideoPlaybackStatusState>(
        'markVerifying short-circuits when already verifying',
        build: VideoPlaybackStatusCubit.new,
        act: (cubit) {
          cubit.markVerifying(id1);
          cubit.markVerifying(id1);
        },
        expect: () => hasLength(1),
      );

      blocTest<VideoPlaybackStatusCubit, VideoPlaybackStatusState>(
        'clearVerifying short-circuits when not verifying',
        build: VideoPlaybackStatusCubit.new,
        act: (cubit) => cubit.clearVerifying(id1),
        expect: () => isEmpty,
      );

      test('reporting a status preserves an in-flight verifying flag', () {
        final cubit = VideoPlaybackStatusCubit();
        cubit.markVerifying(id1);
        cubit.report(id1, PlaybackStatus.ready);

        expect(cubit.state.isVerifying(id1), isTrue);
        expect(cubit.state.statusFor(id1), PlaybackStatus.ready);
      });

      test('clear() drops verifying flags', () {
        final cubit = VideoPlaybackStatusCubit();
        cubit.markVerifying(id1);
        cubit.clear();

        expect(cubit.state.isVerifying(id1), isFalse);
      });
    });

    group('auto age-restricted retry attempts', () {
      test('consumeAutoRetryAttempt spends the per-video budget once', () {
        final cubit = VideoPlaybackStatusCubit();

        expect(cubit.consumeAutoRetryAttempt(id1), isTrue);
        expect(cubit.state.hasAutoRetryAttempted(id1), isTrue);
        expect(cubit.state.hasAutoRetryAttempted(id2), isFalse);

        expect(cubit.consumeAutoRetryAttempt(id1), isFalse);
      });

      test('reporting a status preserves the spent auto-retry budget', () {
        final cubit = VideoPlaybackStatusCubit();
        cubit.consumeAutoRetryAttempt(id1);
        cubit.report(id1, PlaybackStatus.ready);

        expect(cubit.state.hasAutoRetryAttempted(id1), isTrue);
        expect(cubit.state.statusFor(id1), PlaybackStatus.ready);
      });

      test('clear() drops spent auto-retry budgets', () {
        final cubit = VideoPlaybackStatusCubit();
        cubit.consumeAutoRetryAttempt(id1);
        cubit.clear();

        expect(cubit.state.hasAutoRetryAttempted(id1), isFalse);
      });

      test(
        'auto retry eligibility requires age restriction and verify action',
        () {
          final cubit = VideoPlaybackStatusCubit(
            canAutoAuthorizeAgeRestrictedMedia: () => true,
          );

          expect(
            cubit.consumeAgeRestrictedAutoRetryIfEligible(
              id1,
              isAgeRestricted: false,
              hasVerifyAction: true,
            ),
            isFalse,
          );
          expect(
            cubit.consumeAgeRestrictedAutoRetryIfEligible(
              id1,
              isAgeRestricted: true,
              hasVerifyAction: false,
            ),
            isFalse,
          );
          expect(cubit.state.hasAutoRetryAttempted(id1), isFalse);
        },
      );

      test('auto retry eligibility requires an auto-authorized viewer', () {
        final cubit = VideoPlaybackStatusCubit(
          canAutoAuthorizeAgeRestrictedMedia: () => false,
        );

        expect(
          cubit.consumeAgeRestrictedAutoRetryIfEligible(
            id1,
            isAgeRestricted: true,
            hasVerifyAction: true,
          ),
          isFalse,
        );
        expect(cubit.state.hasAutoRetryAttempted(id1), isFalse);
      });

      test('auto retry eligibility is blocked while verifying', () {
        final cubit = VideoPlaybackStatusCubit(
          canAutoAuthorizeAgeRestrictedMedia: () => true,
        );
        cubit.markVerifying(id1);

        expect(
          cubit.consumeAgeRestrictedAutoRetryIfEligible(
            id1,
            isAgeRestricted: true,
            hasVerifyAction: true,
          ),
          isFalse,
        );
        expect(cubit.state.hasAutoRetryAttempted(id1), isFalse);
      });

      test('auto retry eligibility spends the per-video budget once', () {
        final cubit = VideoPlaybackStatusCubit(
          canAutoAuthorizeAgeRestrictedMedia: () => true,
        );

        expect(
          cubit.consumeAgeRestrictedAutoRetryIfEligible(
            id1,
            isAgeRestricted: true,
            hasVerifyAction: true,
          ),
          isTrue,
        );
        expect(cubit.state.hasAutoRetryAttempted(id1), isTrue);
        expect(
          cubit.consumeAgeRestrictedAutoRetryIfEligible(
            id1,
            isAgeRestricted: true,
            hasVerifyAction: true,
          ),
          isFalse,
        );
      });
    });

    group('playbackStatusFromError', () {
      test('maps each VideoErrorType to the expected PlaybackStatus', () {
        expect(
          playbackStatusFromError(VideoErrorType.ageRestricted),
          PlaybackStatus.ageRestricted,
        );
        expect(
          playbackStatusFromError(VideoErrorType.forbidden),
          PlaybackStatus.forbidden,
        );
        expect(
          playbackStatusFromError(VideoErrorType.notFound),
          PlaybackStatus.notFound,
        );
        expect(
          playbackStatusFromError(VideoErrorType.generic),
          PlaybackStatus.generic,
        );
        expect(playbackStatusFromError(null), PlaybackStatus.generic);
      });
    });
  });
}
