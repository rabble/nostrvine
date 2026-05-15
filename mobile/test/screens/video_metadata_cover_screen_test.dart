// ABOUTME: Tests for VideoMetadataCoverScreen widget
// ABOUTME: Verifies rendering, semantics, navigation, and failure handling

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as models;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/video_metadata/video_metadata_cover_screen.dart';
import 'package:pro_video_editor/core/platform/native_method_channel.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../helpers/go_router.dart';

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;
}

/// Fresh ProVideoEditor-compatible instance for tests.
///
/// This routes calls through the mocked `MethodChannel('pro_video_editor')`
/// while skipping EventChannel subscriptions that are not present in widget
/// tests. It also prevents order-dependent failures when another test file has
/// replaced [ProVideoEditor.instance] with a mock that only implements a
/// subset of methods such as `getWaveform()`.
class _NoopInitProVideoEditor extends MethodChannelProVideoEditor {
  @override
  Stream<dynamic> initializeStream() => const Stream.empty();
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

void _setHandler(
  MethodChannel channel,
  Future<Object?> Function(MethodCall call) handler,
) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, handler);
}

void _clearHandler(MethodChannel channel) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DivineVideoPlayerController.resetIdCounterForTesting();
    ProVideoEditor.instance = _NoopInitProVideoEditor();

    _setHandler(const MethodChannel('plugins.flutter.io/path_provider'), (
      call,
    ) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return '/tmp/documents';
      }
      if (call.method == 'getTemporaryDirectory') {
        return '/tmp';
      }
      return null;
    });

    _setHandler(const MethodChannel('divine_video_player'), (call) async {
      if (call.method == 'create') return <String, Object?>{'textureId': 1};
      return null;
    });

    _setHandler(const MethodChannel('pro_video_editor'), (call) async {
      if (call.method == 'getThumbnails') return <Object?>[];
      if (call.method == 'getMetadata') {
        return <String, Object?>{
          'duration': 3000000,
          'extension': 'mp4',
          'fileSize': 1024000,
          'width': 1920,
          'height': 1080,
          'rotation': 0,
          'bitrate': 3000000,
        };
      }
      return null;
    });
  });

  tearDown(() {
    _clearHandler(const MethodChannel('divine_video_player'));
    _clearHandler(const MethodChannel('pro_video_editor'));
    _clearHandler(const MethodChannel('plugins.flutter.io/path_provider'));
  });

  group(VideoMetadataCoverScreen, () {
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockGoRouter = MockGoRouter();
      when(mockGoRouter.canPop).thenReturn(true);
      when(() => mockGoRouter.pop<Object?>(any())).thenAnswer((_) async {});
    });

    Widget buildWidget({DivineVideoClip? clip}) {
      return ProviderScope(
        overrides: [
          videoEditorProvider.overrideWith(
            () => _MockVideoEditorNotifier(VideoEditorProviderState()),
          ),
        ],
        child: MockGoRouterProvider(
          goRouter: mockGoRouter,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: VideoMetadataCoverScreen(clip: clip ?? _createTestClip()),
          ),
        ),
      );
    }

    void setUpPlayerChannel() {
      _setHandler(
        const MethodChannel('divine_video_player/player_0'),
        (call) async => null,
      );
      _setHandler(
        const MethodChannel('divine_video_player/player_0/events'),
        (call) async => null,
      );
    }

    void tearDownPlayerChannel() {
      _clearHandler(const MethodChannel('divine_video_player/player_0'));
      _clearHandler(const MethodChannel('divine_video_player/player_0/events'));
    }

    Future<void> triggerConfirm(WidgetTester tester) async {
      final buttonFinder = find.byWidgetPredicate(
        (w) => w is DivineIconButton && w.icon == DivineIconName.check,
      );
      final button = tester.widget<DivineIconButton>(buttonFinder);
      button.onPressed?.call();
      await tester.pump();
    }

    test('can be instantiated', () {
      expect(
        VideoMetadataCoverScreen(clip: _createTestClip()),
        isA<VideoMetadataCoverScreen>(),
      );
    });

    testWidgets('renders $VideoMetadataCoverScreen with scaffold', (
      tester,
    ) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(VideoMetadataCoverScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows edit-cover title', (tester) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 400));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.videoMetadataEditCoverTitle), findsOneWidget);
    });

    testWidgets('shows DivineVideoPlayer', (tester) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(DivineVideoPlayer), findsOneWidget);
    });

    testWidgets('shows close button with correct semantics label', (
      tester,
    ) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 400));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.bySemanticsLabel(l10n.videoMetadataEditCoverCloseSemanticLabel),
        findsOneWidget,
      );
    });

    testWidgets('shows confirm button with correct semantics label', (
      tester,
    ) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 400));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.bySemanticsLabel(l10n.videoMetadataEditCoverConfirmSemanticLabel),
        findsOneWidget,
      );
    });

    testWidgets('shows thumbnail strip with correct semantics label', (
      tester,
    ) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 400));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(
        find.bySemanticsLabel(l10n.videoMetadataEditCoverStripSemanticLabel),
        findsOneWidget,
      );
    });

    testWidgets('thumbnail strip exposes semantic increase/decrease actions', (
      tester,
    ) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);
      final semanticsHandle = tester.ensureSemantics();

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 400));

      final l10n = lookupAppLocalizations(const Locale('en'));
      final stripFinder = find.bySemanticsLabel(
        l10n.videoMetadataEditCoverStripSemanticLabel,
      );
      final stripSemantics = tester.getSemantics(stripFinder);
      final stripData = stripSemantics.getSemanticsData();

      expect(stripData.flagsCollection.isSlider, isTrue);
      expect(stripData.hasAction(SemanticsAction.increase), isTrue);
      expect(stripData.hasAction(SemanticsAction.decrease), isTrue);

      semanticsHandle.dispose();
    });

    testWidgets('tapping close button calls context.pop()', (tester) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 400));

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(
        find.bySemanticsLabel(l10n.videoMetadataEditCoverCloseSemanticLabel),
        warnIfMissed: false,
      );
      await tester.pump();

      verify(() => mockGoRouter.pop<Object?>(any())).called(1);
    });

    testWidgets(
      'tapping confirm with no extracted thumbnail surfaces failure snackbar '
      'and stays on screen',
      (tester) async {
        setUpPlayerChannel();
        addTearDown(tearDownPlayerChannel);

        await tester.pumpWidget(buildWidget());
        await tester.pump(const Duration(milliseconds: 400));

        final l10n = lookupAppLocalizations(const Locale('en'));
        await triggerConfirm(tester);

        for (var i = 0; i < 5; i++) {
          await tester.pump();
        }

        verifyNever(() => mockGoRouter.pop<Object?>(any()));
        expect(
          find.text(l10n.videoMetadataEditCoverFailedSnackbar),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets('confirm button shows the check icon in its idle state', (
      tester,
    ) async {
      setUpPlayerChannel();
      addTearDown(tearDownPlayerChannel);

      await tester.pumpWidget(buildWidget());
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is DivineIconButton && w.icon == DivineIconName.check,
        ),
        findsOneWidget,
      );
    });
  });
}
