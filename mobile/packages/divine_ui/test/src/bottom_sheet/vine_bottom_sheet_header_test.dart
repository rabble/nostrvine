// ABOUTME: Tests for VineBottomSheetHeader and VineBottomSheetBadge
// ABOUTME: Verifies header rendering and structure

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VineBottomSheetHeader', () {
    testWidgets('renders title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(title: Text('Test Title')),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
    });

    testWidgets('renders with trailing widget', (tester) async {
      const trailingWidget = Icon(Icons.settings, key: Key('trailing'));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(
              title: Text('Test Title'),
              trailing: trailingWidget,
            ),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      // The real trailing widget, plus the hidden copy that reserves the same
      // width on the empty leading side.
      expect(find.byKey(const Key('trailing')), findsNWidgets(2));
    });

    testWidgets('uses default padding when none is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(title: Text('Test Title')),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(VineBottomSheetHeader),
              matching: find.byType(Padding),
            )
            .first,
      );

      expect(
        padding.padding,
        const EdgeInsetsDirectional.only(start: 16, end: 16, top: 8),
      );
    });

    testWidgets('applies custom padding when provided', (tester) async {
      const customPadding = EdgeInsetsDirectional.only(
        start: 12,
        end: 12,
        top: 4,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(
              title: Text('Test Title'),
              padding: customPadding,
            ),
          ),
        ),
      );

      final padding = tester.widget<Padding>(
        find
            .descendant(
              of: find.byType(VineBottomSheetHeader),
              matching: find.byType(Padding),
            )
            .first,
      );

      expect(padding.padding, customPadding);
    });
    testWidgets('renders with leading widget', (tester) async {
      const leadingWidget = Icon(Icons.close, key: Key('leading'));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(
              title: Text('Test Title'),
              leading: leadingWidget,
            ),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      // The real leading widget, plus the hidden copy that reserves the same
      // width on the empty trailing side.
      expect(find.byKey(const Key('leading')), findsNWidgets(2));
    });

    testWidgets('centers the title when only a leading action is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(
              title: const Text('Test Title'),
              leadingAction: DivineIconButton(
                key: const Key('leading_action'),
                icon: DivineIconName.x,
                onPressed: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('leading_action')), findsNWidgets(2));
      expect(
        tester.getCenter(find.text('Test Title')).dx,
        moreOrLessEquals(
          tester.getCenter(find.byType(VineBottomSheetHeader)).dx,
        ),
      );
    });

    testWidgets('centers the title when only a trailing widget is given', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(
              title: Text('Test Title'),
              // Wider than the 40px box the header used to reserve.
              trailing: SizedBox(width: 120, height: 40, child: Text('Newest')),
            ),
          ),
        ),
      );

      expect(
        tester.getCenter(find.text('Test Title')).dx,
        moreOrLessEquals(
          tester.getCenter(find.byType(VineBottomSheetHeader)).dx,
        ),
      );
    });

    testWidgets('keeps the title centered as the trailing width changes', (
      tester,
    ) async {
      Future<double> pumpTrailingWidth(double width) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: VineBottomSheetHeader(
                title: const Text('Test Title'),
                trailing: SizedBox(width: width, height: 40),
              ),
            ),
          ),
        );
        return tester.getCenter(find.text('Test Title')).dx;
      }

      final narrow = await pumpTrailingWidth(60);
      final wide = await pumpTrailingWidth(160);

      expect(narrow, moreOrLessEquals(wide));
    });

    testWidgets('reserved width does not react to taps', (tester) async {
      var trailingTaps = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(
              title: const Text('Test Title'),
              trailing: GestureDetector(
                key: const Key('trailing'),
                behavior: HitTestBehavior.opaque,
                onTap: () => trailingTaps++,
                child: const SizedBox(width: 120, height: 40),
              ),
            ),
          ),
        ),
      );

      // The reserved copy renders on the empty leading side, so it comes
      // first in the header row; the real trailing widget comes last.
      final copies = find.byKey(const Key('trailing'));
      await tester.tapAt(tester.getCenter(copies.first));

      expect(trailingTaps, isZero);

      await tester.tap(copies.last);

      expect(trailingTaps, equals(1));
    });

    testWidgets('reserved width is hidden from screen readers', (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VineBottomSheetHeader(
              title: const Text('Test Title'),
              trailing: Semantics(
                button: true,
                label: 'Sort comments',
                child: const SizedBox(width: 120, height: 40),
              ),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Sort comments'), findsOneWidget);

      semantics.dispose();
    });
  });
}
