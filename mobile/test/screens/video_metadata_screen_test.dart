// ABOUTME: Tests for VideoMetadataScreen basic rendering and structure
// ABOUTME: Verifies screen renders with expected UI elements

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

RecordingClip _createTestClip({String id = 'test-clip'}) {
  return RecordingClip(
    id: id,
    video: EditorVideo.file('test.mp4'),
    duration: const Duration(seconds: 10),
    recordedAt: DateTime.now(),
    targetAspectRatio: models.AspectRatio.square,
    originalAspectRatio: 9 / 16,
  );
}

void main() {
  group(VideoMetadataScreen, () {
    late RecordingClip testClip;

    setUp(() {
      testClip = _createTestClip();
    });

    group('initState', () {
      testWidgets('clears stale publish error state on screen init', (
        tester,
      ) async {
        final container = ProviderContainer(
          overrides: [
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
            videoPublishProvider.overrideWith(
              () => _MockVideoPublishNotifier(
                const VideoPublishProviderState(
                  publishState: VideoPublishState.error,
                  errorMessage: 'Previous error',
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: VideoMetadataScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final state = container.read(videoPublishProvider);
        expect(state.publishState, VideoPublishState.idle);
        expect(state.errorMessage, isNull);
      });
    });

    group('renders', () {
      testWidgets('renders $VideoMetadataScreen with basic structure', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              clipManagerProvider.overrideWith(
                () => _MockClipManagerNotifier([testClip]),
              ),
            ],
            child: const MaterialApp(home: VideoMetadataScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Post details'), findsOneWidget);
        expect(find.text('Post'), findsOneWidget);
      });
    });
  });
}

/// Mock clip manager notifier for testing.
class _MockClipManagerNotifier extends ClipManagerNotifier {
  _MockClipManagerNotifier(this._clips);

  final List<RecordingClip> _clips;

  @override
  ClipManagerState build() => ClipManagerState(clips: _clips);
}

/// Mock publish notifier that starts with a given state.
class _MockVideoPublishNotifier extends VideoPublishNotifier {
  _MockVideoPublishNotifier(this._initialState);

  final VideoPublishProviderState _initialState;

  @override
  VideoPublishProviderState build() => _initialState;
}
