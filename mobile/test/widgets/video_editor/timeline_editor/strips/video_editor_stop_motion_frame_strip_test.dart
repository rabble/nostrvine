import 'dart:convert';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_stop_motion_frame_strip.dart';

void main() {
  // 1x1 transparent PNG.
  final pngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk'
    '+M8AAAMBAQDJ/IY1AAAAAElFTkSuQmCC',
  );

  late Directory tempDir;
  late List<StopMotionClipFrame> frames;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('frame_strip_test');
    frames = [
      for (final name in ['a', 'b', 'c'])
        StopMotionClipFrame(
          path: (File(
            '${tempDir.path}/$name.png',
          )..writeAsBytesSync(pngBytes)).path,
          // 0.5s each → wide, easily tappable tiles at the test pps.
          duration: const Duration(milliseconds: 500),
        ),
    ];
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  Future<void> pump(
    WidgetTester tester, {
    required ValueChanged<int> onFrameTapped,
    int? selectedFrameIndex,
    bool isMultiSelectMode = false,
    Set<int> selectedFrameIndexes = const {},
    ValueChanged<int>? onBlockMove,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: VideoEditorStopMotionFrameStrip(
              frames: frames,
              pixelsPerSecond: 100,
              selectedFrameIndex: selectedFrameIndex,
              isMultiSelectMode: isMultiSelectMode,
              selectedFrameIndexes: selectedFrameIndexes,
              onBlockMove: onBlockMove,
              onFrameTapped: onFrameTapped,
              onReorder: (_, _) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders one tile per captured still', (tester) async {
    await pump(tester, onFrameTapped: (_) {});
    expect(find.byType(Image), findsNWidgets(3));
  });

  testWidgets('renders duplicated stills without a key collision', (
    tester,
  ) async {
    // Duplicating a still reuses its file path; sibling tile keys must stay
    // unique or the Stack throws "duplicate keys found".
    frames = [...frames, frames[1]];
    await pump(tester, onFrameTapped: (_) {});

    expect(tester.takeException(), isNull);
    expect(find.byType(Image), findsNWidgets(4));
  });

  testWidgets('tapping a tile reports its index', (tester) async {
    int? tapped;
    await pump(tester, onFrameTapped: (index) => tapped = index);

    await tester.tap(find.byType(Image).at(1));
    expect(tapped, 1);
  });

  testWidgets('marks the selected tile via semantics', (tester) async {
    await pump(tester, onFrameTapped: (_) {}, selectedFrameIndex: 2);

    final l10n = lookupAppLocalizations(const Locale('en'));
    expect(
      tester.getSemantics(
        find.bySemanticsLabel(
          l10n.videoEditorStopMotionFrameSemanticLabel(3, 3),
        ),
      ),
      isSemantics(isSelected: true),
    );
  });

  testWidgets('selected tile paints a visible accent-yellow border', (
    tester,
  ) async {
    await pump(tester, onFrameTapped: (_) {}, selectedFrameIndex: 1);

    final selectedBoxes = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .where((box) {
          final decoration = box.decoration;
          return decoration is BoxDecoration &&
              decoration.border is Border &&
              (decoration.border! as Border).top.color ==
                  VineTheme.accentYellow;
        })
        .toList();

    expect(selectedBoxes, hasLength(1));
    // Foreground position — a background border would be painted underneath
    // the image that fills the same box and never be visible.
    expect(selectedBoxes.single.position, DecorationPosition.foreground);
    expect(
      ((selectedBoxes.single.decoration as BoxDecoration).border! as Border)
          .top
          .width,
      2,
    );
  });

  testWidgets('multi-select highlights every selected tile', (tester) async {
    await pump(
      tester,
      onFrameTapped: (_) {},
      isMultiSelectMode: true,
      selectedFrameIndexes: {0, 2},
    );

    final selectedBoxes = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .where((box) {
          final decoration = box.decoration;
          return decoration is BoxDecoration &&
              decoration.border is Border &&
              (decoration.border! as Border).top.color ==
                  VineTheme.accentYellow;
        });

    expect(selectedBoxes, hasLength(2));
  });

  testWidgets('multi-select taps still report the tile index', (tester) async {
    int? tapped;
    await pump(
      tester,
      onFrameTapped: (index) => tapped = index,
      isMultiSelectMode: true,
    );

    await tester.tap(find.byType(Image).at(2));
    expect(tapped, 2);
  });

  testWidgets('block drag reports the drop slot among remaining stills', (
    tester,
  ) async {
    int? movedToSlot;
    await pump(
      tester,
      onFrameTapped: (_) {},
      isMultiSelectMode: true,
      selectedFrameIndexes: {0},
      onBlockMove: (slot) => movedToSlot = slot,
    );

    // Long-press the selected first tile, drag past the other two (each 50px
    // wide at 100 pps x 0.5s), release: the block lands at the end (slot 2).
    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Image).at(0)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    // Rebuild so the drag-in-progress move/end handlers are wired.
    await tester.pump();
    // The block pickup shows the accent-yellow insertion marker.
    expect(
      find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == VineTheme.accentYellow,
      ),
      findsOneWidget,
      reason: 'insertion marker',
    );
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(movedToSlot, 2);
  });

  testWidgets('block drag does not start on an unselected tile', (
    tester,
  ) async {
    int? movedToSlot;
    await pump(
      tester,
      onFrameTapped: (_) {},
      isMultiSelectMode: true,
      selectedFrameIndexes: {2},
      onBlockMove: (slot) => movedToSlot = slot,
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(Image).at(0)),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(movedToSlot, isNull);
  });
}
