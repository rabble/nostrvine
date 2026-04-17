// ABOUTME: Widget tests for TimelineTrimHandles.
// ABOUTME: Validates handle rendering, drag callbacks, and configurability.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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

    /// Returns the global top-left of the [TimelineTrimHandles] widget.
    /// Handle hit areas overlap the content by [borderWidth] at each
    /// edge, so dragging from x ≈ 1 hits the left handle and from
    /// x ≈ width - 1 hits the right handle.
    Offset handleOrigin(WidgetTester tester) {
      final box = tester.renderObject<RenderBox>(
        find.byType(TimelineTrimHandles),
      );
      return box.localToGlobal(Offset.zero);
    }

    group('left handle drag', () {
      testWidgets('calls onDragStart on drag begin', (tester) async {
        var started = false;
        await tester.pumpWidget(
          buildWidget(onDragStart: () => started = true),
        );

        final origin = handleOrigin(tester);
        final box = tester.renderObject<RenderBox>(
          find.byType(TimelineTrimHandles),
        );
        final from = origin + Offset(1, box.size.height / 2);

        await tester.dragFrom(from, const Offset(10, 0));
        await tester.pumpAndSettle();

        expect(started, isTrue);
      });

      testWidgets('calls onLeftDragUpdate with dx', (tester) async {
        final deltas = <double>[];
        await tester.pumpWidget(
          buildWidget(onLeftDragUpdate: deltas.add),
        );

        final origin = handleOrigin(tester);
        final box = tester.renderObject<RenderBox>(
          find.byType(TimelineTrimHandles),
        );
        final from = origin + Offset(1, box.size.height / 2);

        await tester.dragFrom(from, const Offset(20, 0));
        await tester.pumpAndSettle();

        expect(deltas, isNotEmpty);
      });

      testWidgets('calls onDragEnd on drag end', (tester) async {
        var ended = false;
        await tester.pumpWidget(
          buildWidget(onDragEnd: () => ended = true),
        );

        final origin = handleOrigin(tester);
        final box = tester.renderObject<RenderBox>(
          find.byType(TimelineTrimHandles),
        );
        final from = origin + Offset(1, box.size.height / 2);

        await tester.dragFrom(from, const Offset(10, 0));
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

        final origin = handleOrigin(tester);
        final box = tester.renderObject<RenderBox>(
          find.byType(TimelineTrimHandles),
        );
        final from = origin + Offset(box.size.width - 1, box.size.height / 2);

        await tester.dragFrom(from, const Offset(-20, 0));
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

        final origin = handleOrigin(tester);
        final box = tester.renderObject<RenderBox>(
          find.byType(TimelineTrimHandles),
        );
        final from = origin + Offset(box.size.width - 1, box.size.height / 2);

        await tester.dragFrom(from, const Offset(-10, 0));
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
