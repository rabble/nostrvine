// ABOUTME: Tests for FeedLoadingModerationCubit.
// ABOUTME: Covers deferred moderation check, timer cancellation, and error handling.

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/feed_loading_moderation/feed_loading_moderation_cubit.dart';
import 'package:openvine/blocs/feed_loading_moderation/feed_loading_moderation_state.dart';
import 'package:openvine/services/video_moderation_status_service.dart';

class _MockVideoModerationStatusService extends Mock
    implements VideoModerationStatusService {}

void main() {
  // Valid 64-char hex sha256.
  const sha256 =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  // URL whose host ends with divine.video and whose path encodes sha256.
  const divineUrl =
      'https://cdn.divine.video/'
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      '.mp4';

  const blockedStatus = VideoModerationStatus(
    moderated: true,
    blocked: true,
    quarantined: false,
    ageRestricted: false,
    needsReview: false,
    aiGenerated: false,
  );

  const notBlockedStatus = VideoModerationStatus(
    moderated: false,
    blocked: false,
    quarantined: false,
    ageRestricted: false,
    needsReview: false,
    aiGenerated: false,
  );

  late _MockVideoModerationStatusService mockService;

  setUp(() {
    mockService = _MockVideoModerationStatusService();
  });

  FeedLoadingModerationCubit buildCubit({
    String? explicitSha256,
    String? videoUrl,
    Duration checkDelay = const Duration(seconds: 2),
  }) {
    return FeedLoadingModerationCubit(
      service: mockService,
      explicitSha256: explicitSha256,
      videoUrl: videoUrl,
      checkDelay: checkDelay,
    );
  }

  group(FeedLoadingModerationCubit, () {
    group('initial state', () {
      test('is loading and not restricted', () {
        final cubit = buildCubit();
        expect(cubit.state, const FeedLoadingModerationState());
        expect(cubit.state.isRestricted, isFalse);
        cubit.close();
      });
    });

    group('start', () {
      test('is a no-op when videoUrl is null', () {
        fakeAsync((fake) {
          final cubit = buildCubit();
          cubit.start();
          fake.elapse(const Duration(seconds: 5));
          fake.flushMicrotasks();
          expect(cubit.state.isRestricted, isFalse);
          verifyNever(() => mockService.fetchStatus(any()));
          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('is a no-op when videoUrl host is not a divine host', () {
        fakeAsync((fake) {
          final cubit = buildCubit(videoUrl: 'https://example.com/video.mp4');
          cubit.start();
          fake.elapse(const Duration(seconds: 5));
          fake.flushMicrotasks();
          expect(cubit.state.isRestricted, isFalse);
          verifyNever(() => mockService.fetchStatus(any()));
          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('does not emit restricted before the delay elapses', () {
        when(
          () => mockService.fetchStatus(sha256),
        ).thenAnswer((_) async => blockedStatus);

        fakeAsync((fake) {
          final cubit = buildCubit(videoUrl: divineUrl);
          cubit.start();
          fake.elapse(const Duration(milliseconds: 1999));
          fake.flushMicrotasks();
          expect(cubit.state.isRestricted, isFalse);
          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test(
        'emits restricted after delay when service returns a blocked status',
        () {
          when(
            () => mockService.fetchStatus(sha256),
          ).thenAnswer((_) async => blockedStatus);

          fakeAsync((fake) {
            final cubit = buildCubit(videoUrl: divineUrl);
            cubit.start();
            fake.elapse(const Duration(seconds: 2));
            fake.flushMicrotasks();
            expect(cubit.state.isRestricted, isTrue);
            verify(() => mockService.fetchStatus(sha256)).called(1);
            cubit.close();
            fake.flushMicrotasks();
          });
        },
      );

      test('emits restricted when service returns age-restricted status', () {
        const ageRestricted = VideoModerationStatus(
          moderated: true,
          blocked: false,
          quarantined: false,
          ageRestricted: true,
          needsReview: false,
          aiGenerated: false,
        );
        when(
          () => mockService.fetchStatus(sha256),
        ).thenAnswer((_) async => ageRestricted);

        fakeAsync((fake) {
          final cubit = buildCubit(videoUrl: divineUrl);
          cubit.start();
          fake.elapse(const Duration(seconds: 2));
          fake.flushMicrotasks();
          expect(cubit.state.isRestricted, isTrue);
          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('stays loading when service returns null', () {
        when(
          () => mockService.fetchStatus(sha256),
        ).thenAnswer((_) async => null);

        fakeAsync((fake) {
          final cubit = buildCubit(videoUrl: divineUrl);
          cubit.start();
          fake.elapse(const Duration(seconds: 3));
          fake.flushMicrotasks();
          expect(cubit.state.isRestricted, isFalse);
          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('stays loading when service returns a non-blocked status', () {
        when(
          () => mockService.fetchStatus(sha256),
        ).thenAnswer((_) async => notBlockedStatus);

        fakeAsync((fake) {
          final cubit = buildCubit(videoUrl: divineUrl);
          cubit.start();
          fake.elapse(const Duration(seconds: 3));
          fake.flushMicrotasks();
          expect(cubit.state.isRestricted, isFalse);
          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test(
        'prefers explicitSha256 over url-derived sha256 when both provided',
        () {
          const explicitSha256 =
              'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
          when(
            () => mockService.fetchStatus(explicitSha256),
          ).thenAnswer((_) async => null);

          fakeAsync((fake) {
            final cubit = buildCubit(
              explicitSha256: explicitSha256,
              videoUrl: divineUrl,
            );
            cubit.start();
            fake.elapse(const Duration(seconds: 3));
            fake.flushMicrotasks();
            verify(() => mockService.fetchStatus(explicitSha256)).called(1);
            verifyNever(() => mockService.fetchStatus(sha256));
            cubit.close();
            fake.flushMicrotasks();
          });
        },
      );
    });

    group('close', () {
      test('cancels the timer so fetchStatus is never called', () {
        fakeAsync((fake) {
          final cubit = buildCubit(videoUrl: divineUrl);
          cubit.start();
          cubit.close();
          fake.elapse(const Duration(seconds: 3));
          fake.flushMicrotasks();
          verifyNever(() => mockService.fetchStatus(any()));
        });
      });
    });

    group('error handling', () {
      blocTest<FeedLoadingModerationCubit, FeedLoadingModerationState>(
        'calls addError and stays loading when fetchStatus throws',
        build: () {
          when(
            () => mockService.fetchStatus(any()),
          ).thenThrow(Exception('network error'));
          return FeedLoadingModerationCubit(
            service: mockService,
            explicitSha256: sha256,
            videoUrl: divineUrl,
            checkDelay: Duration.zero,
          );
        },
        act: (cubit) => cubit.start(),
        wait: const Duration(milliseconds: 50),
        errors: () => [isA<Exception>()],
        expect: () => const <FeedLoadingModerationState>[],
      );
    });
  });
}
