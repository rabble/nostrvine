import 'package:divine_ui/divine_ui.dart';
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
        builder: (context, state) => const Scaffold(body: Placeholder()),
      ),
      GoRoute(
        path: '/drafts',
        builder: (context, state) => const Scaffold(body: Placeholder()),
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

    group('snackbar error state', () {
      VideoEditorProviderState validState0() => VideoEditorProviderState(
        title: 'Test',
        finalRenderedClip: DivineVideoClip(
          id: 'test',
          video: EditorVideo.file('test.mp4'),
          duration: const Duration(seconds: 5),
          recordedAt: DateTime.now(),
          targetAspectRatio: models.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        ),
      );

      DivineSnackbarContainer findSnackbarContainer(
        WidgetTester tester,
      ) {
        return tester.widget<DivineSnackbarContainer>(
          find.byType(DivineSnackbarContainer),
        );
      }

      testWidgets(
        'save for later shows non-error snackbar '
        'when gallery and draft both succeed',
        (tester) async {
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenAnswer((_) async => const GallerySaveSuccess());

          final mockNotifier = _MockVideoEditorNotifier(validState0());

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

          final snackbar = findSnackbarContainer(tester);
          expect(snackbar.error, isFalse);
          expect(snackbar.label, equals('Saved to library'));
        },
      );

      testWidgets(
        'save for later shows error snackbar when draft save fails '
        'but gallery succeeds',
        (tester) async {
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenAnswer((_) async => const GallerySaveSuccess());

          final destination = GallerySaveService.destinationName;
          final mockNotifier = _MockVideoEditorNotifier(
            validState0(),
            saveAsDraftResult: false,
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

          final snackbar = findSnackbarContainer(tester);
          expect(snackbar.error, isTrue);
          expect(
            snackbar.label,
            equals(
              'Saved to $destination, but failed to save to library',
            ),
          );
        },
      );

      testWidgets(
        'save for later shows error snackbar when gallery '
        'save fails with reason',
        (tester) async {
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenAnswer(
            (_) async => const GallerySaveFailure('disk full'),
          );

          final destination = GallerySaveService.destinationName;
          final mockNotifier = _MockVideoEditorNotifier(validState0());

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

          final snackbar = findSnackbarContainer(tester);
          expect(snackbar.error, isTrue);
          expect(
            snackbar.label,
            equals(
              'Saved to library, but '
              'failed to save to $destination: disk full',
            ),
          );
        },
      );

      testWidgets(
        'save for later shows error snackbar '
        'when both draft and gallery fail',
        (tester) async {
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenAnswer(
            (_) async => const GallerySavePermissionDenied(),
          );

          final destination = GallerySaveService.destinationName;
          final mockNotifier = _MockVideoEditorNotifier(
            validState0(),
            saveAsDraftResult: false,
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

          final snackbar = findSnackbarContainer(tester);
          expect(snackbar.error, isTrue);
          expect(
            snackbar.label,
            equals(
              'Failed to save to library, '
              'and $destination permission denied',
            ),
          );
        },
      );

      testWidgets(
        'save for later shows error snackbar '
        'when draft fails and no clip for gallery',
        (tester) async {
          // State without finalRenderedClip so gallery save returns null.
          final mockNotifier = _MockVideoEditorNotifier(
            VideoEditorProviderState(title: 'Test'),
            saveAsDraftResult: false,
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

          final snackbar = findSnackbarContainer(tester);
          expect(snackbar.error, isTrue);
          expect(snackbar.label, equals('Failed to save'));
        },
      );

      testWidgets(
        'save for later snackbar shows Go to Library action',
        (tester) async {
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenAnswer((_) async => const GallerySaveSuccess());

          final mockNotifier = _MockVideoEditorNotifier(validState0());

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

          final snackbar = findSnackbarContainer(tester);
          expect(snackbar.actionLabel, equals('Go to Library'));
          expect(snackbar.onActionPressed, isNotNull);
        },
      );

      testWidgets(
        'save for later navigates to feed on success',
        (tester) async {
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenAnswer((_) async => const GallerySaveSuccess());

          final mockNotifier = _MockVideoEditorNotifier(validState0());

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

          // Verify we start on the page with the bottom bar.
          expect(
            find.byType(VideoMetadataBottomBar),
            findsOneWidget,
          );

          await tester.tap(find.text('Save for Later'));
          await tester.pumpAndSettle();

          // After successful save, navigates away from the bottom bar.
          expect(find.byType(Placeholder), findsOneWidget);
        },
      );

      testWidgets(
        'save for later does not navigate to feed on failure',
        (tester) async {
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenAnswer(
            (_) async => const GallerySavePermissionDenied(),
          );

          final mockNotifier = _MockVideoEditorNotifier(
            validState0(),
            saveAsDraftResult: false,
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

          // Stays on the bottom bar page, does not navigate away.
          expect(
            find.byType(VideoMetadataBottomBar),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'post shows no snackbar when gallery save succeeds',
        (tester) async {
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenAnswer((_) async => const GallerySaveSuccess());

          final mockNotifier = _MockVideoEditorNotifier(
            validState0(),
            onPostVideo: () {},
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

          expect(
            find.byType(DivineSnackbarContainer),
            findsNothing,
          );
        },
      );

      testWidgets(
        'post shows error snackbar with gallery failure reason',
        (tester) async {
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenAnswer(
            (_) async => const GallerySaveFailure('no space'),
          );

          final destination = GallerySaveService.destinationName;
          final mockNotifier = _MockVideoEditorNotifier(
            validState0(),
            onPostVideo: () {},
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

          final snackbar = findSnackbarContainer(tester);
          expect(snackbar.error, isTrue);
          expect(
            snackbar.label,
            equals(
              'failed to save to $destination: '
              'no space. Video will still post.',
            ),
          );
        },
      );
    });
  });
}

/// Mock notifier for testing
class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(
    this._state, {
    this.onPostVideo,
    this.onSaveAsDraft,
    this.saveAsDraftResult = true,
  });

  final VideoEditorProviderState _state;
  final VoidCallback? onPostVideo;
  final VoidCallback? onSaveAsDraft;
  final bool saveAsDraftResult;

  @override
  VideoEditorProviderState build() => _state;

  @override
  Future<void> postVideo(BuildContext context) async {
    onPostVideo?.call();
  }

  @override
  Future<bool> saveAsDraft() async {
    onSaveAsDraft?.call();
    return saveAsDraftResult;
  }
}
