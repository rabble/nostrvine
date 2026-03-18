// ABOUTME: Tests for VideoClipEditorBottomBar widget
// ABOUTME: Validates playback controls and time display

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:openvine/widgets/video_editor/clip_editor/video_clip_editor_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/clip_editor/video_time_display.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoClipEditorBottomBar Widget Tests', () {
    Widget buildTestWidget({
      bool isPlaying = false,
      bool isEditing = false,
      bool isReordering = false,
      Duration totalDuration = const Duration(seconds: 10),
    }) {
      final clips = [
        DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('/test/clip.mp4'),
          duration: totalDuration,
          recordedAt: DateTime.now(),
          targetAspectRatio: .vertical,
          originalAspectRatio: 9 / 16,
        ),
      ];
      final bloc = _TestClipEditorBloc(
        initialState: ClipEditorState(
          clips: clips,
          isPlaying: isPlaying,
          isEditing: isEditing,
          isReordering: isReordering,
        ),
      );

      return ProviderScope(
        overrides: [
          videoEditorProvider.overrideWith(TestVideoEditorNotifier.new),
        ],
        child: BlocProvider<ClipEditorBloc>.value(
          value: bloc,
          child: const MaterialApp(
            home: Scaffold(body: VideoClipEditorBottomBar()),
          ),
        ),
      );
    }

    testWidgets('displays play button when not playing', (tester) async {
      await tester.pumpWidget(buildTestWidget());

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
      expect(
        find.textContaining(
          const Duration(seconds: 3).toFormattedSeconds(),
        ),
        findsOneWidget,
      );
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
  @override
  VideoEditorProviderState build() => VideoEditorProviderState();
}

class _TestClipEditorBloc extends ClipEditorBloc {
  _TestClipEditorBloc({
    ClipEditorState initialState = const ClipEditorState(),
  }) {
    emit(initialState);
  }
}
