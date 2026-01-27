import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_bottom_bar.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Creates a test app with GoRouter for navigation tests.
Widget _createTestApp(Widget child) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(body: child),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  group('VideoMetadataBottomBar', () {
    testWidgets('renders both Save draft and Post buttons', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoMetadataBottomBar())),
        ),
      );
      // TODO(@hm21): Once the Drafts library exists, uncomment below
      // expect(find.text('Save draft'), findsOneWidget);
      expect(find.text('Post'), findsOneWidget);
    });

    testWidgets('buttons are disabled when metadata is invalid', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoMetadataBottomBar())),
        ),
      );

      // Find buttons by text - they should exist but Post button should have
      // reduced opacity when invalid
      expect(find.text('Post'), findsOneWidget);

      // Post button should have reduced opacity when metadata is invalid
      // Find the AnimatedOpacity that is an ancestor of the Post button
      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.text('Post'),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(animatedOpacity.opacity, lessThan(1));
    });

    testWidgets('buttons are enabled when metadata is valid', (tester) async {
      // Create valid state with title and final rendered clip
      final validState = VideoEditorProviderState(
        title: 'Test Video',
        finalRenderedClip: RecordingClip(
          id: 'test-clip',
          video: EditorVideo.file('test.mp4'),
          duration: const Duration(seconds: 10),
          recordedAt: DateTime.now(),
          aspectRatio: models.AspectRatio.square,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(validState),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataBottomBar()),
          ),
        ),
      );

      // Buttons should be fully opaque when valid
      // Find the AnimatedOpacity that is an ancestor of the Post button
      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.ancestor(
          of: find.text('Post'),
          matching: find.byType(AnimatedOpacity),
        ),
      );
      expect(animatedOpacity.opacity, equals(1.0));
    });

    testWidgets('tapping Save draft button calls saveAsDraft', (tester) async {
      var saveAsDraftCalled = false;
      final mockNotifier = _MockVideoEditorNotifier(
        VideoEditorProviderState(
          title: 'Test',
          finalRenderedClip: RecordingClip(
            id: 'test',
            video: EditorVideo.file('test.mp4'),
            duration: const Duration(seconds: 5),
            recordedAt: DateTime.now(),
            aspectRatio: models.AspectRatio.square,
          ),
        ),
        onSaveAsDraft: () => saveAsDraftCalled = true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEditorProvider.overrideWith(() => mockNotifier)],
          child: _createTestApp(const VideoMetadataBottomBar()),
        ),
      );

      await tester.tap(find.text('Save draft'));
      await tester.pumpAndSettle();

      expect(saveAsDraftCalled, isTrue);
      // TODO(@hm21): Once the Drafts library exists, remove skip below
    }, skip: true);

    testWidgets('tapping Post button calls postVideo when valid', (
      tester,
    ) async {
      var postVideoCalled = false;
      final mockNotifier = _MockVideoEditorNotifier(
        VideoEditorProviderState(
          title: 'Test',
          finalRenderedClip: RecordingClip(
            id: 'test',
            video: EditorVideo.file('test.mp4'),
            duration: const Duration(seconds: 5),
            recordedAt: DateTime.now(),
            aspectRatio: models.AspectRatio.square,
          ),
        ),
        onPostVideo: () => postVideoCalled = true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEditorProvider.overrideWith(() => mockNotifier)],
          child: _createTestApp(const VideoMetadataBottomBar()),
        ),
      );

      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();

      expect(postVideoCalled, isTrue);
    });
  });
}

/// Mock notifier for testing
class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state, {this.onPostVideo, this.onSaveAsDraft});

  final VideoEditorProviderState _state;
  final VoidCallback? onPostVideo;
  final VoidCallback? onSaveAsDraft;

  @override
  VideoEditorProviderState build() => _state;

  @override
  Future<void> postVideo(BuildContext context) async {
    onPostVideo?.call();
  }

  @override
  Future<bool> saveAsDraft() async {
    onSaveAsDraft?.call();
    return true;
  }
}
