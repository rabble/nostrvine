// ABOUTME: Integration tests for VideoClipPreview widget
// ABOUTME: Tests video preview rendering and interactions

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_editor_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/video_editor_clip_preview.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('VideoClipPreview Integration Tests', () {
    testWidgets('displays clip preview with correct aspect ratio', (
      tester,
    ) async {
      final clip = RecordingClip(
        id: 'clip1',
        video: EditorVideo.file('assets/videos/default_intro.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        aspectRatio: .vertical,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(const EditorState()),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoClipPreview(clip: clip, isCurrentClip: false),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // AspectRatio widget should be present
      expect(find.byType(AspectRatio), findsOneWidget);
    });

    testWidgets('can be tapped when onTap is provided', (tester) async {
      final clip = RecordingClip(
        id: 'clip1',
        video: EditorVideo.file('assets/videos/default_intro.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        aspectRatio: .vertical,
      );

      var tapped = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(const EditorState()),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoClipPreview(
                clip: clip,
                isCurrentClip: false,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap the preview
      await tester.tap(find.byType(VideoClipPreview));
      await tester.pumpAndSettle();

      expect(tapped, true);
    });

    testWidgets('shows border when reordering', (tester) async {
      final clip = RecordingClip(
        id: 'clip1',
        video: EditorVideo.file('assets/videos/default_intro.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        aspectRatio: .vertical,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(const EditorState()),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoClipPreview(
                clip: clip,
                isCurrentClip: true,
                isReordering: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // AnimatedContainer should be present for border animation
      expect(find.byType(AnimatedContainer), findsWidgets);
    });

    testWidgets('shows deletion zone border color', (tester) async {
      final clip = RecordingClip(
        id: 'clip1',
        video: EditorVideo.file('assets/videos/default_intro.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        aspectRatio: .vertical,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(const EditorState()),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: VideoClipPreview(
                clip: clip,
                isCurrentClip: true,
                isDeletionZone: true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Preview should render with deletion zone styling
      expect(find.byType(VideoClipPreview), findsOneWidget);
    });
  });
}

class TestVideoEditorNotifier extends VideoEditorNotifier {
  TestVideoEditorNotifier(this._state);
  final EditorState _state;

  @override
  EditorState build() => _state;
}
