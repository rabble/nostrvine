// ABOUTME: Tests for VideoCollaboratorStatusCubit.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_collaborator_status/video_collaborator_status_cubit.dart';

class _MockRepository extends Mock
    implements CollaboratorConfirmationRepository {}

const _videoAddress = '34236:abc:vine-1';
const _creatorPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _collaboratorPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  group(VideoCollaboratorStatusCubit, () {
    late _MockRepository repo;

    setUp(() {
      repo = _MockRepository();
      when(() => repo.release(any())).thenReturn(null);
    });

    blocTest<VideoCollaboratorStatusCubit, VideoCollaboratorStatusState>(
      'emits loading then ready with the repository snapshot',
      setUp: () {
        when(
          () => repo.watch(
            _videoAddress,
            creatorPubkey: _creatorPubkey,
            taggedPubkeys: any(named: 'taggedPubkeys'),
          ),
        ).thenAnswer(
          (_) => Stream<VideoCollaboratorStatus>.value(
            const VideoCollaboratorStatus(
              videoAddress: _videoAddress,
              statusByPubkey: {
                _collaboratorPubkey: CollaboratorStatus.confirmed,
              },
            ),
          ),
        );
      },
      build: () => VideoCollaboratorStatusCubit(
        repository: repo,
        videoAddress: _videoAddress,
        creatorPubkey: _creatorPubkey,
        taggedPubkeys: const [_collaboratorPubkey],
      ),
      expect: () => const [
        VideoCollaboratorStatusState(
          load: VideoCollaboratorStatusLoad.ready,
          statusByPubkey: {_collaboratorPubkey: CollaboratorStatus.confirmed},
        ),
      ],
    );

    blocTest<VideoCollaboratorStatusCubit, VideoCollaboratorStatusState>(
      'emits failure and reports error when the stream errors',
      setUp: () {
        when(
          () => repo.watch(
            _videoAddress,
            creatorPubkey: _creatorPubkey,
            taggedPubkeys: any(named: 'taggedPubkeys'),
          ),
        ).thenAnswer(
          (_) => Stream<VideoCollaboratorStatus>.error(
            StateError('relay unavailable'),
          ),
        );
      },
      build: () => VideoCollaboratorStatusCubit(
        repository: repo,
        videoAddress: _videoAddress,
        creatorPubkey: _creatorPubkey,
        taggedPubkeys: const [_collaboratorPubkey],
      ),
      expect: () => const [
        VideoCollaboratorStatusState(
          load: VideoCollaboratorStatusLoad.failure,
        ),
      ],
      errors: () => [isA<StateError>()],
    );

    test('release is called on close', () async {
      when(
        () => repo.watch(
          _videoAddress,
          creatorPubkey: _creatorPubkey,
          taggedPubkeys: any(named: 'taggedPubkeys'),
        ),
      ).thenAnswer(
        (_) => StreamController<VideoCollaboratorStatus>.broadcast().stream,
      );

      final cubit = VideoCollaboratorStatusCubit(
        repository: repo,
        videoAddress: _videoAddress,
        creatorPubkey: _creatorPubkey,
        taggedPubkeys: const [_collaboratorPubkey],
      );

      await cubit.close();

      verify(() => repo.release(_videoAddress)).called(1);
    });
  });
}
