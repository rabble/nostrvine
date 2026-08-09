// ABOUTME: Tests for VideoClipPreview widget
// ABOUTME: Verifies rendering, DivineVideoPlayer integration, and button layout

import 'dart:io';
import 'dart:ui' show SemanticsAction;

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/widgets/stop_motion/stop_motion_player.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';
import 'package:openvine/widgets/video_clip/video_clip_hero.dart';
import 'package:openvine/widgets/video_clip/video_clip_preview.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../helpers/go_router.dart';

class _MockGallerySaveService extends Mock implements GallerySaveService {}

/// Reports a decoded first frame as soon as the controller subscribes, which
/// is what drops [DivineVideoPlayer]'s placeholder from the tree.
class _FirstFrameStreamHandler extends MockStreamHandler {
  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    events.success(<Object?, Object?>{
      'status': 'playing',
      'positionMs': 0,
      'durationMs': 1000,
      'bufferedPositionMs': 500,
      'currentClipIndex': 0,
      'clipCount': 1,
      'isLooping': true,
      'volume': 1.0,
      'playbackSpeed': 1.0,
      'isFirstFrameRendered': true,
      'videoWidth': 1080,
      'videoHeight': 1920,
    });
  }

  @override
  void onCancel(Object? arguments) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGoRouter mockGoRouter;
  late _MockGallerySaveService mockGallerySaveService;

  setUpAll(() {
    registerFallbackValue(EditorVideo.file('/fallback.mp4'));
  });

  setUp(() {
    mockGallerySaveService = _MockGallerySaveService();
    DivineVideoPlayerController.resetIdCounterForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('divine_video_player'), (
          call,
        ) async {
          if (call.method == 'create') {
            return <String, Object?>{'textureId': 1};
          }
          return null;
        });

    mockGoRouter = MockGoRouter();
    when(() => mockGoRouter.pop<Object?>(any())).thenReturn(null);
    when(() => mockGoRouter.canPop()).thenReturn(true);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('divine_video_player'),
          null,
        );
  });

  group(VideoClipPreview, () {
    final testClip = DivineVideoClip(
      id: 'test-clip-1',
      video: EditorVideo.file('/path/to/video.mp4'),
      libraryTitle: 'Rooftop loop',
      duration: const Duration(seconds: 5),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
    );

    Widget buildTestWidget({DivineVideoClip? clip, VoidCallback? onDelete}) {
      return ProviderScope(
        overrides: [
          gallerySaveServiceProvider.overrideWithValue(mockGallerySaveService),
        ],
        child: MockGoRouterProvider(
          goRouter: mockGoRouter,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoClipPreview(
                clip: clip ?? testClip,
                onDelete: onDelete,
              ),
            ),
          ),
        ),
      );
    }

    test('can be instantiated', () {
      expect(VideoClipPreview(clip: testClip), isA<VideoClipPreview>());
    });

    test('accepts onDelete callback', () {
      expect(
        VideoClipPreview(clip: testClip, onDelete: () {}),
        isA<VideoClipPreview>(),
      );
    });

    testWidgets('exposes an action to close the video preview', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player/player_0'),
            (call) async => null,
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player/player_0'),
              null,
            );
      });

      await tester.pumpWidget(buildTestWidget());
      final l10n = lookupAppLocalizations(const Locale('en'));
      final semantics = tester.getSemantics(find.byType(VideoClipPreview));

      expect(
        semantics.label,
        l10n.videoMetadataClosePreviewSemanticLabel,
      );
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isTrue,
      );
      expect(
        find.bySemanticsLabel(
          l10n.videoClipSaveTo(GallerySaveService.destinationName),
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders $DivineVideoPlayer and save button', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player/player_0'),
            (call) async => null,
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player/player_0'),
              null,
            );
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DivineVideoPlayer), findsOneWidget);
      expect(find.text('Rooftop loop'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.downloadSimple,
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders delete button when onDelete is provided', (
      tester,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player/player_0'),
            (call) async => null,
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player/player_0'),
              null,
            );
      });

      await tester.pumpWidget(buildTestWidget(onDelete: () {}));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.trash,
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides delete button when onDelete is null', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player/player_0'),
            (call) async => null,
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player/player_0'),
              null,
            );
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.trash,
        ),
        findsNothing,
      );
    });

    testWidgets('renders placeholder with progress indicator', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player/player_0'),
            (call) async => null,
          );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player/player_0'),
              null,
            );
      });

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('keeps the hero mounted once the video replaces the '
        'placeholder', (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('clip_preview_hero');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final videoFile = File('${tempDir.path}/video.mp4')
        ..writeAsBytesSync(const [0]);
      final thumbnailFile = File('${tempDir.path}/thumbnail.jpg')
        ..writeAsBytesSync(_transparentPngBytes);

      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            ..setMockMethodCallHandler(
              const MethodChannel('divine_video_player/player_0'),
              (call) async => null,
            )
            ..setMockStreamHandler(
              const EventChannel('divine_video_player/player_0/events'),
              _FirstFrameStreamHandler(),
            );
      addTearDown(() {
        messenger
          ..setMockMethodCallHandler(
            const MethodChannel('divine_video_player/player_0'),
            null,
          )
          ..setMockStreamHandler(
            const EventChannel('divine_video_player/player_0/events'),
            null,
          );
      });

      final clip = testClip.copyWith(
        video: EditorVideo.file(videoFile.path),
        thumbnailPath: thumbnailFile.path,
      );

      await tester.pumpWidget(buildTestWidget(clip: clip));
      // pumpAndSettle cannot be used here because the pre-fix placeholder owns
      // a CircularProgressIndicator that never settles.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // The placeholder — which used to own the hero — is gone once the first
      // frame is up, so a hero living inside it would be unmounted here and
      // the dismiss animation would have nothing to fly back from.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is Hero && w.tag == videoClipPreviewHeroTag(clip.id),
        ),
        findsOneWidget,
      );
    });

    testWidgets('builds a decorative thumbnail shuttle for stop-motion clips', (
      tester,
    ) async {
      final tempDir = Directory.systemTemp.createTempSync(
        'clip_preview_stop_motion_hero',
      );
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final frameFile = File('${tempDir.path}/frame.png')
        ..writeAsBytesSync(_transparentPngBytes);

      final clip = DivineVideoClip(
        id: 'stop-motion-clip-1',
        stopMotionFrames: [
          StopMotionClipFrame(
            path: frameFile.path,
            duration: const Duration(milliseconds: 83),
          ),
        ],
        thumbnailPath: frameFile.path,
        libraryTitle: 'Tiny jump',
        duration: const Duration(milliseconds: 83),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      await tester.pumpWidget(buildTestWidget(clip: clip));

      expect(find.byType(StopMotionPlayer), findsOneWidget);

      final heroFinder = find.byWidgetPredicate(
        (w) => w is Hero && w.tag == videoClipPreviewHeroTag(clip.id),
      );
      final hero = tester.widget<Hero>(heroFinder);
      final shuttle = hero.flightShuttleBuilder!(
        tester.element(find.byType(VideoClipPreview)),
        const AlwaysStoppedAnimation<double>(0),
        HeroFlightDirection.push,
        tester.element(heroFinder),
        tester.element(heroFinder),
      );

      final thumbnail = shuttle as ClipThumbnailImage;
      expect(thumbnail.path, frameFile.path);
      expect(thumbnail.fit, BoxFit.cover);
      expect(thumbnail.cacheHeight, tester.view.physicalSize.height.round());
      expect(thumbnail.excludeFromSemantics, isTrue);
      expect(thumbnail.placeholder, isA<VideoClipThumbnailPlaceholder>());
    });

    group('save result snackbar', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final destination = GallerySaveService.destinationName;

      Future<void> pumpAndSave(
        WidgetTester tester,
        GallerySaveResult result,
      ) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player/player_0'),
              (call) async => null,
            );
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(
                const MethodChannel('divine_video_player/player_0'),
                null,
              );
        });

        when(
          () => mockGallerySaveService.saveVideoToGallery(any()),
        ).thenAnswer((_) async => result);

        await tester.pumpWidget(buildTestWidget());
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is DivineIcon && w.icon == DivineIconName.downloadSimple,
          ),
        );
        await tester.pump();
        await tester.pump();
      }

      testWidgets('shows saved message on $GallerySaveSuccess', (tester) async {
        await pumpAndSave(tester, const GallerySaveSuccess());

        expect(
          find.text(l10n.libraryClipsSavedToDestination(1, destination)),
          findsOneWidget,
        );
      });

      testWidgets('shows permission message on $GallerySavePermissionDenied', (
        tester,
      ) async {
        await pumpAndSave(tester, const GallerySavePermissionDenied());

        expect(
          find.text(l10n.libraryGalleryPermissionDenied(destination)),
          findsOneWidget,
        );
      });

      testWidgets('shows failure message on $GallerySaveFailure', (
        tester,
      ) async {
        await pumpAndSave(tester, const GallerySaveFailure('disk full'));

        expect(find.text(l10n.videoClipSaveFailed), findsOneWidget);
      });
    });
  });
}

const _transparentPngBytes = <int>[
  0x89,
  0x50,
  0x4e,
  0x47,
  0x0d,
  0x0a,
  0x1a,
  0x0a,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1f,
  0x15,
  0xc4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0d,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9c,
  0x63,
  0x60,
  0x00,
  0x00,
  0x00,
  0x02,
  0x00,
  0x01,
  0xe2,
  0x21,
  0xbc,
  0x33,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4e,
  0x44,
  0xae,
  0x42,
  0x60,
  0x82,
];
