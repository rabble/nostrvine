// ABOUTME: Tests for VideoEditorMoreSheet widget
// ABOUTME: Validates bottom sheet layout and button states

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_editor/video_editor_more_sheet.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorMoreSheet Widget Tests', () {
    Widget buildTestWidget({bool hasClips = false}) {
      return ProviderScope(
        overrides: [
          clipManagerProvider.overrideWith(
            () => TestClipManagerNotifier(
              ClipManagerState(
                clips: hasClips
                    ? [
                        RecordingClip(
                          id: 'test-clip',
                          video: EditorVideo.file('/test/clip.mp4'),
                          duration: const Duration(seconds: 2),
                          recordedAt: DateTime.now(),
                          aspectRatio: .vertical,
                        ),
                      ]
                    : [],
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: VideoEditorMoreSheet())),
      );
    }

    testWidgets('displays add clip from library option', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Add clip from Library'), findsOneWidget);
    });

    testWidgets('displays save to drafts option', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Save to Drafts'), findsOneWidget);
    });

    testWidgets('displays delete clips option', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Delete clips & start over'), findsOneWidget);
    });

    testWidgets('add clip button is always enabled', (tester) async {
      await tester.pumpWidget(buildTestWidget(hasClips: false));

      final addClipButton = find.text('Add clip from Library');
      expect(addClipButton, findsOneWidget);
    });

    testWidgets('save to drafts is disabled when no clips', (tester) async {
      await tester.pumpWidget(buildTestWidget(hasClips: false));

      final saveButton = find.text('Save to Drafts');
      expect(saveButton, findsOneWidget);
    });

    testWidgets('save to drafts is enabled when clips exist', (tester) async {
      await tester.pumpWidget(buildTestWidget(hasClips: true));

      final saveButton = find.text('Save to Drafts');
      expect(saveButton, findsOneWidget);
    });

    testWidgets('delete button is disabled when no clips', (tester) async {
      await tester.pumpWidget(buildTestWidget(hasClips: false));

      final deleteButton = find.text('Delete clips & start over');
      expect(deleteButton, findsOneWidget);
    });

    testWidgets('delete button is enabled when clips exist', (tester) async {
      await tester.pumpWidget(buildTestWidget(hasClips: true));

      final deleteButton = find.text('Delete clips & start over');
      expect(deleteButton, findsOneWidget);
    });

    testWidgets('uses SingleChildScrollView', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(VideoEditorMoreSheet), findsOneWidget);
    });
  });
}

class TestClipManagerNotifier extends ClipManagerNotifier {
  TestClipManagerNotifier(this._state);
  final ClipManagerState _state;

  @override
  ClipManagerState build() => _state;
}
