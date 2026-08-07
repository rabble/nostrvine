// ABOUTME: Tests for VideoMetadataPreviewScreen widget
// ABOUTME: Verifies rendering, DivineVideoPlayer integration, and layout

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_publish/video_publish_provider_state.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_preview_screen.dart';
import 'package:openvine/widgets/stop_motion/stop_motion_player.dart';
import 'package:openvine/widgets/video_feed_item/blurred_video_backdrop.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../mocks/mock_nostr_service.dart';

class _MockVideoPublishNotifier extends VideoPublishNotifier {
  _MockVideoPublishNotifier(this._initialState);

  final VideoPublishProviderState _initialState;

  @override
  VideoPublishProviderState build() => _initialState;
}

/// Returns a default editor state so the post-mode overlay can render without
/// the real editor's dependency chain.
class _MockVideoEditorNotifier extends VideoEditorNotifier {
  @override
  VideoEditorProviderState build() => VideoEditorProviderState();
}

/// Supplies a stable public key so the post-mode overlay can resolve the author
/// pubkey without a real nostr session. [NostrClient.publicKey] is non-null, so
/// the base mock's `noSuchMethod` (which returns null) is not enough here.
class _FakeNostrClient extends MockNostrService {
  @override
  String get publicKey =>
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
}

DivineVideoClip _createTestClip({
  String id = 'test-clip',
  models.AspectRatio targetAspectRatio = models.AspectRatio.square,
  String? thumbnailPath,
  List<StopMotionClipFrame>? stopMotionFrames,
}) {
  return DivineVideoClip(
    id: id,
    video: stopMotionFrames == null ? EditorVideo.file('test.mp4') : null,
    duration: const Duration(seconds: 10),
    recordedAt: DateTime.now(),
    targetAspectRatio: targetAspectRatio,
    originalAspectRatio: 9 / 16,
    thumbnailPath: thumbnailPath,
    stopMotionFrames: stopMotionFrames,
  );
}

class _PlayerEventsStreamHandler extends MockStreamHandler {
  MockStreamHandlerEventSink? _events;

  void addState(Map<Object?, Object?> state) => _events?.success(state);

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    _events = events;
  }

  @override
  void onCancel(Object? arguments) {
    _events = null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _PlayerEventsStreamHandler playerEvents;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    playerEvents = _PlayerEventsStreamHandler();
    DivineVideoPlayerController.resetIdCounterForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('divine_video_player'), (
          call,
        ) async {
          if (call.method == 'create') {
            final args = call.arguments! as Map<Object?, Object?>;
            final id = args['id']! as int;
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(
                  MethodChannel('divine_video_player/player_$id'),
                  (call) async => null,
                );
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockStreamHandler(
                  EventChannel('divine_video_player/player_$id/events'),
                  playerEvents,
                );
            return <String, Object?>{'textureId': 1};
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('divine_video_player'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('divine_video_player/player_0'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          const EventChannel('divine_video_player/player_0/events'),
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
      await tester.pumpWidget(buildTestWidget());
      // Pump past the 350ms hero animation timer in initState
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(VideoMetadataPreviewScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('renders $DivineVideoPlayer widget', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DivineVideoPlayer), findsOneWidget);
    });

    testWidgets('cover-fits a non-square clip like the feed does', (
      tester,
    ) async {
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

    testWidgets('sizes the fitted video from decoded source dimensions', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          clip: _createTestClip(thumbnailPath: '/tmp/poster.jpg'),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      playerEvents.addState(<Object?, Object?>{
        'status': 'playing',
        'positionMs': 0,
        'durationMs': 1000,
        'bufferedPositionMs': 1000,
        'currentClipIndex': 0,
        'clipCount': 1,
        'isLooping': true,
        'volume': 1.0,
        'playbackSpeed': 1.0,
        'isFirstFrameRendered': true,
        'videoWidth': 1080,
        'videoHeight': 1920,
      });
      await tester.pump();
      await tester.pump();

      final surfaceBox = tester.widget<SizedBox>(
        find
            .ancestor(
              of: find.byType(DivineVideoPlayer),
              matching: find.byType(SizedBox),
            )
            .first,
      );
      expect(surfaceBox.width, equals(56.25));
      expect(surfaceBox.height, equals(100));
    });

    testWidgets('letterboxes a square clip on the blurred poster backdrop', (
      tester,
    ) async {
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
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DivineIconButton), findsOneWidget);
    });

    testWidgets('stays edge to edge in preview-only mode', (tester) async {
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

    testWidgets('rounds the bottom corners in the post flow', (tester) async {
      // The post flow (previewOnly: false, the default) mounts the metadata
      // overlay, so its editor/nostr dependencies are stubbed here. The stage
      // seams into the post bar with rounded bottom corners.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            videoPublishProvider.overrideWith(
              () =>
                  _MockVideoPublishNotifier(const VideoPublishProviderState()),
            ),
            videoEditorProvider.overrideWith(_MockVideoEditorNotifier.new),
            nostrServiceProvider.overrideWithValue(_FakeNostrClient()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: VideoMetadataPreviewScreen(clip: _createTestClip()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      final rounded = tester.widgetList<ClipRRect>(find.byType(ClipRRect));
      expect(
        rounded.any(
          (clip) =>
              clip.borderRadius ==
              const BorderRadius.vertical(
                bottom: Radius.circular(VineTheme.shellCornerRadius),
              ),
        ),
        isTrue,
      );
    });

    testWidgets('rounds the bottom corners during the hero flight', (
      tester,
    ) async {
      // The flying hero is lifted into the navigator overlay, above the stage's
      // clip, so without its own rounding the preview arrived square-bottomed
      // and only snapped into shape once the flight landed.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            videoPublishProvider.overrideWith(
              () =>
                  _MockVideoPublishNotifier(const VideoPublishProviderState()),
            ),
            videoEditorProvider.overrideWith(_MockVideoEditorNotifier.new),
            nostrServiceProvider.overrideWithValue(_FakeNostrClient()),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: SizedBox.square(
                    dimension: 200,
                    child: Hero(
                      tag: VideoEditorConstants.heroMetaPreviewId,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(
                          VideoEditorConstants.clipPreviewCornerRadius,
                        ),
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).push(
                            PageRouteBuilder<void>(
                              pageBuilder: (_, _, _) =>
                                  VideoMetadataPreviewScreen(
                                    clip: _createTestClip(),
                                  ),
                            ),
                          ),
                          child: const Text('open'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Mid-flight the shuttle sits between the thumbnail's all-round corners
      // and the stage's bottom-only rounding.
      final radii = tester
          .widgetList<ClipRRect>(find.byType(ClipRRect))
          .map((clip) => clip.borderRadius)
          .whereType<BorderRadius>();
      expect(
        radii.any(
          (radius) =>
              radius.bottomLeft.x >
                  VideoEditorConstants.clipPreviewCornerRadius &&
              radius.bottomLeft.x < VineTheme.shellCornerRadius &&
              radius.topLeft.x < VideoEditorConstants.clipPreviewCornerRadius,
        ),
        isTrue,
      );

      // Settle the flight and the overlay timer the screen starts on mount.
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('constrains square stop-motion clips to the target box', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          clip: _createTestClip(
            stopMotionFrames: const <StopMotionClipFrame>[],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(StopMotionPlayer), findsOneWidget);
      final targetBox = tester.widget<AspectRatio>(
        find
            .ancestor(
              of: find.byType(StopMotionPlayer),
              matching: find.byType(AspectRatio),
            )
            .first,
      );
      expect(targetBox.aspectRatio, equals(1.0));
      expect(
        find.ancestor(
          of: find.byType(StopMotionPlayer),
          matching: find.byType(Center),
        ),
        findsOneWidget,
      );
    });

    testWidgets('cover-fills vertical stop-motion clips edge to edge', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          clip: _createTestClip(
            targetAspectRatio: models.AspectRatio.vertical,
            stopMotionFrames: const <StopMotionClipFrame>[],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(StopMotionPlayer), findsOneWidget);
      expect(
        find.ancestor(
          of: find.byType(StopMotionPlayer),
          matching: find.byType(AspectRatio),
        ),
        findsNothing,
      );
      expect(find.byType(BlurredVideoBackdrop), findsNothing);
    });

    testWidgets('hides bottom bar and overlay in preview-only mode', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 400));

      // Post button and overlay should not be present in previewOnly mode
      expect(find.text('Post'), findsNothing);
    });
  });
}
