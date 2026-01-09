// ABOUTME: Integration tests for VideoPublishVideoPreview widget
// ABOUTME: Tests video preview rendering and playback states

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_publish_state.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/widgets/video_publish/video_publish_video_preview.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('VideoPublishVideoPreview Integration Tests', () {
    testWidgets('displays preview with correct aspect ratio', (tester) async {
      final clip = RecordingClip(
        id: 'test-clip',
        video: EditorVideo.file('assets/videos/default_intro.mp4'),
        duration: const Duration(seconds: 5),
        recordedAt: DateTime.now(),
        aspectRatio: model.AspectRatio.vertical,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoPublishProvider.overrideWith(
              () => TestVideoPublishNotifier(
                VideoPublishProviderState(clip: clip),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoPublishVideoPreview()),
          ),
        ),
      );

      // Wait for video to initialize
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));

      // AspectRatio widget should be present
      expect(find.byType(AspectRatio), findsOneWidget);
    });

    testWidgets('shows loading indicator while initializing', (tester) async {
      final clip = RecordingClip(
        id: 'test-clip',
        video: EditorVideo.file('assets/videos/default_intro.mp4'),
        duration: const Duration(seconds: 5),
        recordedAt: DateTime.now(),
        aspectRatio: model.AspectRatio.vertical,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoPublishProvider.overrideWith(
              () => TestVideoPublishNotifier(
                VideoPublishProviderState(clip: clip),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoPublishVideoPreview()),
          ),
        ),
      );

      await tester.pump();

      // CircularProgressIndicator should be visible while loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders without errors when no clip provided', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoPublishProvider.overrideWith(
              () => TestVideoPublishNotifier(const VideoPublishProviderState()),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoPublishVideoPreview()),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(VideoPublishVideoPreview), findsOneWidget);
    });
  });
}

class TestVideoPublishNotifier extends VideoPublishNotifier {
  TestVideoPublishNotifier(this._state);
  final VideoPublishProviderState _state;

  @override
  VideoPublishProviderState build() => _state;

  @override
  void setDuration(Duration duration) {}

  @override
  void updatePosition(Duration position) {}
}
