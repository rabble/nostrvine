// ABOUTME: Widget tests for VideoEditorMainBottomBar.
// ABOUTME: Verifies visible actions and callback wiring via VideoEditorScope.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group(VideoEditorMainBottomBar, () {
    testWidgets('renders core action labels', (tester) async {
      await tester.pumpWidget(_buildWidget());

      expect(find.text(l10n.videoEditorLibraryLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorTextLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorDrawLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorVolumeLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorFilterLabel), findsOneWidget);
    });

    testWidgets('tapping Clips calls onOpenClipsEditor', (tester) async {
      var clipsTapped = false;

      await tester.pumpWidget(
        _buildWidget(onOpenClipsEditor: () => clipsTapped = true),
      );

      await tester.tap(find.bySemanticsLabel(l10n.videoEditorLibraryLabel));
      await tester.pump();

      expect(clipsTapped, isTrue);
    });

    testWidgets('tapping Volume calls onAdjustVolume', (tester) async {
      var volumeTapped = false;

      await tester.pumpWidget(
        _buildWidget(onAdjustVolume: () => volumeTapped = true),
      );

      await tester.tap(find.bySemanticsLabel(l10n.videoEditorVolumeLabel));
      await tester.pump();

      expect(volumeTapped, isTrue);
    });
  });
}

Widget _buildWidget({
  VoidCallback? onOpenClipsEditor,
  VoidCallback? onAdjustVolume,
}) {
  final editorKey = GlobalKey<ProImageEditorState>();
  final removeAreaKey = GlobalKey();

  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: VideoEditorScope(
      editorKey: editorKey,
      removeAreaKey: removeAreaKey,
      onOpenCamera: () {},
      onAddStickers: () {},
      onAdjustVolume: onAdjustVolume ?? () {},
      onOpenClipsEditor: onOpenClipsEditor ?? () {},
      onAddEditTextLayer: ([layer]) async => null,
      onOpenMusicLibrary: () {},
      originalClipAspectRatio: 9 / 16,
      bodySizeNotifier: ValueNotifier(const Size(400, 800)),
      fromLibrary: false,
      child: const Scaffold(body: VideoEditorMainBottomBar()),
    ),
  );
}
