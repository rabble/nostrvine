import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';

class _MockVineDraft extends Mock implements VineDraft {}

class _MockVideoPublishService extends Mock implements VideoPublishService {}

void main() {
  final defaultVieoPublishServiceFactory =
      ({required OnProgressChanged onProgress}) =>
          Future.value(_MockVideoPublishService());

  group('BackgroundPublishState', () {
    group('hasUploadInProgress', () {
      test('returns false when uploads list is empty', () {
        const state = BackgroundPublishState();
        expect(state.hasUploadInProgress, isFalse);
      });

      test('returns true when there is an upload with null result', () {
        final draft = _MockVineDraft();
        when(() => draft.id).thenReturn('1');

        final state = BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 0.5),
          ],
        );
        expect(state.hasUploadInProgress, isTrue);
      });

      test('returns false when all uploads have a result', () {
        final draft = _MockVineDraft();
        when(() => draft.id).thenReturn('1');

        final state = BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draft,
              result: const PublishError('error'),
              progress: 1.0,
            ),
          ],
        );
        expect(state.hasUploadInProgress, isFalse);
      });

      test('returns true when at least one upload has null result', () {
        final draft1 = _MockVineDraft();
        final draft2 = _MockVineDraft();
        when(() => draft1.id).thenReturn('1');
        when(() => draft2.id).thenReturn('2');

        final state = BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draft1,
              result: const PublishError('error'),
              progress: 1.0,
            ),
            BackgroundUpload(draft: draft2, result: null, progress: 0.3),
          ],
        );
        expect(state.hasUploadInProgress, isTrue);
      });
    });
  });

  group('BackgroundBlocUpload', () {
    test('can be instantiated', () {
      expect(
        BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
        ),
        isNotNull,
      );
    });

    group('BackgroundPublishRequested', () {
      final draft = _MockVineDraft();

      const draftId = '1';

      setUp(() {
        when(() => draft.id).thenReturn(draftId);
      });

      group('when the upload is a success', () {
        blocTest(
          'is removed from the uploads list',
          build: () => BackgroundPublishBloc(
            videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          ),
          act: (bloc) => bloc.add(
            BackgroundPublishRequested(
              draft: draft,
              publishmentProcess: Future.value(PublishSuccess()),
            ),
          ),
          expect: () => [
            BackgroundPublishState(
              uploads: [
                BackgroundUpload(draft: draft, result: null, progress: 0),
              ],
            ),
            BackgroundPublishState(uploads: []),
          ],
        );
      });

      group('when the upload is a failure', () {
        blocTest(
          'is kept on the uploads list',
          build: () => BackgroundPublishBloc(
            videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          ),
          act: (bloc) => bloc.add(
            BackgroundPublishRequested(
              draft: draft,
              publishmentProcess: Future.value(PublishError('ops')),
            ),
          ),
          expect: () => [
            BackgroundPublishState(
              uploads: [
                BackgroundUpload(draft: draft, result: null, progress: 0),
              ],
            ),
            BackgroundPublishState(
              uploads: [
                BackgroundUpload(
                  draft: draft,
                  result: PublishError('ops'),
                  progress: 1.0,
                ),
              ],
            ),
          ],
        );
      });

      group('when the draft is already uploading', () {
        blocTest(
          'does not add duplicate upload',
          build: () => BackgroundPublishBloc(
            videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          ),
          seed: () => BackgroundPublishState(
            uploads: [
              BackgroundUpload(draft: draft, result: null, progress: 0.5),
            ],
          ),
          act: (bloc) => bloc.add(
            BackgroundPublishRequested(
              draft: draft,
              publishmentProcess: Future.value(PublishSuccess()),
            ),
          ),
          expect: () => [
            // Only emits the final state after success, no duplicate added
            BackgroundPublishState(uploads: []),
          ],
        );
      });
    });

    group('BackgroundPublishProgressChanged', () {
      final draft = _MockVineDraft();

      const draftId = '1';

      setUp(() {
        when(() => draft.id).thenReturn(draftId);
      });

      blocTest(
        'updates the background upload',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
        ),
        seed: () => BackgroundPublishState(
          uploads: [BackgroundUpload(draft: draft, result: null, progress: 0)],
        ),
        act: (bloc) => bloc.add(
          BackgroundPublishProgressChanged(draftId: draftId, progress: .3),
        ),
        expect: () => [
          BackgroundPublishState(
            uploads: [
              BackgroundUpload(draft: draft, result: null, progress: .3),
            ],
          ),
        ],
      );
    });

    group('BackgroundPublishVanished', () {
      final draft = _MockVineDraft();

      const draftId = '1';

      setUp(() {
        when(() => draft.id).thenReturn(draftId);
      });
      blocTest(
        'removes the background upload',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
        ),
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 1.0),
          ],
        ),
        act: (bloc) => bloc.add(BackgroundPublishVanished(draftId: draftId)),
        expect: () => [BackgroundPublishState(uploads: [])],
      );
    });

    group('BackgroundPublishRetryRequested', () {
      late _MockVineDraft draft;
      late _MockVideoPublishService mockPublishService;

      const draftId = '1';

      setUp(() {
        draft = _MockVineDraft();
        mockPublishService = _MockVideoPublishService();
        when(() => draft.id).thenReturn(draftId);
      });

      blocTest<BackgroundPublishBloc, BackgroundPublishState>(
        'clears previous failed upload and retries',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory:
              ({required OnProgressChanged onProgress}) {
                return Future.value(mockPublishService);
              },
        ),
        setUp: () {
          when(
            () => mockPublishService.publishVideo(draft: draft),
          ).thenAnswer((_) => Future.value(const PublishSuccess()));
        },
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draft,
              result: const PublishError('Previous error'),
              progress: 1.0,
            ),
          ],
        ),
        act: (bloc) =>
            bloc.add(BackgroundPublishRetryRequested(draftId: draftId)),
        expect: () => [
          // First: old failed upload is cleared
          BackgroundPublishState(uploads: []),
          // Then: new upload is added (from BackgroundPublishRequested)
          BackgroundPublishState(
            uploads: [
              BackgroundUpload(draft: draft, result: null, progress: 0),
            ],
          ),
          // Finally: successful retry removes the upload
          BackgroundPublishState(uploads: []),
        ],
        verify: (_) {
          verify(() => mockPublishService.publishVideo(draft: draft)).called(1);
        },
      );
    });
  });
}
