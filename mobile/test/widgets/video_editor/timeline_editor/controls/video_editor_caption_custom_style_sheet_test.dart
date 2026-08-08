// ABOUTME: Tests accessibility semantics for the custom caption-style sheet.
// ABOUTME: Verifies color swatches expose their precise RGB values and action.

import 'dart:ui' show SemanticsAction, Tristate;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_caption_custom_style_sheet.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show LayerBackgroundMode;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('custom color swatch exposes RGB semantics', (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const customColor = Color.fromARGB(255, 100, 20, 20);
    final initial = CaptionCustomStyle.initial().copyWith(
      color: customColor,
      colorMode: LayerBackgroundMode.onlyColor,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: VineTheme.theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showCaptionCustomStyleSheet(
                context,
                initial: initial,
              ),
              child: const Text('Open style sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open style sheet'));
    await tester.pump(const Duration(milliseconds: 300));

    final semantics = tester.getSemantics(
      find.bySemanticsLabel('Color picker, RGB 100, 20, 20'),
    );
    final data = semantics.getSemanticsData();

    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isSelected, Tristate.isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
  });
}
