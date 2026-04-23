// ABOUTME: Unit and widget tests for VideoEditorScope.
// ABOUTME: Verifies scale calculation and InheritedWidget access.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
  group(VideoEditorScope, () {
    test('calculateFittedBoxScale returns 1.0 for zero size', () {
      final scale = VideoEditorScope.calculateFittedBoxScale(Size.zero, 9 / 16);
      expect(scale, equals(1.0));
    });

    test('calculateFittedBoxScale returns expected positive scale', () {
      final scale = VideoEditorScope.calculateFittedBoxScale(
        const Size(400, 800),
        9 / 16,
      );

      expect(scale, greaterThan(0));
    });

    testWidgets('of returns nearest scope from context', (tester) async {
      final editorKey = GlobalKey<ProImageEditorState>();
      final removeAreaKey = GlobalKey();
      late VideoEditorScope resolvedScope;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: VideoEditorScope(
            editorKey: editorKey,
            removeAreaKey: removeAreaKey,
            onOpenCamera: () {},
            onAddStickers: () {},
            onAdjustVolume: () {},
            onOpenClipsEditor: () {},
            onAddEditTextLayer: ([layer]) async => null,
            onOpenMusicLibrary: () {},
            originalClipAspectRatio: 9 / 16,
            bodySizeNotifier: ValueNotifier(const Size(400, 800)),
            fromLibrary: false,
            child: Builder(
              builder: (context) {
                resolvedScope = VideoEditorScope.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      expect(resolvedScope.editorKey, equals(editorKey));
      expect(resolvedScope.removeAreaKey, equals(removeAreaKey));
    });
  });
}
