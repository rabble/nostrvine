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
import 'package:openvine/widgets/video_clip/video_clip_preview.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../../helpers/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGoRouter mockGoRouter;

  setUp(() {
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
      duration: const Duration(seconds: 5),
      recordedAt: DateTime(2026),
      targetAspectRatio: .vertical,
      originalAspectRatio: 9 / 16,
    );

    Widget buildTestWidget({VoidCallback? onDelete}) {
      return ProviderScope(
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

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(DivineVideoPlayer), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.downloadSimple,
        ),
        findsOneWidget,
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player/player_0'),
            null,
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

      await tester.pumpWidget(buildTestWidget(onDelete: () {}));
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.trash,
        ),
        findsOneWidget,
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player/player_0'),
            null,
          );
    });

    testWidgets('hides delete button when onDelete is null', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player/player_0'),
            (call) async => null,
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIcon && w.icon == DivineIconName.trash,
        ),
        findsNothing,
      );

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player/player_0'),
            null,
          );
    });

    testWidgets('renders placeholder with progress indicator', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player/player_0'),
            (call) async => null,
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player/player_0'),
            null,
          );
    });
  });
}
