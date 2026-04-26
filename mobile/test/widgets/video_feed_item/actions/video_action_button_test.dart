// ABOUTME: Tests for VideoActionButton base widget.
// ABOUTME: Verifies icon rendering, count display, loading state, tap
// ABOUTME: handling, and accessibility semantics.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_feed_item/actions/video_action_button.dart';

void main() {
  Widget buildSubject({
    DivineIconName icon = DivineIconName.heart,
    String semanticIdentifier = 'test_button',
    String semanticLabel = 'Test button',
    VoidCallback? onPressed,
    Color iconColor = VineTheme.whiteText,
    int count = 0,
    bool isLoading = false,
    String? caption,
    String? labelWhenZero,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: VideoActionButton(
          icon: icon,
          semanticIdentifier: semanticIdentifier,
          semanticLabel: semanticLabel,
          onPressed: onPressed,
          iconColor: iconColor,
          count: count,
          isLoading: isLoading,
          caption: caption,
          labelWhenZero: labelWhenZero,
        ),
      ),
    );
  }

  group(VideoActionButton, () {
    group('renders', () {
      testWidgets('$DivineIcon with specified icon', (tester) async {
        await tester.pumpWidget(buildSubject(icon: DivineIconName.chat));

        // Three DivineIcons render per button: two shadow copies +
        // the foreground glyph. The foreground is always last in the
        // stack, and is the only one with the caller-supplied color
        // (shadows use VineTheme.innerShadow).
        final divineIcon = tester
            .widgetList<DivineIcon>(find.byType(DivineIcon))
            .last;
        expect(divineIcon.icon, equals(DivineIconName.chat));
      });

      testWidgets('$DivineIcon with specified color', (tester) async {
        await tester.pumpWidget(buildSubject(iconColor: Colors.red));

        final divineIcon = tester
            .widgetList<DivineIcon>(find.byType(DivineIcon))
            .last;
        expect(divineIcon.color, equals(Colors.red));
      });

      testWidgets('$GestureDetector fills the 48x48 tap target', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());

        // One GestureDetector wraps the whole tap target.
        expect(find.byType(GestureDetector), findsOneWidget);

        // Tap target is exactly 48x48 regardless of child content.
        final size = tester.getSize(find.byType(GestureDetector));
        expect(size, equals(const Size(48, 48)));
      });
    });

    group('count display', () {
      testWidgets('hides count when count is 0', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.text('0'), findsNothing);
      });

      testWidgets('displays count when greater than 0', (tester) async {
        await tester.pumpWidget(buildSubject(count: 42));

        expect(find.text('42'), findsOneWidget);
      });

      testWidgets('formats large counts compactly', (tester) async {
        await tester.pumpWidget(buildSubject(count: 1500));

        expect(find.text('1.5K'), findsOneWidget);
      });

      testWidgets('renders caption when provided', (tester) async {
        await tester.pumpWidget(buildSubject(caption: 'Auto'));

        expect(find.text('Auto'), findsOneWidget);
      });

      testWidgets('renders labelWhenZero as a placeholder when count is 0', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(labelWhenZero: 'Like'));

        expect(find.text('Like'), findsOneWidget);
      });

      testWidgets('hides labelWhenZero once count goes above 0', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(count: 12, labelWhenZero: 'Like'));

        expect(find.text('12'), findsOneWidget);
        expect(find.text('Like'), findsNothing);
      });

      testWidgets('caption takes precedence over labelWhenZero', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(caption: 'Auto', labelWhenZero: 'Like'),
        );

        expect(find.text('Auto'), findsOneWidget);
        expect(find.text('Like'), findsNothing);
      });
    });

    group('loading state', () {
      testWidgets('shows $CircularProgressIndicator when loading', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(isLoading: true));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(DivineIcon), findsNothing);
      });

      testWidgets('hides count when loading', (tester) async {
        await tester.pumpWidget(buildSubject(isLoading: true, count: 10));

        expect(find.text('10'), findsNothing);
      });

      testWidgets('hides labelWhenZero when loading', (tester) async {
        await tester.pumpWidget(
          buildSubject(isLoading: true, labelWhenZero: 'Like'),
        );

        expect(find.text('Like'), findsNothing);
      });

      testWidgets('disables tap when loading', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          buildSubject(isLoading: true, onPressed: () => tapped = true),
        );

        await tester.tap(find.byType(GestureDetector));
        expect(tapped, isFalse);
      });
    });

    group('interactions', () {
      testWidgets('calls onPressed when tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildSubject(onPressed: () => tapped = true));

        await tester.tap(find.byType(GestureDetector));
        expect(tapped, isTrue);
      });

      testWidgets('does not throw when onPressed is null', (tester) async {
        await tester.pumpWidget(buildSubject());

        await tester.tap(find.byType(GestureDetector));
        // No assertion needed — just verifying no exception is thrown
      });

      testWidgets('captures taps on the caption area, not just the icon', (
        tester,
      ) async {
        var tapped = false;
        await tester.pumpWidget(
          buildSubject(labelWhenZero: 'Like', onPressed: () => tapped = true),
        );

        // The caption sits in the lower half of the 48x48 box. Tapping
        // on it should still fire the action.
        await tester.tap(find.text('Like'));
        expect(tapped, isTrue);
      });
    });

    group('accessibility', () {
      testWidgets('has correct semantics identifier', (tester) async {
        await tester.pumpWidget(
          buildSubject(semanticIdentifier: 'like_button'),
        );

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.identifier == 'like_button',
          ),
        );
        expect(semantics.properties.button, isTrue);
      });

      testWidgets('has correct semantics label', (tester) async {
        await tester.pumpWidget(buildSubject(semanticLabel: 'Like video'));

        final semantics = tester.widget<Semantics>(
          find.byWidgetPredicate(
            (w) => w is Semantics && w.properties.identifier == 'test_button',
          ),
        );
        expect(semantics.properties.label, equals('Like video'));
      });
    });
  });
}
