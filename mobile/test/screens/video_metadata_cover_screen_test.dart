// ABOUTME: Tests for VideoMetadataCoverScreen widget
// ABOUTME: Verifies rendering, navigation, and cover selection UI

import 'dart:io';

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
import 'package:pro_video_editor/pro_video_editor.dart';

import '../helpers/go_router.dart';

class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;
}

class _TrackingVideoEditorNotifier extends VideoEditorNotifier {
  _TrackingVideoEditorNotifier(this._state);

  final VideoEditorProviderState _state;
  String? capturedThumbnailPath;
  Duration? capturedTimestamp;

  @override
  VideoEditorProviderState build() => _state;

  @override
  void updateCover({
    required String thumbnailPath,
    required Duration thumbnailTimestamp,
  }) {
    capturedThumbnailPath = thumbnailPath;
    capturedTimestamp = thumbnailTimestamp;
  }
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

/// Sets a MethodChannel mock handler.
void _setHandler(
  MethodChannel channel,
  Future<Object?> Function(MethodCall call) handler,
) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, handler);
}

/// Clears a MethodChannel mock handler.
void _clearHandler(MethodChannel channel) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DivineVideoPlayerController.resetIdCounterForTesting();

    // Global divine_video_player channel — handles controller creation.
    _setHandler(const MethodChannel('divine_video_player'), (call) async {
      if (call.method == 'create') return <String, Object?>{'textureId': 1};
      return null;
    });

    // pro_video_editor channel — returns empty thumbnail list so strip
    // generation completes without native FFI calls.
    _setHandler(const MethodChannel('pro_video_editor'), (call) async {
      if (call.method == 'getThumbnails') return <Object?>[];
      return null;
    });
  });

  tearDown(() {
    _clearHandler(const MethodChannel('divine_video_player'));
    _clearHandler(const MethodChannel('pro_video_editor'));
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
            home: VideoMetadataCoverScreen(
              clip: clip ?? _createTestClip(),
            ),
          ),
        ),
      );
    }

    /// Sets up the per-player MethodChannel mock. Must be called at the start
    /// of every testWidgets block that pumps the widget tree.
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

    /// Clears the per-player MethodChannel mock.
    void tearDownPlayerChannel() {
      _clearHandler(const MethodChannel('divine_video_player/player_0'));
      _clearHandler(const MethodChannel('divine_video_player/player_0/events'));
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

      expect(stripData.hasFlag(SemanticsFlag.isSlider), isTrue);
      expect(stripData.hasAction(SemanticsAction.increase), isTrue);
      expect(stripData.hasAction(SemanticsAction.decrease), isTrue);

      expect(
        stripSemantics.label,
        contains(l10n.videoMetadataEditCoverStripSemanticLabel),
      );

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

        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is DivineIconButton && w.icon == DivineIconName.check,
          ),
        );
        // Pump several times: setState → extractThumbnail (returns null) →
        // snackbar surface.
        for (var i = 0; i < 5; i++) {
          await tester.pump();
        }

        // Must NOT have popped: the user needs to retry.
        verifyNever(() => mockGoRouter.pop<Object?>(any()));
        expect(
          find.text(l10n.videoMetadataEditCoverFailedSnackbar),
          findsOneWidget,
        );
        // Confirm icon button is interactable again.
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );

    testWidgets(
      'confirm button shows the check icon in its idle state',
      (tester) async {
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
      },
    );

    testWidgets(
      'tapping confirm with a valid video calls updateCover and pops screen',
      (tester) async {
        final docsDir = Directory('/tmp/documents');
        if (!docsDir.existsSync()) {
          docsDir.createSync(recursive: true);
        }

        // Create a real temp file so VideoThumbnailService.existsSync() passes.
        final tempVideoFile = File(
          '${Directory.systemTemp.path}/cover_test_${DateTime.now().millisecondsSinceEpoch}.mp4',
        );
        tempVideoFile.writeAsBytesSync([0x00, 0x00]);
        addTearDown(() {
          if (tempVideoFile.existsSync()) {
            tempVideoFile.deleteSync();
          }
        });

        final notifier = _TrackingVideoEditorNotifier(
          VideoEditorProviderState(),
        );

        // Return minimal JPEG bytes so thumbnail extraction succeeds.
        _setHandler(const MethodChannel('pro_video_editor'), (call) async {
          if (call.method == 'getThumbnails') {
            return <Object?>[
              Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]),
            ];
          }
          return null;
        });
        addTearDown(
          () => _setHandler(
            const MethodChannel('pro_video_editor'),
            (call) async {
              if (call.method == 'getThumbnails') return <Object?>[];
              return null;
            },
          ),
        );

        setUpPlayerChannel();
        addTearDown(tearDownPlayerChannel);

        final clip = DivineVideoClip(
          id: 'test-clip',
          video: EditorVideo.file(tempVideoFile.path),
          duration: const Duration(seconds: 10),
          recordedAt: DateTime.now(),
          targetAspectRatio: models.AspectRatio.square,
          originalAspectRatio: 9 / 16,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              videoEditorProvider.overrideWith(() => notifier),
            ],
            child: MockGoRouterProvider(
              goRouter: mockGoRouter,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: VideoMetadataCoverScreen(clip: clip),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(
          find.byWidgetPredicate(
            (w) => w is DivineIconButton && w.icon == DivineIconName.check,
          ),
        );

        // Allow real async I/O in _confirm (thumbnail file write) to complete.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });

        // Pump several times so UI updates and pop callback are processed.
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        // thumbnailTimestamp for a 10-second clip with no explicit value is
        // min(5000ms, 210ms) = 210ms (see DivineVideoClip.thumbnailTimestamp).
        expect(notifier.capturedThumbnailPath, isNotNull);
        expect(
          notifier.capturedTimestamp,
          const Duration(milliseconds: 210),
        );
        verify(() => mockGoRouter.pop<Object?>(any())).called(1);
      },
    );

    testWidgets(
      'confirm button shows CircularProgressIndicator while confirming',
      (tester) async {
        _setHandler(const MethodChannel('pro_video_editor'), (call) async {
          if (call.method == 'getThumbnails') {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            return <Object?>[];
          }
          return null;
        });
        addTearDown(
          () => _setHandler(
            const MethodChannel('pro_video_editor'),
            (call) async {
              if (call.method == 'getThumbnails') return <Object?>[];
              return null;
            },
          ),
        );

        setUpPlayerChannel();
        addTearDown(tearDownPlayerChannel);

        await tester.pumpWidget(buildWidget());
        await tester.pump(const Duration(milliseconds: 400));

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(
          find.bySemanticsLabel(
            l10n.videoMetadataEditCoverConfirmSemanticLabel,
          ),
          warnIfMissed: false,
        );
        // Single pump — captures the in-progress state before async completes.
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );
  });
}
