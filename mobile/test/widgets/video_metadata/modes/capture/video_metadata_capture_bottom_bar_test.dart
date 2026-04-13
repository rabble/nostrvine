import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_bottom_bar.dart';
import 'package:permissions_service/permissions_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockGallerySaveService extends Mock implements GallerySaveService {}

class _MockPermissionsService extends Mock implements PermissionsService {}

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
  return MaterialApp.router(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEditorVideo());
  });

  group(VideoMetadataCaptureBottomBar, () {
    late _MockGallerySaveService mockGallerySaveService;
    late _MockPermissionsService mockPermissionsService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockGallerySaveService = _MockGallerySaveService();
      mockPermissionsService = _MockPermissionsService();
      when(
        () => mockPermissionsService.openAppSettings(),
      ).thenAnswer((_) async => true);
      when(
        () => mockPermissionsService.checkGalleryStatus(),
      ).thenAnswer((_) async => PermissionStatus.granted);
      when(
        () => mockPermissionsService.requestGalleryPermission(),
      ).thenAnswer((_) async => PermissionStatus.granted);
      when(
        () => mockGallerySaveService.saveVideoToGallery(any()),
      ).thenAnswer((_) async => const GallerySaveSuccess());
    });

    testWidgets('renders both Save draft and Post buttons', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCaptureBottomBar()),
          ),
        ),
      );
      expect(find.text('Save for Later'), findsOneWidget);
      expect(find.text('Post'), findsOneWidget);
    });

    testWidgets('buttons are disabled when metadata is invalid', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCaptureBottomBar()),
          ),
        ),
      );

      // Find buttons by text - they should exist but Post button should have
      // reduced opacity when invalid
      expect(find.text('Post'), findsOneWidget);

      // Post button should have reduced opacity when metadata is invalid
      // Find the AnimatedOpacity that is an ancestor of the Post button
      // Use .first to get DivineButton's AnimatedOpacity (actual disabled state)
      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.text('Post'),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
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
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: VideoMetadataCaptureBottomBar()),
          ),
        ),
      );

      // Buttons should be fully opaque when valid
      // Find the AnimatedOpacity that is an ancestor of the Post button
      // Use .first to get DivineButton's AnimatedOpacity (actual disabled state)
      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find
            .ancestor(
              of: find.text('Post'),
              matching: find.byType(AnimatedOpacity),
            )
            .first,
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
          child: _createTestApp(const VideoMetadataCaptureBottomBar()),
        ),
      );

      await tester.tap(find.text('Save for Later'));
      await tester.pumpAndSettle();

      expect(saveAsDraftCalled, isTrue);
    });

    testWidgets(
      'save for later shows permission sheet on gallery denial',
      (tester) async {
        var saveAsDraftCalled = false;
        when(
          () => mockGallerySaveService.saveVideoToGallery(any()),
        ).thenAnswer((_) async => const GallerySavePermissionDenied());
        when(
          () => mockPermissionsService.checkGalleryStatus(),
        ).thenAnswer((_) async => PermissionStatus.requiresSettings);

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
              permissionsServiceProvider.overrideWithValue(
                mockPermissionsService,
              ),
            ],
            child: _createTestApp(const VideoMetadataCaptureBottomBar()),
          ),
        );

        await tester.tap(find.text('Save for Later'));
        await tester.pumpAndSettle();

        // Permission sheet should be visible
        expect(
          find.text('Let us save your videos'),
          findsOneWidget,
        );

        // Dismiss via "Not Now"
        await tester.tap(find.text('Not Now'));
        await tester.pumpAndSettle();

        // Draft still saved after sheet dismissal
        expect(saveAsDraftCalled, isTrue);
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
          child: _createTestApp(const VideoMetadataCaptureBottomBar()),
        ),
      );

      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();

      expect(postVideoCalled, isTrue);
    });

    testWidgets('post continues after gallery permission sheet dismissal', (
      tester,
    ) async {
      var postVideoCalled = false;
      when(
        () => mockGallerySaveService.saveVideoToGallery(any()),
      ).thenAnswer((_) async => const GallerySavePermissionDenied());
      when(
        () => mockPermissionsService.checkGalleryStatus(),
      ).thenAnswer((_) async => PermissionStatus.requiresSettings);

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
            permissionsServiceProvider.overrideWithValue(
              mockPermissionsService,
            ),
          ],
          child: _createTestApp(const VideoMetadataCaptureBottomBar()),
        ),
      );

      await tester.tap(find.text('Post'));
      await tester.pumpAndSettle();

      // Permission sheet appears — dismiss via "Not Now"
      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      expect(postVideoCalled, isTrue);
    });

    testWidgets(
      'gallery save is skipped when dismissed forever flag is set',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'gallery_permission_dismissed_forever': true,
        });
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
            child: _createTestApp(const VideoMetadataCaptureBottomBar()),
          ),
        );

        await tester.tap(find.text('Post'));
        await tester.pumpAndSettle();

        // Gallery save was never called
        verifyNever(
          () => mockGallerySaveService.saveVideoToGallery(any()),
        );
        expect(postVideoCalled, isTrue);
      },
    );

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
              child: _createTestApp(const VideoMetadataCaptureBottomBar()),
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
        'even if gallery succeeds',
        (tester) async {
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenAnswer((_) async => const GallerySaveSuccess());

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
                permissionsServiceProvider.overrideWithValue(
                  mockPermissionsService,
                ),
              ],
              child: _createTestApp(const VideoMetadataCaptureBottomBar()),
            ),
          );

          await tester.tap(find.text('Save for Later'));
          await tester.pumpAndSettle();

          // Gallery success is not surfaced — only draft status matters.
          final snackbar = findSnackbarContainer(tester);
          expect(snackbar.error, isTrue);
          expect(snackbar.label, equals('Failed to save'));
        },
      );

      testWidgets(
        'save for later shows success snackbar when gallery '
        'save fails but draft succeeds',
        (tester) async {
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenAnswer(
            (_) async => const GallerySaveFailure('disk full'),
          );

          final mockNotifier = _MockVideoEditorNotifier(validState0());

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                videoEditorProvider.overrideWith(() => mockNotifier),
                gallerySaveServiceProvider.overrideWith(
                  (ref) => mockGallerySaveService,
                ),
              ],
              child: _createTestApp(const VideoMetadataCaptureBottomBar()),
            ),
          );

          await tester.tap(find.text('Save for Later'));
          await tester.pumpAndSettle();

          // Gallery failure is optional — draft success is what matters.
          final snackbar = findSnackbarContainer(tester);
          expect(snackbar.error, isFalse);
          expect(snackbar.label, equals('Saved to library'));
        },
      );

      testWidgets(
        'save for later shows error snackbar '
        'when both draft and gallery fail',
        (tester) async {
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenAnswer(
            (_) async => const GallerySaveFailure('storage full'),
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
              child: _createTestApp(const VideoMetadataCaptureBottomBar()),
            ),
          );

          await tester.tap(find.text('Save for Later'));
          await tester.pumpAndSettle();

          final snackbar = findSnackbarContainer(tester);
          expect(snackbar.error, isTrue);
          // Gallery failure is not surfaced — only draft failure matters.
          expect(snackbar.label, equals('Failed to save'));
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
              child: _createTestApp(const VideoMetadataCaptureBottomBar()),
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
              child: _createTestApp(const VideoMetadataCaptureBottomBar()),
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
              child: _createTestApp(const VideoMetadataCaptureBottomBar()),
            ),
          );

          // Verify we start on the page with the bottom bar.
          expect(
            find.byType(VideoMetadataCaptureBottomBar),
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
            (_) async => const GallerySaveFailure('disk full'),
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
              child: _createTestApp(const VideoMetadataCaptureBottomBar()),
            ),
          );

          await tester.tap(find.text('Save for Later'));
          await tester.pumpAndSettle();

          // Stays on the bottom bar page, does not navigate away.
          expect(
            find.byType(VideoMetadataCaptureBottomBar),
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
              child: _createTestApp(const VideoMetadataCaptureBottomBar()),
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
        'post does not show snackbar when gallery save fails',
        (tester) async {
          when(
            () => mockGallerySaveService.saveVideoToGallery(any()),
          ).thenAnswer(
            (_) async => const GallerySaveFailure('no space'),
          );

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
                permissionsServiceProvider.overrideWithValue(
                  mockPermissionsService,
                ),
              ],
              child: _createTestApp(const VideoMetadataCaptureBottomBar()),
            ),
          );

          await tester.tap(find.text('Post'));
          await tester.pumpAndSettle();

          // Gallery failure is optional — no snackbar shown.
          expect(find.byType(DivineSnackbarContainer), findsNothing);
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
  Future<bool> saveAsDraft({bool enforceCreateNewDraft = false}) async {
    onSaveAsDraft?.call();
    return saveAsDraftResult;
  }
}
