// ABOUTME: Widget tests for VideoEditorMainActionsSheet.
// ABOUTME: Verifies action rendering and callback behavior.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_actions_sheet.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(VideoEditorMainActionsSheet, () {
    testWidgets('renders all action labels', (tester) async {
      await tester.pumpWidget(_buildWidget());

      expect(find.text(l10n.videoEditorCameraLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorLibraryLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorAudioLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorTextLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDrawLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorFilterLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorStickers), findsOneWidget);
    });

    testWidgets('tap on Clips triggers onOpenClipsEditor', (tester) async {
      var openedClips = false;

      await tester.pumpWidget(
        _buildWidget(onOpenClipsEditor: () => openedClips = true),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorOpenLibrarySemanticLabel),
      );
      await tester.pumpAndSettle();

      expect(openedClips, isTrue);
    });

    testWidgets('tap on Audio triggers onOpenMusicLibrary', (tester) async {
      var openedMusic = false;

      await tester.pumpWidget(
        _buildWidget(onOpenMusicLibrary: () => openedMusic = true),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorOpenAudioSemanticLabel),
      );
      await tester.pumpAndSettle();

      expect(openedMusic, isTrue);
    });

    testWidgets('tap on Stickers triggers onAddStickers', (tester) async {
      var addedStickers = false;

      await tester.pumpWidget(
        _buildWidget(onAddStickers: () => addedStickers = true),
      );

      await tester.tap(
        find.bySemanticsLabel(l10n.videoEditorOpenStickerSemanticLabel),
      );
      await tester.pumpAndSettle();

      expect(addedStickers, isTrue);
    });
  });
}

Widget _buildWidget({
  VoidCallback? onOpenClipsEditor,
  VoidCallback? onOpenMusicLibrary,
  VoidCallback? onAddStickers,
}) {
  final editorKey = GlobalKey<ProImageEditorState>();
  final removeAreaKey = GlobalKey();

  final scope = VideoEditorScope(
    editorKey: editorKey,
    removeAreaKey: removeAreaKey,
    onOpenCamera: () {},
    onAddStickers: onAddStickers ?? () {},
    onAdjustVolume: () {},
    onOpenClipsEditor: onOpenClipsEditor ?? () {},
    onAddEditTextLayer: ([layer]) async => null,
    onOpenMusicLibrary: onOpenMusicLibrary ?? () {},
    originalClipAspectRatio: 9 / 16,
    bodySizeNotifier: ValueNotifier(const Size(400, 800)),
    fromLibrary: false,
  );

  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return VideoEditorScope(
            editorKey: scope.editorKey,
            removeAreaKey: scope.removeAreaKey,
            onOpenCamera: () {},
            onAddStickers: scope.onAddStickers,
            onAdjustVolume: scope.onAdjustVolume,
            onOpenClipsEditor: scope.onOpenClipsEditor,
            onAddEditTextLayer: scope.onAddEditTextLayer,
            onOpenMusicLibrary: scope.onOpenMusicLibrary,
            originalClipAspectRatio: scope.originalClipAspectRatio,
            bodySizeNotifier: scope.bodySizeNotifier,
            fromLibrary: scope.fromLibrary,
            child: VideoEditorMainActionsSheet(scope: scope),
          );
        },
      ),
    ),
  );
}
