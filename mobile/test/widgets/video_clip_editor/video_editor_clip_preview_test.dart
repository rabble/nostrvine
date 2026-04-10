// ABOUTME: Widget tests for VideoEditorClipPreview
// ABOUTME: Verifies rendering, thumbnail visibility, and DivineVideoPlayer
// ABOUTME: integration after migration from video_player package

import 'package:divine_ui/divine_ui.dart';
import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/clip_editor/gallery/video_editor_clip_preview.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    DivineVideoPlayerController.resetIdCounterForTesting();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('divine_video_player'),
          (call) async {
            if (call.method == 'create') {
              return <String, Object?>{'textureId': 1};
            }
            return null;
          },
        );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('divine_video_player'),
          null,
        );
  });

  group(VideoEditorClipPreview, () {
    DivineVideoClip createTestClip({String id = 'clip-1'}) {
      return DivineVideoClip(
        id: id,
        video: EditorVideo.file('/test/video.mp4'),
        duration: const Duration(seconds: 5),
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
    }

    Widget buildTestWidget({
      required DivineVideoClip clip,
      bool isCurrentClip = false,
      bool isReordering = false,
      ClipEditorState? initialState,
    }) {
      final bloc = _TestClipEditorBloc(
        initialState: initialState ?? ClipEditorState(clips: [clip]),
      );

      return ProviderScope(
        child: BlocProvider<ClipEditorBloc>.value(
          value: bloc,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 400,
                child: VideoEditorClipPreview(
                  clip: clip,
                  isCurrentClip: isCurrentClip,
                  isReordering: isReordering,
                ),
              ),
            ),
          ),
        ),
      );
    }

    test('can be instantiated', () {
      expect(
        VideoEditorClipPreview(clip: createTestClip()),
        isA<VideoEditorClipPreview>(),
      );
    });

    testWidgets('renders non-current clip with thumbnail', (tester) async {
      final clip = createTestClip();

      await tester.pumpWidget(buildTestWidget(clip: clip));
      await tester.pump();

      expect(find.byType(VideoEditorClipPreview), findsOneWidget);

      // Non-current clip should not render DivineVideoPlayer
      expect(find.byType(DivineVideoPlayer), findsNothing);
    });

    testWidgets(
      'renders $DivineVideoPlayer when isCurrentClip is true',
      (tester) async {
        final clip = createTestClip();

        // Mock the player method channel for player_0
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player/player_0'),
              (call) async => null,
            );

        await tester.pumpWidget(
          buildTestWidget(clip: clip, isCurrentClip: true),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.byType(DivineVideoPlayer), findsOneWidget);

        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              const MethodChannel('divine_video_player/player_0'),
              null,
            );
      },
    );

    testWidgets('shows delete zone border when over delete zone', (
      tester,
    ) async {
      final clip = createTestClip();

      await tester.pumpWidget(
        buildTestWidget(
          clip: clip,
          isCurrentClip: true,
          initialState: ClipEditorState(
            clips: [clip],
            isOverDeleteZone: true,
          ),
        ),
      );
      await tester.pump();

      final animatedContainer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = animatedContainer.decoration as BoxDecoration?;
      final border = decoration?.border as Border?;
      expect(border?.top.color, VineTheme.error);
    });

    testWidgets('shows reordering border when reordering', (tester) async {
      final clip = createTestClip();

      await tester.pumpWidget(
        buildTestWidget(
          clip: clip,
          isCurrentClip: true,
          isReordering: true,
        ),
      );
      await tester.pump();

      final animatedContainer = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      final decoration = animatedContainer.decoration as BoxDecoration?;
      final border = decoration?.border as Border?;
      expect(border?.top.color, VineTheme.accentYellow);
    });

    testWidgets('invokes onTap callback', (tester) async {
      var tapped = false;
      final clip = createTestClip();
      final bloc = _TestClipEditorBloc(
        initialState: ClipEditorState(clips: [clip]),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: BlocProvider<ClipEditorBloc>.value(
            value: bloc,
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SizedBox(
                  width: 200,
                  height: 400,
                  child: VideoEditorClipPreview(
                    clip: clip,
                    onTap: () => tapped = true,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(VideoEditorClipPreview));
      expect(tapped, isTrue);
    });
  });
}

class _TestClipEditorBloc extends ClipEditorBloc {
  _TestClipEditorBloc({
    ClipEditorState initialState = const ClipEditorState(),
  }) {
    emit(initialState);
  }
}
