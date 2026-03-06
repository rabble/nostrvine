import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_bottom_bar.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockGallerySaveService extends Mock implements GallerySaveService {}

class _FakeEditorVideo extends Fake implements EditorVideo {}

/// Creates a test app with GoRouter for navigation tests.
Widget _createTestApp(Widget child) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/home/:index',
        builder: (context, state) => Scaffold(body: child),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEditorVideo());
  });

  group('VideoMetadataBottomBar', () {
    late _MockGallerySaveService mockGallerySaveService;

    setUp(() {
      mockGallerySaveService = _MockGallerySaveService();
      when(
        () => mockGallerySaveService.saveVideoToGallery(any()),
      ).thenAnswer((_) async => const GallerySaveSuccess());
    });

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
        finalRenderedClip: DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file('test.mp4'),
          duration: const Duration(seconds: 10),
          recordedAt: DateTime.now(),
          targetAspectRatio: models.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(validState),
            ),
            gallerySaveServiceProvider.overrideWith(
              (ref) => mockGallerySaveService,
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
          finalRenderedClip: DivineVideoClip(
            id: 'test',
            video: EditorVideo.file('test.mp4'),
            duration: const Duration(seconds: 5),
            recordedAt: DateTime.now(),
            targetAspectRatio: models.AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ),
        onSaveAsDraft: () => saveAsDraftCalled = true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(() => mockNotifier),
            gallerySaveServiceProvider.overrideWith(
              (ref) => mockGallerySaveService,
            ),
          ],
          child: _createTestApp(const VideoMetadataBottomBar()),
        ),
      );

      await tester.tap(find.text('Save for Later'));
      await tester.pumpAndSettle();

      expect(saveAsDraftCalled, isTrue);
    });

    testWidgets(
      'save for later surfaces gallery permission errors instead of full success',
      (tester) async {
        var saveAsDraftCalled = false;
        when(
          () => mockGallerySaveService.saveVideoToGallery(any()),
        ).thenAnswer((_) async => const GallerySavePermissionDenied());

        final mockNotifier = _MockVideoEditorNotifier(
          VideoEditorProviderState(
            title: 'Test',
            finalRenderedClip: DivineVideoClip(
              id: 'test',
              video: EditorVideo.file('test.mp4'),
              duration: const Duration(seconds: 5),
              recordedAt: DateTime.now(),
              targetAspectRatio: models.AspectRatio.square,
              originalAspectRatio: 9 / 16,
            ),
          ),
          onSaveAsDraft: () => saveAsDraftCalled = true,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              videoEditorProvider.overrideWith(() => mockNotifier),
              gallerySaveServiceProvider.overrideWith(
                (ref) => mockGallerySaveService,
              ),
            ],
            child: _createTestApp(const VideoMetadataBottomBar()),
          ),
        );

        await tester.tap(find.text('Save for Later'));
        await tester.pumpAndSettle();

        expect(saveAsDraftCalled, isTrue);
        expect(find.textContaining('permission denied'), findsOneWidget);
      },
    );

    testWidgets('tapping Post button calls postVideo when valid', (
      tester,
    ) async {
      var postVideoCalled = false;
      final mockNotifier = _MockVideoEditorNotifier(
        VideoEditorProviderState(
          title: 'Test',
          finalRenderedClip: DivineVideoClip(
            id: 'test',
            video: EditorVideo.file('test.mp4'),
            duration: const Duration(seconds: 5),
            recordedAt: DateTime.now(),
            targetAspectRatio: models.AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ),
        onPostVideo: () => postVideoCalled = true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(() => mockNotifier),
            gallerySaveServiceProvider.overrideWith(
              (ref) => mockGallerySaveService,
            ),
          ],
          child: _createTestApp(const VideoMetadataBottomBar()),
        ),
      );

      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();

      expect(postVideoCalled, isTrue);
    });

    testWidgets('post continues after gallery save permission denial', (
      tester,
    ) async {
      var postVideoCalled = false;
      when(
        () => mockGallerySaveService.saveVideoToGallery(any()),
      ).thenAnswer((_) async => const GallerySavePermissionDenied());

      final mockNotifier = _MockVideoEditorNotifier(
        VideoEditorProviderState(
          title: 'Test',
          finalRenderedClip: DivineVideoClip(
            id: 'test',
            video: EditorVideo.file('test.mp4'),
            duration: const Duration(seconds: 5),
            recordedAt: DateTime.now(),
            targetAspectRatio: models.AspectRatio.square,
            originalAspectRatio: 9 / 16,
          ),
        ),
        onPostVideo: () => postVideoCalled = true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(() => mockNotifier),
            gallerySaveServiceProvider.overrideWith(
              (ref) => mockGallerySaveService,
            ),
          ],
          child: _createTestApp(const VideoMetadataBottomBar()),
        ),
      );

      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();

      expect(postVideoCalled, isTrue);
      expect(find.textContaining('permission denied'), findsOneWidget);
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
