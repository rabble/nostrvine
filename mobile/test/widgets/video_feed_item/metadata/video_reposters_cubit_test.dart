// ABOUTME: Unit tests for VideoRepostersCubit.
// ABOUTME: Pins the success/error paths and the close-during-fetch race
// ABOUTME: that previously surfaced as a Crashlytics 'emit after close'.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/widgets/video_feed_item/metadata/video_reposters_cubit.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

void main() {
  group(VideoRepostersCubit, () {
    late _MockVideoEventService service;

    setUp(() {
      service = _MockVideoEventService();
    });

    blocTest<VideoRepostersCubit, VideoRepostersState>(
      'emits success state when fetch resolves before close',
      setUp: () {
        when(
          () => service.getRepostersForVideo('video-id'),
        ).thenAnswer((_) async => ['pubkey-a', 'pubkey-b']);
      },
      build: () => VideoRepostersCubit(
        videoEventService: service,
        videoId: 'video-id',
      ),
      expect: () => const [
        VideoRepostersState(
          pubkeys: ['pubkey-a', 'pubkey-b'],
          isLoading: false,
        ),
      ],
    );

    test('moves to loading=false when videoId is empty', () async {
      final cubit = VideoRepostersCubit(
        videoEventService: service,
        videoId: '',
      );
      // The empty-id branch emits synchronously inside the constructor,
      // so a direct state check is the right shape — blocTest's stream
      // listener attaches too late to observe it.
      expect(cubit.state, equals(const VideoRepostersState(isLoading: false)));
      verifyNever(() => service.getRepostersForVideo(any()));
      await cubit.close();
    });

    blocTest<VideoRepostersCubit, VideoRepostersState>(
      'emits loading=false and reports addError on relay failure',
      setUp: () {
        when(
          () => service.getRepostersForVideo('video-id'),
        ).thenAnswer((_) async => throw StateError('relay unavailable'));
      },
      build: () => VideoRepostersCubit(
        videoEventService: service,
        videoId: 'video-id',
      ),
      expect: () => const [VideoRepostersState(isLoading: false)],
      errors: () => [isA<StateError>()],
    );

    test(
      'does not emit (or throw) when closed before in-flight fetch resolves '
      '— regression for #3734 emit-after-close race',
      () async {
        final completer = Completer<List<String>>();
        when(
          () => service.getRepostersForVideo('video-id'),
        ).thenAnswer((_) => completer.future);

        final cubit = VideoRepostersCubit(
          videoEventService: service,
          videoId: 'video-id',
        );

        final emissions = <VideoRepostersState>[];
        final subscription = cubit.stream.listen(emissions.add);

        await cubit.close();
        completer.complete(['pubkey-late']);
        await Future<void>.delayed(Duration.zero);

        expect(emissions, isEmpty);
        await subscription.cancel();
      },
    );

    test(
      'does not emit (or addError) when closed before in-flight fetch errors',
      () async {
        final completer = Completer<List<String>>();
        when(
          () => service.getRepostersForVideo('video-id'),
        ).thenAnswer((_) => completer.future);

        final cubit = VideoRepostersCubit(
          videoEventService: service,
          videoId: 'video-id',
        );

        final emissions = <VideoRepostersState>[];
        final subscription = cubit.stream.listen(emissions.add);

        await cubit.close();
        completer.completeError(StateError('relay timeout'));
        await Future<void>.delayed(Duration.zero);

        expect(emissions, isEmpty);
        await subscription.cancel();
      },
    );
  });
}
