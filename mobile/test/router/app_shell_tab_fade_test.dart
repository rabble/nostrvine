// ABOUTME: Tests AppShellBranchContainer — the cross-fade between shell tabs
// ABOUTME: All branches stay alive; switching cross-fades; reduced motion snaps

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/router.dart';

const _keys = [
  ValueKey<String>('branch-0'),
  ValueKey<String>('branch-1'),
  ValueKey<String>('branch-2'),
  ValueKey<String>('branch-3'),
];

Widget _buildSubject(ValueListenable<int> currentIndex, {bool reduce = false}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: ValueListenableBuilder<int>(
        valueListenable: currentIndex,
        builder: (context, index, _) => AppShellBranchContainer(
          currentIndex: index,
          children: [
            for (final key in _keys) ColoredBox(key: key, color: Colors.black),
          ],
        ),
      ),
    ),
  );
}

/// Rendered opacity of the branch [key] (read off the [FadeTransition] that
/// [AnimatedOpacity] builds internally).
double _opacityOf(WidgetTester tester, Key key) {
  // `.first` = the closest FadeTransition (the one AnimatedOpacity builds);
  // the MaterialApp page transition adds another higher up.
  final fade = tester.widget<FadeTransition>(
    find
        .ancestor(of: find.byKey(key), matching: find.byType(FadeTransition))
        .first,
  );
  return fade.opacity.value;
}

void main() {
  group(AppShellBranchContainer, () {
    testWidgets('keeps every branch mounted, only the active one opaque', (
      tester,
    ) async {
      final index = ValueNotifier<int>(0);
      addTearDown(index.dispose);

      await tester.pumpWidget(_buildSubject(index));
      await tester.pumpAndSettle();

      for (final key in _keys) {
        expect(find.byKey(key), findsOneWidget); // all alive
      }
      expect(_opacityOf(tester, _keys[0]), 1.0);
      expect(_opacityOf(tester, _keys[1]), 0.0);
      expect(_opacityOf(tester, _keys[3]), 0.0);
    });

    testWidgets('cross-fades the outgoing and incoming branches on switch', (
      tester,
    ) async {
      final index = ValueNotifier<int>(0);
      addTearDown(index.dispose);

      await tester.pumpWidget(_buildSubject(index));
      await tester.pumpAndSettle();

      index.value = 1;
      await tester.pump(); // start the implicit animations
      await tester.pump(const Duration(milliseconds: 40)); // mid (< fade dur)

      expect(tester.hasRunningAnimations, isTrue);
      final outgoing = _opacityOf(tester, _keys[0]);
      final incoming = _opacityOf(tester, _keys[1]);
      expect(outgoing, greaterThan(0.0));
      expect(outgoing, lessThan(1.0));
      expect(incoming, greaterThan(0.0));
      expect(incoming, lessThan(1.0));

      await tester.pumpAndSettle();
      expect(_opacityOf(tester, _keys[0]), 0.0);
      expect(_opacityOf(tester, _keys[1]), 1.0);
      // Branches are never torn down across the switch.
      expect(find.byKey(_keys[0]), findsOneWidget);
    });

    testWidgets('cross-fades between two non-home tabs', (tester) async {
      final index = ValueNotifier<int>(1);
      addTearDown(index.dispose);

      await tester.pumpWidget(_buildSubject(index));
      await tester.pumpAndSettle();

      index.value = 2;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40)); // mid (< fade dur)

      expect(_opacityOf(tester, _keys[1]), greaterThan(0.0));
      expect(_opacityOf(tester, _keys[1]), lessThan(1.0));
      expect(_opacityOf(tester, _keys[2]), greaterThan(0.0));
      expect(_opacityOf(tester, _keys[2]), lessThan(1.0));

      await tester.pumpAndSettle();
      expect(_opacityOf(tester, _keys[2]), 1.0);
    });

    testWidgets('reduced motion snaps without a running animation', (
      tester,
    ) async {
      final index = ValueNotifier<int>(0);
      addTearDown(index.dispose);

      await tester.pumpWidget(_buildSubject(index, reduce: true));
      await tester.pumpAndSettle();

      index.value = 2;
      await tester.pump();

      expect(tester.hasRunningAnimations, isFalse);
      expect(_opacityOf(tester, _keys[0]), 0.0);
      expect(_opacityOf(tester, _keys[2]), 1.0);
    });
  });
}
