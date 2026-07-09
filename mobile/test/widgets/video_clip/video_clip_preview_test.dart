// ABOUTME: Tests for VideoClipPreview widget
// ABOUTME: Verifies rendering, DivineVideoPlayer integration, and button layout

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/widgets/video_clip/video_clip_preview.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../helpers/go_router.dart';

class _MockGallerySaveService extends Mock implements GallerySaveService {}

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

    Widget buildTestWidget({VoidCallback? onDelete}) {
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
              body: VideoClipPreview(clip: testClip, onDelete: onDelete),
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

      testWidgets(
        'shows permission message on $GallerySavePermissionDenied',
        (tester) async {
          await pumpAndSave(tester, const GallerySavePermissionDenied());

          expect(
            find.text(l10n.libraryGalleryPermissionDenied(destination)),
            findsOneWidget,
          );
        },
      );

      testWidgets('shows failure message on $GallerySaveFailure', (
        tester,
      ) async {
        await pumpAndSave(tester, const GallerySaveFailure('disk full'));

        expect(find.text(l10n.videoClipSaveFailed), findsOneWidget);
      });
    });
  });
}
