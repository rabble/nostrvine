import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/blocs/background_publish/publish_foreground_session.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/video_publish/publish_error_kind.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';

class _MockVineDraft extends Mock implements DivineVideoDraft {}

class _MockVideoPublishService extends Mock implements VideoPublishService {}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

/// Records begin/end calls; optionally throws to prove the session is
/// best-effort and never breaks the publish.
class _FakeForegroundSession implements PublishForegroundSession {
  _FakeForegroundSession({this.throws = false});

  final bool throws;
  final List<String> beginCalls = [];
  final List<String> endCalls = [];

  @override
  Future<void> begin(String sessionId) async {
    beginCalls.add(sessionId);
    if (throws) throw Exception('begin failed');
  }

  @override
  Future<void> end(String sessionId) async {
    endCalls.add(sessionId);
    if (throws) throw Exception('end failed');
  }
}

void main() {
  late _MockDraftStorageService mockDraftStorageService;

  Future<_MockVideoPublishService> defaultVieoPublishServiceFactory({
    required OnProgressChanged onProgress,
  }) => Future.value(_MockVideoPublishService());

  setUpAll(() {
    registerFallbackValue(PublishStatus.draft);
  });

  setUp(() {
    mockDraftStorageService = _MockDraftStorageService();
    when(
      () => mockDraftStorageService.updatePublishStatus(
        draftId: any(named: 'draftId'),
        status: any(named: 'status'),
        publishError: any(named: 'publishError'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockDraftStorageService.deleteDraft(any()),
    ).thenAnswer((_) async {});
  });

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
              result: const PublishError(PublishErrorKind.generic),
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
              result: const PublishError(PublishErrorKind.generic),
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
          draftStorageService: mockDraftStorageService,
        ),
        isNotNull,
      );
    });

    group('BackgroundPublishRequested', () {
      final draft = _MockVineDraft();

      const draftId = '1';

      setUp(() {
        when(() => draft.id).thenReturn(draftId);
        when(() => draft.sourceDraftId).thenReturn(null);
      });

      group('when the upload is a success', () {
        blocTest(
          'is removed from the uploads list',
          build: () => BackgroundPublishBloc(
            videoPublishServiceFactory: defaultVieoPublishServiceFactory,
            draftStorageService: mockDraftStorageService,
          ),
          act: (bloc) => bloc.add(
            BackgroundPublishRequested(
              draft: draft,
              publishmentProcess: Future.value(const PublishSuccess()),
            ),
          ),
          expect: () => [
            BackgroundPublishState(
              uploads: [
                BackgroundUpload(draft: draft, result: null, progress: 0),
              ],
            ),
            // Success: upload removed and recentlySucceededIds populated.
            const BackgroundPublishState(recentlySucceededIds: {draftId}),
          ],
          verify: (_) {
            verify(
              () => mockDraftStorageService.deleteDraft(draftId),
            ).called(1);
          },
        );
      });

      group('when the upload is a failure', () {
        blocTest(
          'is kept on the uploads list and persists failed status',
          build: () => BackgroundPublishBloc(
            videoPublishServiceFactory: defaultVieoPublishServiceFactory,
            draftStorageService: mockDraftStorageService,
          ),
          act: (bloc) => bloc.add(
            BackgroundPublishRequested(
              draft: draft,
              publishmentProcess: Future.value(
                const PublishError(PublishErrorKind.generic),
              ),
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
                  result: const PublishError(PublishErrorKind.generic),
                  progress: 1.0,
                ),
              ],
            ),
          ],
          verify: (_) {
            verify(
              () => mockDraftStorageService.updatePublishStatus(
                draftId: draftId,
                status: PublishStatus.failed,
                publishError: 'pek1:generic',
              ),
            ).called(1);
          },
        );
      });

      group('when a transient publish copy succeeds', () {
        final publishDraft = _MockVineDraft();

        const publishDraftId = 'draft_publish_1';
        const sourceDraftId = 'draft_1';

        setUp(() {
          when(() => publishDraft.id).thenReturn(publishDraftId);
          when(() => publishDraft.sourceDraftId).thenReturn(sourceDraftId);
        });

        blocTest(
          'deletes the publish copy and the source draft',
          build: () => BackgroundPublishBloc(
            videoPublishServiceFactory: defaultVieoPublishServiceFactory,
            draftStorageService: mockDraftStorageService,
          ),
          act: (bloc) => bloc.add(
            BackgroundPublishRequested(
              draft: publishDraft,
              publishmentProcess: Future.value(const PublishSuccess()),
            ),
          ),
          expect: () => [
            BackgroundPublishState(
              uploads: [
                BackgroundUpload(
                  draft: publishDraft,
                  result: null,
                  progress: 0,
                ),
              ],
            ),
            const BackgroundPublishState(
              recentlySucceededIds: {publishDraftId},
            ),
          ],
          verify: (_) {
            verify(
              () => mockDraftStorageService.deleteDraft(publishDraftId),
            ).called(1);
            verify(
              () => mockDraftStorageService.deleteDraft(sourceDraftId),
            ).called(1);
          },
        );
      });

      group('when the publish process throws an exception', () {
        blocTest<BackgroundPublishBloc, BackgroundPublishState>(
          'transitions the upload to error state',
          build: () => BackgroundPublishBloc(
            videoPublishServiceFactory: defaultVieoPublishServiceFactory,
            draftStorageService: mockDraftStorageService,
          ),
          act: (bloc) => bloc.add(
            BackgroundPublishRequested(
              draft: draft,
              publishmentProcess: Future<PublishResult>.delayed(
                Duration.zero,
                () => throw Exception('Network connection lost'),
              ),
            ),
          ),
          errors: () => [isA<Exception>()],
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
                  result: const PublishError(PublishErrorKind.generic),
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
            draftStorageService: mockDraftStorageService,
          ),
          seed: () => BackgroundPublishState(
            uploads: [
              BackgroundUpload(draft: draft, result: null, progress: 0.5),
            ],
          ),
          act: (bloc) => bloc.add(
            BackgroundPublishRequested(
              draft: draft,
              publishmentProcess: Future.value(const PublishSuccess()),
            ),
          ),
          expect: () => [
            // Only emits the final state after success, no duplicate added.
            // recentlySucceededIds is populated so UploadFailureListener can
            // distinguish a true success from BackgroundPublishVanished.
            const BackgroundPublishState(recentlySucceededIds: {draftId}),
          ],
        );
      });
    });

    group('BackgroundPublishProgressChanged', () {
      final draft = _MockVineDraft();

      const draftId = '1';

      setUp(() {
        when(() => draft.id).thenReturn(draftId);
        when(() => draft.sourceDraftId).thenReturn(null);
      });

      blocTest(
        'updates the background upload',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
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

      blocTest(
        'ignores progress when it is less than current progress',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 0.5),
          ],
        ),
        act: (bloc) => bloc.add(
          BackgroundPublishProgressChanged(draftId: draftId, progress: .3),
        ),
        expect: () => <BackgroundPublishState>[],
      );

      blocTest(
        'ignores progress when it is equal to the current progress',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 0.5),
          ],
        ),
        act: (bloc) => bloc.add(
          BackgroundPublishProgressChanged(draftId: draftId, progress: .5),
        ),
        expect: () => <BackgroundPublishState>[],
      );

      blocTest(
        'ignores progress when the upload already has a result',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draft,
              result: const PublishError(PublishErrorKind.generic),
              progress: 1.0,
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          BackgroundPublishProgressChanged(draftId: draftId, progress: .5),
        ),
        expect: () => <BackgroundPublishState>[],
      );

      blocTest(
        'ignores progress when the draft is not found',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        seed: () => const BackgroundPublishState(),
        act: (bloc) => bloc.add(
          BackgroundPublishProgressChanged(
            draftId: 'non-existent',
            progress: .5,
          ),
        ),
        expect: () => <BackgroundPublishState>[],
      );
    });

    group('BackgroundPublishVanished', () {
      late _MockVineDraft draft;

      const draftId = '1';

      setUp(() {
        draft = _MockVineDraft();
        when(() => draft.id).thenReturn(draftId);
        when(() => draft.sourceDraftId).thenReturn(null);
      });
      blocTest(
        'removes the background upload and resets status to draft',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 1.0),
          ],
        ),
        act: (bloc) => bloc.add(BackgroundPublishVanished(draftId: draftId)),
        expect: () => [const BackgroundPublishState()],
        verify: (_) {
          verify(
            () => mockDraftStorageService.updatePublishStatus(
              draftId: draftId,
              status: PublishStatus.draft,
            ),
          ).called(1);
        },
      );

      blocTest(
        'does NOT populate recentlySucceededIds — '
        'regression: vanished upload must not trigger a success snackbar',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 1.0),
          ],
        ),
        act: (bloc) => bloc.add(BackgroundPublishVanished(draftId: draftId)),
        verify: (bloc) {
          // recentlySucceededIds must be empty — Vanished is not a publish
          // success and must never trigger a success snackbar.
          expect(bloc.state.recentlySucceededIds, isEmpty);
        },
      );

      blocTest(
        'deletes a transient publish copy instead of mutating the source draft',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        setUp: () {
          when(() => draft.sourceDraftId).thenReturn('draft_source');
        },
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(draft: draft, result: null, progress: 1.0),
          ],
        ),
        act: (bloc) => bloc.add(BackgroundPublishVanished(draftId: draftId)),
        expect: () => [const BackgroundPublishState()],
        verify: (_) {
          verify(() => mockDraftStorageService.deleteDraft(draftId)).called(1);
          verifyNever(
            () => mockDraftStorageService.updatePublishStatus(
              draftId: any(named: 'draftId'),
              status: any(named: 'status'),
              publishError: any(named: 'publishError'),
            ),
          );
        },
      );
    });

    group('BackgroundPublishFailed', () {
      final draft = _MockVineDraft();

      const draftId = '1';

      setUp(() {
        when(() => draft.id).thenReturn(draftId);
      });

      blocTest<BackgroundPublishBloc, BackgroundPublishState>(
        'adds interrupted upload to state with error result',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        act: (bloc) => bloc.add(
          BackgroundPublishFailed(
            draft: draft,
            error: const PublishError(PublishErrorKind.interrupted),
          ),
        ),
        expect: () => [
          BackgroundPublishState(
            uploads: [
              BackgroundUpload(
                draft: draft,
                result: const PublishError(PublishErrorKind.interrupted),
                progress: 0,
              ),
            ],
          ),
        ],
      );

      blocTest<BackgroundPublishBloc, BackgroundPublishState>(
        'does not duplicate when the same draft is already tracked',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
        ),
        seed: () => BackgroundPublishState(
          uploads: [
            BackgroundUpload(
              draft: draft,
              result: const PublishError(PublishErrorKind.generic),
              progress: 1.0,
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          BackgroundPublishFailed(
            draft: draft,
            error: const PublishError(PublishErrorKind.interrupted),
          ),
        ),
        expect: () => <BackgroundPublishState>[],
      );
    });

    group('foreground session', () {
      late _MockVineDraft draft;
      late _FakeForegroundSession session;

      const draftId = '1';

      setUp(() {
        draft = _MockVineDraft();
        session = _FakeForegroundSession();
        when(() => draft.id).thenReturn(draftId);
        when(() => draft.sourceDraftId).thenReturn(null);
      });

      blocTest<BackgroundPublishBloc, BackgroundPublishState>(
        'begins and ends the session around a successful publish',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
          foregroundSession: session,
        ),
        act: (bloc) => bloc.add(
          BackgroundPublishRequested(
            draft: draft,
            publishmentProcess: Future.value(const PublishSuccess()),
          ),
        ),
        verify: (_) {
          expect(session.beginCalls, [draftId]);
          expect(session.endCalls, [draftId]);
        },
      );

      blocTest<BackgroundPublishBloc, BackgroundPublishState>(
        'ends the session even when the publish fails',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
          foregroundSession: session,
        ),
        act: (bloc) => bloc.add(
          BackgroundPublishRequested(
            draft: draft,
            publishmentProcess: Future.value(
              const PublishError(PublishErrorKind.generic),
            ),
          ),
        ),
        verify: (_) {
          expect(session.beginCalls, [draftId]);
          expect(session.endCalls, [draftId]);
        },
      );

      blocTest<BackgroundPublishBloc, BackgroundPublishState>(
        'a session failure does not abort the publish',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory: defaultVieoPublishServiceFactory,
          draftStorageService: mockDraftStorageService,
          foregroundSession: _FakeForegroundSession(throws: true),
        ),
        act: (bloc) => bloc.add(
          BackgroundPublishRequested(
            draft: draft,
            publishmentProcess: Future.value(const PublishSuccess()),
          ),
        ),
        expect: () => [
          BackgroundPublishState(
            uploads: [
              BackgroundUpload(draft: draft, result: null, progress: 0),
            ],
          ),
          const BackgroundPublishState(recentlySucceededIds: {draftId}),
        ],
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
        when(() => draft.sourceDraftId).thenReturn(null);
      });

      blocTest<BackgroundPublishBloc, BackgroundPublishState>(
        'clears previous failed upload and retries',
        build: () => BackgroundPublishBloc(
          videoPublishServiceFactory:
              ({required OnProgressChanged onProgress}) {
                return Future.value(mockPublishService);
              },
          draftStorageService: mockDraftStorageService,
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
              result: const PublishError(PublishErrorKind.generic),
              progress: 1.0,
            ),
          ],
        ),
        act: (bloc) =>
            bloc.add(BackgroundPublishRetryRequested(draftId: draftId)),
        expect: () => [
          // First: old failed upload is cleared
          const BackgroundPublishState(),
          // Then: new upload is added (from BackgroundPublishRequested)
          BackgroundPublishState(
            uploads: [
              BackgroundUpload(draft: draft, result: null, progress: 0),
            ],
          ),
          // Finally: successful retry removes the upload, recentlySucceededIds
          // is populated so UploadFailureListener shows a success snackbar.
          const BackgroundPublishState(recentlySucceededIds: {draftId}),
        ],
        verify: (_) {
          verify(() => mockPublishService.publishVideo(draft: draft)).called(1);
        },
      );
    });
  });
}
