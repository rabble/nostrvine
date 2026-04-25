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
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_preview_screen.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class _MockVideoPublishNotifier extends VideoPublishNotifier {
  _MockVideoPublishNotifier(this._initialState);

  final VideoPublishProviderState _initialState;

  @override
  VideoPublishProviderState build() => _initialState;
}

DivineVideoClip _createTestClip({String id = 'test-clip'}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file('test.mp4'),
    duration: const Duration(seconds: 10),
    recordedAt: DateTime.now(),
    targetAspectRatio: models.AspectRatio.square,
    originalAspectRatio: 9 / 16,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('divine_video_player'),
          null,
        );
  });

  group(VideoMetadataPreviewScreen, () {
    Widget buildTestWidget({DivineVideoClip? clip}) {
      // Use previewOnly to avoid deep Riverpod dependency chain from
      // the overlay's VideoOverlayActions widget. The overlay is unrelated
      // to the video_player → DivineVideoPlayer migration.
      return ProviderScope(
        overrides: [
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

      await tester.pumpWidget(buildTestWidget());
      // Pump past the 350ms hero animation timer in initState
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(VideoMetadataPreviewScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player/player_0'),
            null,
          );
    });

    testWidgets('renders $DivineVideoPlayer widget', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player/player_0'),
            (call) async => null,
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DivineVideoPlayer), findsOneWidget);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player/player_0'),
            null,
          );
    });

    testWidgets('renders close button', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player/player_0'),
            (call) async => null,
          );

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DivineIconButton), findsOneWidget);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player/player_0'),
            null,
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

      await tester.pumpWidget(buildTestWidget());
      await tester.pump(const Duration(milliseconds: 400));

      // Post button and overlay should not be present in previewOnly mode
      expect(find.text('Post'), findsNothing);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('divine_video_player/player_0'),
            null,
          );
    });
  });
}
