// ABOUTME: Tests for VideoMetadataPreviewScreen widget
// ABOUTME: Verifies rendering, DivineVideoPlayer integration, and layout

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_preview_screen.dart';
import 'package:openvine/widgets/video_feed_item/blurred_video_backdrop.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockVideoPublishNotifier extends VideoPublishNotifier {
  _MockVideoPublishNotifier(this._initialState);

  final VideoPublishProviderState _initialState;

  @override
  VideoPublishProviderState build() => _initialState;
}

DivineVideoClip _createTestClip({
  String id = 'test-clip',
  models.AspectRatio targetAspectRatio = models.AspectRatio.square,
  String? thumbnailPath,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('test.mp4'),
    duration: const Duration(seconds: 10),
    recordedAt: DateTime.now(),
    targetAspectRatio: targetAspectRatio,
    originalAspectRatio: 9 / 16,
    thumbnailPath: thumbnailPath,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
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
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('divine_video_player'),
          null,
        );
  });

  group(VideoMetadataPreviewScreen, () {
    testWidgets('preview overlay renders metadata without a VideoEvent', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: VideoOverlayActions.preview(
                previewData: VideoOverlayPreviewData(
                  pubkey:
                      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                  title: 'A title',
                  description:
                      'description with nostr:npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq',
                ),
                isVisible: true,
                isActive: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('A title'), findsOneWidget);
      expect(find.textContaining('description with'), findsOneWidget);
      expect(find.byType(VideoOverlayActions), findsOneWidget);
    });

    Widget buildTestWidget({DivineVideoClip? clip}) {
      // Use previewOnly to avoid deep Riverpod dependency chain from
      // the overlay's VideoOverlayActions widget. The overlay is unrelated
      // to the video_player → DivineVideoPlayer migration.
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          videoPublishProvider.overrideWith(
            () => _MockVideoPublishNotifier(const VideoPublishProviderState()),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VideoMetadataPreviewScreen(
            clip: clip ?? _createTestClip(),
            previewOnly: true,
          ),
        ),
      );
    }

    test('can be instantiated', () {
      expect(
        VideoMetadataPreviewScreen(clip: _createTestClip()),
        isA<VideoMetadataPreviewScreen>(),
      );
    });

    testWidgets('renders $VideoMetadataPreviewScreen with scaffold', (
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

      await tester.pumpWidget(buildTestWidget());
      // Pump past the 350ms hero animation timer in initState
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(VideoMetadataPreviewScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders $DivineVideoPlayer widget', (tester) async {
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
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DivineVideoPlayer), findsOneWidget);
    });

    testWidgets('cover-fits a non-square clip like the feed does', (
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

      await tester.pumpWidget(
        buildTestWidget(
          clip: _createTestClip(
            targetAspectRatio: models.AspectRatio.vertical,
            thumbnailPath: '/tmp/poster.jpg',
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final fittedBox = tester.widget<FittedBox>(
        find
            .ancestor(
              of: find.byType(DivineVideoPlayer),
              matching: find.byType(FittedBox),
            )
            .first,
      );
      expect(fittedBox.fit, equals(BoxFit.cover));
      // A cover-fit video occludes the backdrop, so the feed never mounts it.
      expect(find.byType(BlurredVideoBackdrop), findsNothing);
    });

    testWidgets('letterboxes a square clip on the blurred poster backdrop', (
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

      await tester.pumpWidget(
        buildTestWidget(
          clip: _createTestClip(thumbnailPath: '/tmp/poster.jpg'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final fittedBox = tester.widget<FittedBox>(
        find
            .ancestor(
              of: find.byType(DivineVideoPlayer),
              matching: find.byType(FittedBox),
            )
            .first,
      );
      expect(fittedBox.fit, equals(BoxFit.contain));
      final backdrop = tester.widget<BlurredVideoBackdrop>(
        find.byType(BlurredVideoBackdrop),
      );
      expect(backdrop.filePath, equals('/tmp/poster.jpg'));
      expect(backdrop.videoAspectRatio, equals(1.0));
    });

    testWidgets('renders close button', (tester) async {
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
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DivineIconButton), findsOneWidget);
    });

    testWidgets('stays edge to edge in preview-only mode', (tester) async {
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
      await tester.pump(const Duration(milliseconds: 400));

      // The rounded bottom corners seam into the post bar; without a post
      // bar there is nothing to seam into, so the preview fills the screen.
      final rounded = tester.widgetList<ClipRRect>(find.byType(ClipRRect));
      expect(
        rounded.any(
          (clip) =>
              clip.borderRadius ==
              const BorderRadius.vertical(
                bottom: Radius.circular(VineTheme.shellCornerRadius),
              ),
        ),
        isFalse,
      );
    });

    testWidgets('hides bottom bar and overlay in preview-only mode', (
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

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 400));

      // Post button and overlay should not be present in previewOnly mode
      expect(find.text('Post'), findsNothing);
    });
  });
}
