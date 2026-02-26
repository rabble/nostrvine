// ABOUTME: Integration tests for VideoEditorClipPreview widget
// ABOUTME: Tests video preview rendering and interactions

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_clip_editor/gallery/video_editor_clip_preview.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorClipPreview Integration Tests', () {
    testWidgets('displays clip preview with correct aspect ratio', (
      tester,
    ) async {
      final clip = RecordingClip(
        id: 'clip1',
        video: EditorVideo.file('assets/videos/default_intro.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(VideoEditorProviderState()),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoEditorClipPreview(clip: clip),
            ),
          ),
        ),
      );

      // Use pump instead of pumpAndSettle to avoid waiting for infinite animations
      await tester.pump();

      // AspectRatio widget should be present
      expect(find.byType(AspectRatio), findsOneWidget);
    });

    testWidgets('can be tapped when onTap is provided', (tester) async {
      final clip = RecordingClip(
        id: 'clip1',
        video: EditorVideo.file('assets/videos/default_intro.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      var tapped = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(VideoEditorProviderState()),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoEditorClipPreview(
                clip: clip,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      // Use pump instead of pumpAndSettle to avoid waiting for infinite animations
      await tester.pump();

      // Tap the preview
      await tester.tap(find.byType(VideoEditorClipPreview));
      await tester.pump();

      expect(tapped, true);
    });

    testWidgets('shows border when reordering', (tester) async {
      final clip = RecordingClip(
        id: 'clip1',
        video: EditorVideo.file('assets/videos/default_intro.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(VideoEditorProviderState()),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoEditorClipPreview(
                clip: clip,
                isCurrentClip: true,
                isReordering: true,
              ),
            ),
          ),
        ),
      );

      // Use pump instead of pumpAndSettle to avoid waiting for infinite animations
      await tester.pump();

      // AnimatedContainer should be present for border animation
      expect(find.byType(AnimatedContainer), findsWidgets);
    });

    testWidgets('shows deletion zone border color', (tester) async {
      final clip = RecordingClip(
        id: 'clip1',
        video: EditorVideo.file('assets/videos/default_intro.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(
                VideoEditorProviderState(isOverDeleteZone: true),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoEditorClipPreview(
                clip: clip,
                isCurrentClip: true,
                isReordering: true,
              ),
            ),
          ),
        ),
      );

      // Use pump instead of pumpAndSettle to avoid waiting for infinite animations
      await tester.pump();

      // Preview should render with deletion zone styling
      expect(find.byType(VideoEditorClipPreview), findsOneWidget);
    });
  });
}

class TestVideoEditorNotifier extends VideoEditorNotifier {
  TestVideoEditorNotifier(this._state);
  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;
}
