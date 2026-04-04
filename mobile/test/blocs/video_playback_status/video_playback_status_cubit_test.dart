import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

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

    test(
      'states with same entries but different LRU order are not equal',
      () {
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
      },
    );

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
        expect(
          playbackStatusFromError(null),
          PlaybackStatus.generic,
        );
      });
    });
  });
}
