// ABOUTME: Tests for VideoEditorTopBar widget
// ABOUTME: Validates close button, clip counter, and done button

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_editor_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/video_editor_top_bar.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:pro_video_editor/core/models/video/editor_video_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorTopBar Widget Tests', () {
    Widget buildTestWidget({
      int currentClipIndex = 0,
      int totalClips = 3,
      bool isEditing = false,
    }) {
      return ProviderScope(
        overrides: [
          videoEditorProvider.overrideWith(
            () => TestVideoEditorNotifier(
              EditorState(
                currentClipIndex: currentClipIndex,
                isEditing: isEditing,
              ),
            ),
          ),
          clipManagerProvider.overrideWith(
            () => TestClipManagerNotifier(
              ClipManagerState(
                clips: List.generate(
                  totalClips,
                  (i) => RecordingClip(
                    id: 'clip$i',
                    video: EditorVideo.file('/test/clip$i.mp4'),
                    duration: const Duration(seconds: 2),
                    recordedAt: DateTime.now(),
                    aspectRatio: .vertical,
                  ),
                ),
              ),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) =>
                    const Scaffold(body: VideoEditorTopBar()),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('displays clip counter with correct format', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(currentClipIndex: 0, totalClips: 3),
      );

      expect(find.text('1/3'), findsOneWidget);
    });

    testWidgets('updates clip counter when clip index changes', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(currentClipIndex: 1, totalClips: 5),
      );

      expect(find.text('2/5'), findsOneWidget);
    });

    testWidgets('displays camera icon when not editing', (tester) async {
      await tester.pumpWidget(buildTestWidget(isEditing: false));

      expect(find.bySemanticsLabel('Go back to camera'), findsOneWidget);
    });

    testWidgets('displays close icon when editing', (tester) async {
      await tester.pumpWidget(buildTestWidget(isEditing: true));

      expect(find.bySemanticsLabel('Close video editor'), findsOneWidget);
    });

    testWidgets('displays done button when not editing', (tester) async {
      await tester.pumpWidget(buildTestWidget(isEditing: false));

      expect(find.bySemanticsLabel('Done editing'), findsOneWidget);
    });

    testWidgets('displays more button when editing', (tester) async {
      await tester.pumpWidget(buildTestWidget(isEditing: true));

      expect(find.bySemanticsLabel('More'), findsOneWidget);
    });

    testWidgets('close button is tappable when editing', (tester) async {
      await tester.pumpWidget(buildTestWidget(isEditing: true));

      final closeButton = find.bySemanticsLabel('Close video editor');

      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      expect(closeButton, findsOneWidget);
    });

    testWidgets('more button is tappable when editing', (tester) async {
      await tester.pumpWidget(buildTestWidget(isEditing: true));

      final moreButton = find.bySemanticsLabel('More');

      await tester.tap(moreButton);
      await tester.pumpAndSettle();

      expect(moreButton, findsOneWidget);
    });

    testWidgets('displays correct clip counter for single clip', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(currentClipIndex: 0, totalClips: 1),
      );

      expect(find.text('1/1'), findsOneWidget);
    });
  });
}

class TestVideoEditorNotifier extends VideoEditorNotifier {
  TestVideoEditorNotifier(this._state);
  final EditorState _state;

  @override
  EditorState build() => _state;

  @override
  void stopClipEditing() {}

  @override
  Future<void> showMoreOptions(BuildContext context) async {}

  @override
  Future<void> done(BuildContext context) async {}
}

class TestClipManagerNotifier extends ClipManagerNotifier {
  TestClipManagerNotifier(this._state);
  final ClipManagerState _state;

  @override
  ClipManagerState build() => _state;
}
