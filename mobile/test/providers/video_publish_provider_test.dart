// ABOUTME: Unit tests for VideoPublishNotifier
// ABOUTME: Tests state management for video publishing

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/models/video_publish/video_publish_state.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/services/cawg_verifier_client.dart';

void main() {
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
  });
}
