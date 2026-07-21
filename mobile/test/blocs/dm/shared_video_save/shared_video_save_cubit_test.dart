// ABOUTME: Tests for SharedVideoSaveCubit.
// ABOUTME: Verifies resolve states, in-flight guarding, and watermark text.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/shared_video_save/shared_video_save_cubit.dart';
import 'package:openvine/screens/inbox/conversation/dm_video_target.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../../builders/video_event_builder.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  const currentPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
  const otherPubkey =
      '1122334411223344112233441122334411223344112233441122334411223344';
  const target = DmVideoTarget(
    stableId: 'skate-loop',
    authorPubkey: otherPubkey,
    videoKind: 34236,
  );

  late _MockVideosRepository videosRepository;
  late _MockProfileRepository profileRepository;

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  setUp(() {
    videosRepository = _MockVideosRepository();
    profileRepository = _MockProfileRepository();
  });

  SharedVideoSaveCubit createCubit({String? currentUser = currentPubkey}) {
    return SharedVideoSaveCubit(
      videosRepository: videosRepository,
      profileRepository: profileRepository,
      currentPubkey: currentUser,
    );
  }

  group(SharedVideoSaveCubit, () {
    blocTest<SharedVideoSaveCubit, SharedVideoSaveState>(
      'emits originalReady for the current user video',
      build: () {
        final video = VideoEventBuilder(
          id: target.stableId,
          pubkey: currentPubkey,
        ).build();
        when(
          () => videosRepository.fetchVideoWithStatsForRouteId(
            target.stableId,
            fallbackRouteIds: target.fallbackRouteIds,
          ),
        ).thenAnswer((_) async => video);
        return createCubit();
      },
      act: (cubit) => cubit.save(target),
      expect: () => [
        const SharedVideoSaveState(status: SharedVideoSaveStatus.resolving),
        isA<SharedVideoSaveState>()
            .having(
              (state) => state.status,
              'status',
              SharedVideoSaveStatus.originalReady,
            )
            .having((state) => state.video?.id, 'video id', target.stableId),
      ],
    );

    blocTest<SharedVideoSaveCubit, SharedVideoSaveState>(
      'emits watermarkReady with resolved profile text for another creator',
      build: () {
        final video = VideoEventBuilder(
          id: target.stableId,
          pubkey: otherPubkey,
        ).build();
        when(
          () => videosRepository.fetchVideoWithStatsForRouteId(
            target.stableId,
            fallbackRouteIds: target.fallbackRouteIds,
          ),
        ).thenAnswer((_) async => video);
        when(
          () => profileRepository.getCachedProfile(pubkey: otherPubkey),
        ).thenAnswer(
          (_) async => UserProfile(
            pubkey: otherPubkey,
            rawData: const {},
            createdAt: DateTime.fromMillisecondsSinceEpoch(0),
            eventId: 'profile',
            nip05: 'alice@example.com',
          ),
        );
        return createCubit();
      },
      act: (cubit) => cubit.save(target),
      expect: () => [
        const SharedVideoSaveState(status: SharedVideoSaveStatus.resolving),
        isA<SharedVideoSaveState>()
            .having(
              (state) => state.status,
              'status',
              SharedVideoSaveStatus.watermarkReady,
            )
            .having((state) => state.video?.id, 'video id', target.stableId)
            .having(
              (state) => state.watermarkText,
              'watermark text',
              'alice@example.com',
            ),
      ],
    );

    blocTest<SharedVideoSaveCubit, SharedVideoSaveState>(
      'emits unavailable when resolve throws',
      build: () {
        when(
          () => videosRepository.fetchVideoWithStatsForRouteId(
            target.stableId,
            fallbackRouteIds: target.fallbackRouteIds,
          ),
        ).thenThrow(StateError('closed'));
        return createCubit();
      },
      act: (cubit) => cubit.save(target),
      expect: () => [
        const SharedVideoSaveState(status: SharedVideoSaveStatus.resolving),
        const SharedVideoSaveState(status: SharedVideoSaveStatus.unavailable),
      ],
    );

    test('drops a second save request while resolve is in flight', () async {
      final completer = Completer<VideoEvent?>();
      when(
        () => videosRepository.fetchVideoWithStatsForRouteId(
          target.stableId,
          fallbackRouteIds: target.fallbackRouteIds,
        ),
      ).thenAnswer((_) => completer.future);

      final cubit = createCubit();
      addTearDown(cubit.close);

      final first = cubit.save(target);
      final second = cubit.save(target);

      verify(
        () => videosRepository.fetchVideoWithStatsForRouteId(
          target.stableId,
          fallbackRouteIds: target.fallbackRouteIds,
        ),
      ).called(1);

      completer.complete(null);
      await Future.wait([first, second]);
      expect(cubit.state.status, SharedVideoSaveStatus.unavailable);
    });
  });
}
