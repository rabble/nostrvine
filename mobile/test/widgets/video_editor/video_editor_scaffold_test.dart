// ABOUTME: Tests for VideoEditorScaffold widget.
// ABOUTME: Validates layout structure, child widget placement, and clip handling.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_editor/video_editor_scaffold.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorScaffold', () {
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

    Widget buildWidget({
      Widget? overlayControls,
      Widget? bottomBar,
      Widget? editor,
      RecordingClip? clip,
    }) {
      return ProviderScope(
        overrides: [
          clipManagerProvider.overrideWith(
            () => _MockClipManagerNotifier([clip ?? testClip]),
          ),
        ],
        child: MaterialApp(
          home: VideoEditorScaffold(
            overlayControls: overlayControls ?? const Text('Overlay Controls'),
            bottomBar: bottomBar ?? const Text('Bottom Bar'),
            editor: editor ?? const Text('Editor'),
          ),
        ),
      );
    }

    group('Structure', () {
      testWidgets('renders Scaffold with correct background color', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, VineTheme.surfaceContainerHigh);
      });

      testWidgets('renders overlayControls widget', (tester) async {
        await tester.pumpWidget(
          buildWidget(overlayControls: const Text('Test Overlay')),
        );

        expect(find.text('Test Overlay'), findsOneWidget);
      });

      testWidgets('renders bottomBar widget', (tester) async {
        await tester.pumpWidget(
          buildWidget(bottomBar: const Text('Test Bottom Bar')),
        );

        expect(find.text('Test Bottom Bar'), findsOneWidget);
      });

      testWidgets('renders editor widget', (tester) async {
        await tester.pumpWidget(buildWidget(editor: const Text('Test Editor')));

        expect(find.text('Test Editor'), findsOneWidget);
      });

      testWidgets('uses Column layout with editor expanded', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(Column), findsOneWidget);
        expect(find.byType(Expanded), findsOneWidget);
      });
    });

    group('Layout', () {
      testWidgets('editor area uses ClipRRect with rounded bottom corners', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        final clipRRect = tester.widget<ClipRRect>(find.byType(ClipRRect));
        expect(
          clipRRect.borderRadius,
          const BorderRadius.vertical(bottom: Radius.circular(32)),
        );
      });

      testWidgets('uses Stack to overlay controls on editor', (tester) async {
        await tester.pumpWidget(buildWidget());

        // VideoEditorScaffold uses a Stack, may find multiple Stacks in widget tree
        expect(find.byType(Stack), findsWidgets);
      });

      testWidgets('editor is wrapped in FittedBox with cover fit', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        final fittedBox = tester.widget<FittedBox>(find.byType(FittedBox));
        expect(fittedBox.fit, BoxFit.cover);
      });
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
