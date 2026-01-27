// ABOUTME: Tests for VideoClipEditorBottomBar widget
// ABOUTME: Validates playback controls, mute button, and time display

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_clip_editor/video_clip_editor_bottom_bar.dart';
import 'package:openvine/widgets/video_clip_editor/video_time_display.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoClipEditorBottomBar Widget Tests', () {
    Widget buildTestWidget({
      bool isPlaying = false,
      bool isEditing = false,
      bool isReordering = false,
      bool isMuted = false,
      Duration totalDuration = const Duration(seconds: 10),
    }) {
      return ProviderScope(
        overrides: [
          videoEditorProvider.overrideWith(
            () => TestVideoEditorNotifier(
              VideoEditorProviderState(
                isPlaying: isPlaying,
                isEditing: isEditing,
                isReordering: isReordering,
                isMuted: isMuted,
              ),
            ),
          ),
          clipManagerProvider.overrideWith(
            () => TestClipManagerNotifier(
              ClipManagerState(
                clips: [
                  RecordingClip(
                    id: 'test-clip',
                    video: EditorVideo.file('/test/clip.mp4'),
                    duration: totalDuration,
                    recordedAt: DateTime.now(),
                    aspectRatio: .vertical,
                  ),
                ],
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: VideoClipEditorBottomBar()),
        ),
      );
    }

    testWidgets('displays play button when not playing', (tester) async {
      await tester.pumpWidget(buildTestWidget(isPlaying: false));

      expect(find.bySemanticsLabel('Play or pause video'), findsOneWidget);
    });

    testWidgets('displays pause button when playing', (tester) async {
      await tester.pumpWidget(buildTestWidget(isPlaying: true));

      expect(find.bySemanticsLabel('Play or pause video'), findsOneWidget);
    });

    testWidgets('displays more options button', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.bySemanticsLabel('More options'), findsOneWidget);
    });

    testWidgets('displays crop button when editing', (tester) async {
      await tester.pumpWidget(buildTestWidget(isEditing: true));

      expect(find.bySemanticsLabel('Crop'), findsOneWidget);
    });

    testWidgets('does not display mute button when editing', (tester) async {
      await tester.pumpWidget(buildTestWidget(isEditing: true));

      // Mute and more buttons should not be visible when editing
      expect(find.bySemanticsLabel('Mute or unmute audio'), findsNothing);
    });

    testWidgets('displays time display', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(totalDuration: const Duration(seconds: 3)),
      );
      await tester.pump();

      // VideoTimeDisplay should be present with correct duration
      expect(find.byType(VideoTimeDisplay), findsOneWidget);
      expect(find.textContaining('3.00s'), findsOneWidget);
    });

    testWidgets('limit time display to maximum', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(totalDuration: VideoEditorConstants.maxDuration * 2),
      );
      await tester.pump();

      // VideoTimeDisplay should be present with correct duration
      expect(find.byType(VideoTimeDisplay), findsOneWidget);
      expect(
        find.textContaining(
          VideoEditorConstants.maxDuration.toFormattedSeconds(),
        ),
        findsOneWidget,
      );
    });

    testWidgets('play button is tappable', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final playButton = find.bySemanticsLabel('Play or pause video');

      await tester.tap(playButton);
      await tester.pumpAndSettle();

      expect(playButton, findsOneWidget);
    });

    testWidgets('hides controls when reordering', (tester) async {
      await tester.pumpWidget(buildTestWidget(isReordering: true));

      // Control buttons should not be visible
      expect(find.bySemanticsLabel('Play or pause video'), findsNothing);
      expect(find.bySemanticsLabel('Mute or unmute audio'), findsNothing);
    });
  });
}

class TestVideoEditorNotifier extends VideoEditorNotifier {
  TestVideoEditorNotifier(this._state);
  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;

  @override
  void togglePlayPause() {}

  @override
  void toggleMute() {}
}

class TestClipManagerNotifier extends ClipManagerNotifier {
  TestClipManagerNotifier(this._state);
  final ClipManagerState _state;

  @override
  ClipManagerState build() => _state;
}
