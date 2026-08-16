import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'accessibility_guidelines.dart';

void _noop() {}

/// Runs [check] and returns the failure it threw, or `null` if it passed.
///
/// `expectLater(future, throwsA(...))` cannot be used here: the check has
/// already started async work under `TestAsyncUtils`, and starting a second
/// guarded operation before awaiting the first trips `guardSync`.
Future<TestFailure?> _failureFrom(Future<void> Function() check) async {
  try {
    await check();
    return null;
  } on TestFailure catch (failure) {
    return failure;
  }
}

Widget _app(Widget child, {ThemeData? theme, Color? background}) => MaterialApp(
  theme: theme ?? VineTheme.theme,
  home: Scaffold(
    backgroundColor: background,
    body: Center(child: child),
  ),
);

/// A tap target of [side] logical pixels, optionally announcing [label].
class _TapTarget extends StatelessWidget {
  const _TapTarget({required this.side, this.label});

  final double side;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: side,
      child: Semantics(
        label: label,
        button: true,
        child: GestureDetector(onTap: _noop, child: const SizedBox.expand()),
      ),
    );
  }
}

/// Draws label text in the same colour as the surface behind it in light mode,
/// and in a legible colour in dark mode.
///
/// Deliberately inverted so exactly one appearance fails, which is what makes
/// the two-appearance sweep worth running.
class _LightModeContrastRegression extends StatelessWidget {
  const _LightModeContrastRegression();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      'appearance-sensitive label',
      style: TextStyle(
        fontSize: 14,
        color: isDark ? Colors.black : Colors.white,
      ),
    );
  }
}

void main() {
  group('expectMeetsAccessibilityGuidelines', () {
    testWidgets('passes for a compliant control', (tester) async {
      await tester.pumpWidget(
        _app(const DivineButton(label: 'Continue', onPressed: _noop)),
      );

      await expectMeetsAccessibilityGuidelines(tester);
    });

    testWidgets('fails when a tap target is under 48dp', (tester) async {
      await tester.pumpWidget(_app(const _TapTarget(side: 20, label: 'Tiny')));

      final failure = await _failureFrom(
        () => expectMeetsAccessibilityGuidelines(
          tester,
          guidelines: const [androidTapTargetGuideline],
        ),
      );

      expect(failure, isNotNull);
    });

    testWidgets('fails when a tap target is under 44pt', (tester) async {
      await tester.pumpWidget(_app(const _TapTarget(side: 20, label: 'Tiny')));

      final failure = await _failureFrom(
        () => expectMeetsAccessibilityGuidelines(
          tester,
          guidelines: const [iOSTapTargetGuideline],
        ),
      );

      expect(failure, isNotNull);
    });

    testWidgets('fails when a tappable node announces nothing', (tester) async {
      await tester.pumpWidget(_app(const _TapTarget(side: 60)));

      final failure = await _failureFrom(
        () => expectMeetsAccessibilityGuidelines(
          tester,
          guidelines: const [labeledTapTargetGuideline],
        ),
      );

      expect(failure, isNotNull);
    });

    testWidgets('fails when text does not meet WCAG AA contrast', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const Text(
            'barely visible label',
            style: TextStyle(fontSize: 14, color: Colors.white),
          ),
          background: Colors.white,
        ),
      );

      final failure = await _failureFrom(
        () => expectMeetsAccessibilityGuidelines(
          tester,
          guidelines: const [textContrastGuideline],
        ),
      );

      expect(failure, isNotNull);
    });

    testWidgets('checks contrast against real VineTheme typography', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(Text('legible label', style: VineTheme.bodyMediumFont())),
      );

      await expectMeetsAccessibilityGuidelines(
        tester,
        guidelines: const [textContrastGuideline],
      );
    });
  });

  group('expectMeetsAccessibilityGuidelinesInBothAppearances', () {
    testWidgets('passes when a control is compliant in both appearances', (
      tester,
    ) async {
      await expectMeetsAccessibilityGuidelinesInBothAppearances(
        tester,
        (theme) => _app(
          const DivineButton(label: 'Continue', onPressed: _noop),
          theme: theme,
        ),
      );
    });

    testWidgets(
      'fails on a contrast regression that only lands in light mode',
      (
        tester,
      ) async {
        final failure = await _failureFrom(
          () => expectMeetsAccessibilityGuidelinesInBothAppearances(
            tester,
            (theme) => _app(
              const _LightModeContrastRegression(),
              theme: theme,
              background: Colors.white,
            ),
            guidelines: const [textContrastGuideline],
          ),
        );

        expect(failure, isNotNull);
        expect(failure.toString(), contains('light appearance'));
      },
    );
  });
}
