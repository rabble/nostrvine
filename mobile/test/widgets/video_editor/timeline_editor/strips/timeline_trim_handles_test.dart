// ABOUTME: Widget tests for TimelineTrimHandles.
// ABOUTME: Validates handle rendering, drag callbacks, and configurability.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/timeline_trim_handles.dart';

void main() {
  group(TimelineTrimHandles, () {
    Widget buildWidget({
      TrimDragCallback? onLeftDragUpdate,
      TrimDragCallback? onRightDragUpdate,
      VoidCallback? onDragStart,
      VoidCallback? onDragEnd,
      Color? handleColor,
      double height = TimelineConstants.thumbnailStripHeight,
      double handleWidth = TimelineConstants.trimHandleWidth,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: TimelineTrimHandles(
              height: height,
              onLeftDragUpdate: onLeftDragUpdate,
              onRightDragUpdate: onRightDragUpdate,
              onDragStart: onDragStart,
              onDragEnd: onDragEnd,
              handleColor: handleColor ?? VineTheme.accentYellow,
              handleWidth: handleWidth,
              child: const ColoredBox(
                color: Colors.blue,
                child: SizedBox.expand(),
              ),
            ),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $TimelineTrimHandles', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(TimelineTrimHandles), findsOneWidget);
      });

      testWidgets('renders child between handles', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(ColoredBox), findsWidgets);
      });

      testWidgets('renders two GestureDetectors for handles', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byType(GestureDetector), findsNWidgets(2));
      });

      testWidgets('renders border with handle color', (tester) async {
        const color = Colors.red;
        await tester.pumpWidget(buildWidget(handleColor: color));

        final decorated = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox).first,
        );
        final decoration = decorated.decoration as BoxDecoration;
        expect(decoration.border, isNotNull);
        expect(
          (decoration.border! as Border).top.color,
          equals(color),
        );
      });

      testWidgets('uses configured height', (tester) async {
        const height = 80.0;
        await tester.pumpWidget(buildWidget(height: height));

        final box = tester.renderObject<RenderBox>(
          find.byType(TimelineTrimHandles),
        );
        expect(box.size.height, equals(height));
      });
    });

    group('left handle drag', () {
      testWidgets('calls onDragStart on drag begin', (tester) async {
        var started = false;
        await tester.pumpWidget(
          buildWidget(onDragStart: () => started = true),
        );

        final handles = find.byType(GestureDetector);
        final leftHandle = handles.first;

        await tester.drag(leftHandle, const Offset(10, 0));
        await tester.pumpAndSettle();

        expect(started, isTrue);
      });

      testWidgets('calls onLeftDragUpdate with dx', (tester) async {
        final deltas = <double>[];
        await tester.pumpWidget(
          buildWidget(onLeftDragUpdate: deltas.add),
        );

        final handles = find.byType(GestureDetector);
        final leftHandle = handles.first;

        await tester.drag(leftHandle, const Offset(20, 0));
        await tester.pumpAndSettle();

        expect(deltas, isNotEmpty);
      });

      testWidgets('calls onDragEnd on drag end', (tester) async {
        var ended = false;
        await tester.pumpWidget(
          buildWidget(onDragEnd: () => ended = true),
        );

        final handles = find.byType(GestureDetector);
        final leftHandle = handles.first;

        await tester.drag(leftHandle, const Offset(10, 0));
        await tester.pumpAndSettle();

        expect(ended, isTrue);
      });
    });

    group('right handle drag', () {
      testWidgets('calls onRightDragUpdate with dx', (tester) async {
        final deltas = <double>[];
        await tester.pumpWidget(
          buildWidget(onRightDragUpdate: deltas.add),
        );

        final handles = find.byType(GestureDetector);
        final rightHandle = handles.last;

        await tester.drag(rightHandle, const Offset(-20, 0));
        await tester.pumpAndSettle();

        expect(deltas, isNotEmpty);
      });

      testWidgets('calls onDragStart on right handle drag', (
        tester,
      ) async {
        var started = false;
        await tester.pumpWidget(
          buildWidget(onDragStart: () => started = true),
        );

        final handles = find.byType(GestureDetector);
        final rightHandle = handles.last;

        await tester.drag(rightHandle, const Offset(-10, 0));
        await tester.pumpAndSettle();

        expect(started, isTrue);
      });
    });

    group('defaults', () {
      testWidgets('uses $VineTheme accentYellow as default handle color', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());

        final decorated = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox).first,
        );
        final decoration = decorated.decoration as BoxDecoration;
        expect(
          (decoration.border! as Border).top.color,
          equals(VineTheme.accentYellow),
        );
      });
    });
  });
}
