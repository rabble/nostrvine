// ABOUTME: Integration tests for VideoEditorClipGallery widget
// ABOUTME: Tests PageView scrolling, clip selection, and reordering

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_editor_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/video_editor_clip_gallery.dart';
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
          aspectRatio: .vertical,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => TestClipManagerNotifier(ClipManagerState(clips: clips)),
            ),
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(const EditorState()),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoEditorClipGallery()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should render the gallery
      expect(find.byType(VideoEditorClipGallery), findsOneWidget);

      // Verify PageView has 3 children
      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.childrenDelegate.estimatedChildCount, 3);
    });

    testWidgets('displays PageView for clips', (tester) async {
      final clips = List.generate(
        2,
        (i) => RecordingClip(
          id: 'clip$i',
          video: EditorVideo.file('assets/videos/default_intro.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          aspectRatio: .vertical,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => TestClipManagerNotifier(ClipManagerState(clips: clips)),
            ),
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(const EditorState()),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoEditorClipGallery()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // PageView should be present with 2 children
      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.childrenDelegate.estimatedChildCount, 2);
    });

    testWidgets('displays instruction text when not editing', (tester) async {
      final clips = [
        RecordingClip(
          id: 'clip1',
          video: EditorVideo.file('assets/videos/default_intro.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          aspectRatio: .vertical,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => TestClipManagerNotifier(ClipManagerState(clips: clips)),
            ),
            videoEditorProvider.overrideWith(
              () => TestVideoEditorNotifier(const EditorState()),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoEditorClipGallery()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Instruction text should be visible
      expect(find.text('Tap to edit. Drag to reorder.'), findsOneWidget);
    });

    testWidgets('can scroll through clips', (tester) async {
      var currentIndex = 0;
      final clips = List.generate(
        3,
        (i) => RecordingClip(
          id: 'clip$i',
          video: EditorVideo.file('assets/videos/default_intro.mp4'),
          duration: const Duration(seconds: 2),
          recordedAt: DateTime.now(),
          aspectRatio: .vertical,
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
                EditorState(currentClipIndex: currentIndex),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoEditorClipGallery()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.controller?.page, 0.0);

      // Scroll to next clip slowly with multiple small drags
      for (var i = 0; i < 10; i++) {
        await tester.drag(find.byType(PageView), const Offset(-30, 0));
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Let animation complete
      await tester.pumpAndSettle();

      // Verify scroll occurred by checking PageView controller position changed
      final pageViewAfterScroll = tester.widget<PageView>(
        find.byType(PageView),
      );
      expect(pageViewAfterScroll.controller?.page, greaterThan(0.0));
    });

    testWidgets('video plays and pauses correctly', (tester) async {
      final clips = [
        RecordingClip(
          id: 'clip1',
          video: EditorVideo.file('assets/videos/default_intro.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          aspectRatio: .vertical,
        ),
      ];

      final notifier = MutableVideoEditorNotifier(
        const EditorState(isPlaying: false),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            clipManagerProvider.overrideWith(
              () => TestClipManagerNotifier(ClipManagerState(clips: clips)),
            ),
            videoEditorProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoEditorClipGallery()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Video should be paused initially
      expect(notifier.state.isPlaying, false);

      // Start playing
      notifier.updateState(notifier.state.copyWith(isPlaying: true));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Video should be playing
      expect(notifier.state.isPlaying, true);

      // Wait a bit and verify position changes (video is actually playing)
      final initialPosition = notifier.state.currentPosition;
      await tester.pump(const Duration(seconds: 1));

      // Position should have advanced
      expect(
        notifier.state.currentPosition.inMilliseconds,
        greaterThan(initialPosition.inMilliseconds),
      );

      // Stop playing
      notifier.updateState(notifier.state.copyWith(isPlaying: false));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Video should be paused
      expect(notifier.state.isPlaying, false);
    });
  });
}

class TestVideoEditorNotifier extends VideoEditorNotifier {
  TestVideoEditorNotifier(this._state);
  final EditorState _state;

  @override
  EditorState build() => _state;
}

class TestClipManagerNotifier extends ClipManagerNotifier {
  TestClipManagerNotifier(this._state);
  final ClipManagerState _state;

  @override
  ClipManagerState build() => _state;
}

class MutableVideoEditorNotifier extends VideoEditorNotifier {
  MutableVideoEditorNotifier(EditorState initialState) : _state = initialState;
  EditorState _state;

  @override
  EditorState build() => _state;

  void updateState(EditorState newState) {
    _state = newState;
    ref.notifyListeners();
  }
}
