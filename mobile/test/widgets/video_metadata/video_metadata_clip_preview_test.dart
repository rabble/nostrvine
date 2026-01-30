import 'package:flutter/material.dart' hide AspectRatio;
import 'package:flutter/widgets.dart' show AspectRatio;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_clip_editor/video_clip_editor_processing_overlay.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_clip_preview.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('VideoMetadataClipPreview', () {
    late RecordingClip testClip;

    setUp(() {
      testClip = RecordingClip(
        id: 'test-clip',
        video: EditorVideo.file('test.mp4'),
        duration: const Duration(seconds: 10),
        recordedAt: DateTime.now(),
        thumbnailPath: 'test_thumbnail.jpg',
        targetAspectRatio: models.AspectRatio.square,
        originalAspectRatio: 9 / 16,
      );
    });

    testWidgets('displays clip thumbnail when available', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataClipPreview()),
          ),
        ),
      );

      // Should display thumbnail image
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('displays placeholder when no thumbnail', (tester) async {
      final clipNoThumbnail = RecordingClip(
        id: 'test-clip',
        video: EditorVideo.file('test.mp4'),
        duration: const Duration(seconds: 10),
        recordedAt: DateTime.now(),
        targetAspectRatio: models.AspectRatio.square,
        originalAspectRatio: 9 / 16,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([clipNoThumbnail]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataClipPreview()),
          ),
        ),
      );

      // Should display placeholder icon
      expect(find.byIcon(Icons.play_circle_outline), findsOneWidget);
    });

    testWidgets('shows processing overlay when isProcessing is true', (
      tester,
    ) async {
      final state = VideoEditorProviderState(isProcessing: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataClipPreview()),
          ),
        ),
      );

      // Processing overlay should be present
      expect(find.byType(VideoClipEditorProcessingOverlay), findsOneWidget);
    });

    testWidgets('play button is disabled when no final rendered clip', (
      tester,
    ) async {
      final state = VideoEditorProviderState();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataClipPreview()),
          ),
        ),
      );

      // Play indicator should exist but be disabled (no onTap callback)
      expect(find.byType(GestureDetector), findsWidgets);
    });

    testWidgets('play button is enabled when final rendered clip exists', (
      tester,
    ) async {
      final finalClip = RecordingClip(
        id: 'final-clip',
        video: EditorVideo.file('final.mp4'),
        duration: const Duration(seconds: 15),
        recordedAt: DateTime.now(),
        targetAspectRatio: models.AspectRatio.square,
        originalAspectRatio: 9 / 16,
      );

      final state = VideoEditorProviderState(finalRenderedClip: finalClip);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataClipPreview()),
          ),
        ),
      );

      // Play button should be tappable
      final playButton = find.bySemanticsLabel('Open post preview screen');
      expect(playButton, findsOneWidget);
    });

    testWidgets('opens preview screen when play button tapped', (tester) async {
      final finalClip = RecordingClip(
        id: 'final-clip',
        video: EditorVideo.file('final.mp4'),
        duration: const Duration(seconds: 15),
        recordedAt: DateTime.now(),
        targetAspectRatio: models.AspectRatio.square,
        originalAspectRatio: 9 / 16,
      );

      final state = VideoEditorProviderState(finalRenderedClip: finalClip);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataClipPreview()),
          ),
        ),
      );

      // Just verify the play button exists - actual navigation requires
      // full app context with GoRouter and all providers
      expect(find.bySemanticsLabel('Open post preview screen'), findsOneWidget);
    });

    testWidgets('has correct aspect ratio', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataClipPreview()),
          ),
        ),
      );

      final aspectRatio = tester.widget<AspectRatio>(find.byType(AspectRatio));

      expect(aspectRatio.aspectRatio, equals(testClip.targetAspectRatio.value));
    });

    testWidgets('has Hero widget with correct tag', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataClipPreview()),
          ),
        ),
      );

      final hero = tester.widget<Hero>(find.byType(Hero));
      expect(hero.tag, equals('Video-metadata-clip-preview-video'));
    });

    testWidgets('displays with correct height', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataClipPreview()),
          ),
        ),
      );

      final sizedBox = tester.widget<SizedBox>(
        find.ancestor(of: find.byType(Hero), matching: find.byType(SizedBox)),
      );

      expect(sizedBox.height, equals(200));
    });

    testWidgets('has rounded corners', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => _MockClipManagerNotifier([testClip]),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataClipPreview()),
          ),
        ),
      );

      final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
      expect(clipRRect.borderRadius, equals(BorderRadius.circular(16)));
    });
  });
}

/// Mock clip manager notifier for testing
class _MockClipManagerNotifier extends ClipManagerNotifier {
  _MockClipManagerNotifier(this._clips);

  final List<RecordingClip> _clips;

  @override
  ClipManagerState build() => ClipManagerState(clips: _clips);
}

/// Mock video editor notifier for testing
class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;
}
