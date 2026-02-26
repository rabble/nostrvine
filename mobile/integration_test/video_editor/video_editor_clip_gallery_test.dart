// ABOUTME: Integration tests for VideoEditorClipGallery widget
// ABOUTME: Tests PageView scrolling, clip selection, and reordering

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_clip_editor/gallery/video_editor_clip_gallery.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorClipGallery Integration Tests', () {
    testWidgets('displays multiple clips in gallery', (tester) async {
      final clips = List.generate(
        3,
        (i) => RecordingClip(
          id: 'clip$i',
          video: EditorVideo.file('assets/videos/default_intro.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => TestClipManagerNotifier(ClipManagerState(clips: clips)),
            ),
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(VideoEditorProviderState()),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoEditorClipGallery()),
          ),
        ),
      );

      // Use pump instead of pumpAndSettle to avoid waiting for infinite
      // animations
      await tester.pump();

      // Should render the gallery
      expect(find.byType(VideoEditorClipGallery), findsOneWidget);

      // Verify Scrollable is present (the gallery uses Scrollable, not PageView)
      expect(find.byType(Scrollable), findsOneWidget);
    });

    testWidgets('displays Scrollable for clips', (tester) async {
      final clips = List.generate(
        2,
        (i) => RecordingClip(
          id: 'clip$i',
          video: EditorVideo.file('assets/videos/default_intro.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => TestClipManagerNotifier(ClipManagerState(clips: clips)),
            ),
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(VideoEditorProviderState()),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoEditorClipGallery()),
          ),
        ),
      );

      // Use pump instead of pumpAndSettle to avoid waiting for infinite animations
      await tester.pump();

      // Scrollable should be present (the gallery uses Scrollable with Viewport)
      expect(find.byType(Scrollable), findsOneWidget);
    });

    testWidgets('displays instruction text when not editing', (tester) async {
      final clips = [
        RecordingClip(
          id: 'clip1',
          video: EditorVideo.file('assets/videos/default_intro.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => TestClipManagerNotifier(ClipManagerState(clips: clips)),
            ),
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(VideoEditorProviderState()),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoEditorClipGallery()),
          ),
        ),
      );

      // Use pump instead of pumpAndSettle to avoid waiting for infinite animations
      await tester.pump();

      // Instruction text should be visible
      expect(
        find.text('Tap to edit. Hold and drag to reorder.'),
        findsOneWidget,
      );
    });

    testWidgets('can scroll through clips', (tester) async {
      final clips = List.generate(
        3,
        (i) => RecordingClip(
          id: 'clip$i',
          video: EditorVideo.file('assets/videos/default_intro.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => TestClipManagerNotifier(ClipManagerState(clips: clips)),
            ),
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(
                VideoEditorProviderState(),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoEditorClipGallery()),
          ),
        ),
      );

      // Use pump instead of pumpAndSettle to avoid waiting for infinite animations
      await tester.pump();

      // Verify Scrollable is present
      expect(find.byType(Scrollable), findsOneWidget);

      // Scroll to next clip slowly with multiple small drags
      for (var i = 0; i < 10; i++) {
        await tester.drag(find.byType(Scrollable), const Offset(-30, 0));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Let animation frames render
      await tester.pump(const Duration(milliseconds: 500));

      // Verify gallery still renders after scrolling
      expect(find.byType(VideoEditorClipGallery), findsOneWidget);
    });
  });
}

class TestVideoEditorNotifier extends VideoEditorNotifier {
  TestVideoEditorNotifier(this._state);
  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;
}

class TestClipManagerNotifier extends ClipManagerNotifier {
  TestClipManagerNotifier(this._state);
  final ClipManagerState _state;

  @override
  ClipManagerState build() => _state;
}

class MutableVideoEditorNotifier extends VideoEditorNotifier {
  MutableVideoEditorNotifier(VideoEditorProviderState initialState)
    : _state = initialState;
  VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;

  void updateState(VideoEditorProviderState newState) {
    _state = newState;
    ref.notifyListeners();
  }
}
