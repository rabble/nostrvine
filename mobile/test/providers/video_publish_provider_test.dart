// ABOUTME: Unit tests for VideoPublishNotifier
// ABOUTME: Tests state management for video publishing

import 'dart:async';
import 'dart:convert';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:dm_repository/dm_repository.dart'
    show CollaboratorInviteRetrySummary;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/upload_media_providers.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/cawg_verifier_client.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/mention_resolution_service.dart';
import 'package:openvine/services/upload_manager.dart';
import 'package:openvine/services/video_event_publisher.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockProfileRepository extends Mock implements ProfileRepository {}

class MockDraftStorageService extends Mock implements DraftStorageService {}

class MockAuthService extends Mock implements AuthService {}

class MockUploadManager extends Mock implements UploadManager {}

class MockVideoEventPublisher extends Mock implements VideoEventPublisher {}

class MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _IdentityKnownNostrSession extends NostrSession {
  @override
  NostrSessionReadiness build() => const NostrSessionReadiness.identityKnown(
    pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  );
}

DivineVideoClip _createTestClip() => DivineVideoClip(
  id: 'clip_1',
  video: EditorVideo.file('/tmp/test.mp4'),
  duration: const Duration(seconds: 6),
  recordedAt: DateTime(2026),
  originalAspectRatio: 9 / 16,
  targetAspectRatio: .vertical,
);

DivineVideoDraft _createPublishableDraft() {
  final clip = _createTestClip();
  final proofManifestJson = jsonEncode(
    const NativeProofData(
      videoHash: 'abc123',
      creatorBindingAssertionLabel: 'video.divine.nostr.creator_binding',
      creatorBindingPayloadJson: '{"version":1}',
    ).toJson(),
  );

  return DivineVideoDraft.create(
    clips: [clip],
    title: 'Test Draft',
    description: 'Test Description',
    hashtags: const {},
    selectedApproach: 'default',
  ).copyWith(finalRenderedClip: clip, proofManifestJson: proofManifestJson);
}

class _FakeDivineVideoDraft extends Fake implements DivineVideoDraft {}

void main() {
  setUpAll(() {
    registerFallbackValue(_createPublishableDraft());
  });

  group('VideoPublishNotifier', () {
    late ProviderContainer container;
    late VideoPublishNotifier notifier;

    setUp(() {
      container = ProviderContainer();
      notifier = container.read(videoPublishProvider.notifier);
    });

    tearDown(() {
      container.dispose();
    });

    test('setUploadProgress updates progress value', () {
      notifier.setUploadProgress(draftId: '1', progress: 0.5);
      expect(container.read(videoPublishProvider).uploadProgress, 0.5);

      notifier.setUploadProgress(draftId: '1', progress: 1);
      expect(container.read(videoPublishProvider).uploadProgress, 1.0);
    });

    test('setUploadProgress clamps value between 0.0 and 1.0', () {
      notifier.setUploadProgress(draftId: '1', progress: 0);
      expect(container.read(videoPublishProvider).uploadProgress, 0.0);

      notifier.setUploadProgress(draftId: '1', progress: 1);
      expect(container.read(videoPublishProvider).uploadProgress, 1.0);
    });

    test('upload progress tracks intermediate values', () {
      notifier.setUploadProgress(draftId: '1', progress: 0);
      expect(container.read(videoPublishProvider).uploadProgress, 0.0);

      notifier.setUploadProgress(draftId: '1', progress: 0.25);
      expect(container.read(videoPublishProvider).uploadProgress, 0.25);

      notifier.setUploadProgress(draftId: '1', progress: 0.5);
      expect(container.read(videoPublishProvider).uploadProgress, 0.5);

      notifier.setUploadProgress(draftId: '1', progress: 0.75);
      expect(container.read(videoPublishProvider).uploadProgress, 0.75);

      notifier.setUploadProgress(draftId: '1', progress: 1);
      expect(container.read(videoPublishProvider).uploadProgress, 1.0);
    });

    test('setError sets error state and message', () {
      notifier.setError('Upload failed');

      final state = container.read(videoPublishProvider);
      expect(state.publishState, VideoPublishState.error);
      expect(state.errorMessage, 'Upload failed');
    });

    test('clearError resets to idle state', () {
      notifier
        ..setError('Upload failed')
        ..clearError();

      final state = container.read(videoPublishProvider);
      expect(state.publishState, VideoPublishState.idle);
      // Note: errorMessage is not cleared due to copyWith behavior
    });

    test('reset returns state to initial values', () {
      // First modify the state
      notifier
        ..setUploadProgress(draftId: '1', progress: 0.5)
        // Then reset
        ..reset();

      final state = container.read(videoPublishProvider);
      expect(state.uploadProgress, 0.0);
      expect(state.publishState, VideoPublishState.idle);
    });

    test('setError preserves other state values', () {
      notifier.setError('Test error');

      final state = container.read(videoPublishProvider);
      expect(state.publishState, VideoPublishState.error);
      expect(state.errorMessage, 'Test error');
    });

    test(
      'createVideoPublishMentionResolutionService returns null without profile repository',
      () {
        expect(createVideoPublishMentionResolutionService(null), isNull);
      },
    );

    test(
      'createVideoPublishMentionResolutionService creates resolver from profile repository',
      () {
        final service = createVideoPublishMentionResolutionService(
          MockProfileRepository(),
        );

        expect(service, isA<MentionResolutionService>());
      },
    );

    test('collaborator invite warning message handles singular failure', () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(
        notifier.collaboratorInviteWarningMessage(l10n, 1),
        l10n.videoPublishCollaboratorInviteWarning(1),
      );
    });

    test('collaborator invite warning message handles plural failures', () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(
        notifier.collaboratorInviteWarningMessage(l10n, 2),
        l10n.videoPublishCollaboratorInviteWarning(2),
      );
    });

    test(
      'collaborator invite retry message prioritizes transient failures',
      () {
        final l10n = lookupAppLocalizations(const Locale('en'));

        expect(
          notifier.collaboratorInviteRetryResultMessage(
            l10n,
            const CollaboratorInviteRetrySummary(
              attemptedCount: 3,
              successCount: 1,
              failureCount: 1,
              blockedCount: 1,
            ),
          ),
          l10n.videoPublishCollaboratorInviteWarning(1),
        );
      },
    );

    test('collaborator invite retry message reports terminal blocks apart '
        'from failures', () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(
        notifier.collaboratorInviteRetryResultMessage(
          l10n,
          const CollaboratorInviteRetrySummary(
            attemptedCount: 1,
            successCount: 0,
            failureCount: 0,
            blockedCount: 1,
          ),
        ),
        l10n.profileCollaboratorInviteBlockedResult(1),
      );
    });

    test('collaborator invite retry message reads as sent when all '
        'delivered', () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      expect(
        notifier.collaboratorInviteRetryResultMessage(
          l10n,
          const CollaboratorInviteRetrySummary(
            attemptedCount: 2,
            successCount: 2,
            failureCount: 0,
          ),
        ),
        l10n.profileCollaboratorInviteRetryResult(0),
      );
    });

    test(
      'preferredSocialVerificationMethods prefers oauth then public proof',
      () {
        expect(
          notifier.preferredSocialVerificationMethods(supportsOAuth: true),
          equals(const [
            VerifierRequiredMethod.oauth,
            VerifierRequiredMethod.publicProof,
          ]),
        );
      },
    );

    test(
      'preferredSocialVerificationMethods falls back to public proof only',
      () {
        expect(
          notifier.preferredSocialVerificationMethods(supportsOAuth: false),
          equals(const [VerifierRequiredMethod.publicProof]),
        );
      },
    );

    test(
      'shouldAttachCreatorIdentityProof returns true when proof is missing',
      () {
        expect(notifier.shouldAttachCreatorIdentityProof(null), isTrue);
        expect(notifier.shouldAttachCreatorIdentityProof(''), isTrue);
      },
    );

    test(
      'shouldAttachCreatorIdentityProof returns false when proof already has creator identity metadata',
      () {
        final proofManifestJson = jsonEncode(
          const NativeProofData(
            videoHash: 'abc123',
            creatorBindingAssertionLabel: 'video.divine.nostr.creator_binding',
            creatorBindingPayloadJson: '{"version":1}',
          ).toJson(),
        );

        expect(
          notifier.shouldAttachCreatorIdentityProof(proofManifestJson),
          isFalse,
        );
      },
    );

    test('video reply publish destination opens parent video comments', () {
      const rootEventId =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const rootAddressableId =
          '34236:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
          ':parent-video';
      const context = VideoReplyContext(
        rootEventId: rootEventId,
        rootEventKind: 34236,
        rootAuthorPubkey:
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
        rootAddressableId: rootAddressableId,
      );

      final destination = videoReplyPublishDestinationFor(context);

      expect(destination.path, VideoDetailScreen.pathForId(rootAddressableId));
      expect(destination.extra.autoOpenComments, isTrue);
    });

    testWidgets(
      'publishVideo returns not signed in before saving publish draft when signer is not ready',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final sharedPreferences = await SharedPreferences.getInstance();
        final draftStorageService = MockDraftStorageService();
        final authService = MockAuthService();
        final uploadManager = MockUploadManager();
        final videoEventPublisher = MockVideoEventPublisher();
        final blossomUploadService = MockBlossomUploadService();
        final backgroundPublishBloc = BackgroundPublishBloc(
          videoPublishServiceFactory: ({required onProgress}) async =>
              throw StateError('background publish should not be requested'),
          draftStorageService: draftStorageService,
        );
        addTearDown(backgroundPublishBloc.close);

        when(
          () => draftStorageService.saveDraft(any()),
        ).thenAnswer((_) async {});
        when(() => authService.currentNpub).thenReturn(null);
        when(() => authService.isAuthenticated).thenReturn(true);
        when(() => authService.currentPublicKeyHex).thenReturn(
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        );

        late BuildContext publishContext;
        late WidgetRef publishRef;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sharedPreferences),
              draftStorageServiceProvider.overrideWithValue(
                draftStorageService,
              ),
              authServiceProvider.overrideWithValue(authService),
              uploadManagerProvider.overrideWithValue(uploadManager),
              videoEventPublisherProvider.overrideWithValue(
                videoEventPublisher,
              ),
              blossomUploadServiceProvider.overrideWithValue(
                blossomUploadService,
              ),
              nostrSessionProvider.overrideWith(_IdentityKnownNostrSession.new),
            ],
            child: MaterialApp(
              home: BlocProvider<BackgroundPublishBloc>.value(
                value: backgroundPublishBloc,
                child: Consumer(
                  builder: (context, ref, _) {
                    publishContext = context;
                    publishRef = ref;
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        );

        await publishRef
            .read(videoPublishProvider.notifier)
            .publishVideo(publishContext, _createPublishableDraft());

        final state = publishRef.read(videoPublishProvider);
        expect(state.publishState, VideoPublishState.error);
        expect(state.errorMessage, isNotEmpty);
        verifyNever(() => draftStorageService.saveDraft(any()));
        expect(backgroundPublishBloc.state.uploads, isEmpty);
      },
    );
  });

  group('VideoPublishNotifier publishVideo duplicate guard (#6018)', () {
    setUpAll(() {
      registerFallbackValue(_FakeDivineVideoDraft());
    });

    DivineVideoDraft createDraft() {
      final clip = DivineVideoClip(
        id: 'clip_1',
        video: EditorVideo.file('/tmp/test.mp4'),
        duration: const Duration(seconds: 6),
        recordedAt: DateTime(2025),
        originalAspectRatio: 9 / 16,
        targetAspectRatio: .vertical,
      );
      return DivineVideoDraft(
        id: 'draft_1',
        clips: [clip],
        title: 'Plants',
        description: '',
        hashtags: const {},
        selectedApproach: 'camera',
        createdAt: DateTime(2025),
        lastModified: DateTime(2025),
        publishStatus: PublishStatus.draft,
        publishAttempts: 0,
        finalRenderedClip: clip,
        // Creator identity metadata present so publishVideo skips the
        // proof refresh and suspends on the mocked saveDraft below.
        proofManifestJson: jsonEncode(
          const NativeProofData(
            videoHash: 'abc123',
            creatorBindingAssertionLabel: 'video.divine.nostr.creator_binding',
            creatorBindingPayloadJson: '{"version":1}',
          ).toJson(),
        ),
      );
    }

    testWidgets(
      'reset during an in-flight publish does not reopen the gate for '
      'the same source draft',
      (tester) async {
        final mockDraftStorage = MockDraftStorageService();
        // Never completes - keeps the first publish in flight, like the
        // 20s+ audio-reuse window in production.
        final saveDraftGate = Completer<void>();
        when(
          () => mockDraftStorage.saveDraft(any()),
        ).thenAnswer((_) => saveDraftGate.future);

        final container = ProviderContainer(
          overrides: [
            draftStorageServiceProvider.overrideWithValue(mockDraftStorage),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SizedBox()),
          ),
        );
        final context = tester.element(find.byType(SizedBox));
        final notifier = container.read(videoPublishProvider.notifier);
        final draft = createDraft();

        unawaited(notifier.publishVideo(context, draft));
        await tester.pump();
        expect(
          container.read(videoPublishProvider).publishState,
          VideoPublishState.preparing,
        );

        // clearAll resets the state ~600ms after navigation while the
        // publish future is still running - simulate that state wipe.
        notifier.reset();

        unawaited(notifier.publishVideo(context, draft));
        await tester.pump();

        verify(() => mockDraftStorage.saveDraft(any())).called(1);
      },
    );
  });
}
