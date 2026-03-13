// ABOUTME: Unit tests for VideoEditorProviderState model validating state
// ABOUTME: management, copyWith behavior, and computed properties

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_metadata/video_metadata_expiration.dart';

void main() {
  group(VideoEditorProviderState, () {
    test('creates instance with default values', () {
      final state = VideoEditorProviderState();

      expect(state.isMuted, isFalse);
      expect(state.isProcessing, isFalse);
      expect(state.isSavingDraft, isFalse);
      expect(state.allowAudioReuse, isFalse);
      expect(state.title, isEmpty);
      expect(state.description, isEmpty);
      expect(state.tags, isEmpty);
      expect(state.expiration, equals(VideoMetadataExpiration.notExpire));
      expect(state.metadataLimitReached, isFalse);
      expect(state.finalRenderedClip, isNull);
      expect(state.editorStateHistory, isEmpty);
      expect(state.editorEditingParameters, isNull);
      expect(state.collaboratorPubkeys, isEmpty);
      expect(state.inspiredByVideo, isNull);
      expect(state.inspiredByNpub, isNull);
      expect(state.selectedSound, isNull);
      expect(state.contentWarnings, isEmpty);
      expect(state.proofManifestJson, isNull);
      expect(state.deleteButtonKey, isA<GlobalKey>());
    });

    test('copyWith updates specified fields only', () {
      final initial = VideoEditorProviderState(
        isMuted: true,
        title: 'Original Title',
      );

      final updated = initial.copyWith(
        isProcessing: true,
        description: 'New description',
      );

      expect(updated.isMuted, isTrue);
      expect(updated.title, equals('Original Title'));
      expect(updated.isProcessing, isTrue);
      expect(updated.description, equals('New description'));
      expect(updated.isSavingDraft, isFalse);
    });

    test('copyWith preserves all fields when none specified', () {
      final state = VideoEditorProviderState(
        isMuted: true,
        isProcessing: true,
        isSavingDraft: true,
        allowAudioReuse: true,
        title: 'Test Title',
        description: 'Test Description',
        tags: const {'tag1', 'tag2'},
        metadataLimitReached: true,
        collaboratorPubkeys: const {'pubkey1'},
        contentWarnings: const {ContentLabel.nudity},
      );

      final copied = state.copyWith();

      expect(copied.isMuted, state.isMuted);
      expect(copied.isProcessing, state.isProcessing);
      expect(copied.isSavingDraft, state.isSavingDraft);
      expect(copied.allowAudioReuse, state.allowAudioReuse);
      expect(copied.title, state.title);
      expect(copied.description, state.description);
      expect(copied.tags, state.tags);
      expect(copied.metadataLimitReached, state.metadataLimitReached);
      expect(copied.collaboratorPubkeys, state.collaboratorPubkeys);
      expect(copied.contentWarnings, state.contentWarnings);
    });

    group('isValidToPost', () {
      test('returns false when isProcessing is true', () {
        final state = VideoEditorProviderState(isProcessing: true);

        expect(state.isValidToPost, isFalse);
      });

      test('returns false when finalRenderedClip is null', () {
        final state = VideoEditorProviderState();

        expect(state.isValidToPost, isFalse);
      });

      test('returns false when metadataLimitReached is true', () {
        final state = VideoEditorProviderState(metadataLimitReached: true);

        expect(state.isValidToPost, isFalse);
      });
    });

    test('copyWith with clearFinalRenderedClip sets clip to null', () {
      final state = VideoEditorProviderState();

      final cleared = state.copyWith(clearFinalRenderedClip: true);

      expect(cleared.finalRenderedClip, isNull);
    });

    test('copyWith with clearInspiredByNpub sets npub to null', () {
      final state = VideoEditorProviderState(inspiredByNpub: 'npub123');

      final cleared = state.copyWith(clearInspiredByNpub: true);

      expect(cleared.inspiredByNpub, isNull);
    });

    test('copyWith with clearSelectedSound sets sound to null', () {
      final state = VideoEditorProviderState();

      final cleared = state.copyWith(clearSelectedSound: true);

      expect(cleared.selectedSound, isNull);
    });
  });
}
