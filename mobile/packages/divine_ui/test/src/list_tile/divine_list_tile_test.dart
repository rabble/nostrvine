import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(DivineListTile, () {
    Widget buildSubject({
      String? subtitle,
      DivineIconName? icon,
      Widget? leading,
      Color? iconColor,
      Color? titleColor,
      DivineIconName trailingIcon = DivineIconName.caretRight,
      double trailingIconSize = 24,
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: DivineListTile(
            title: 'Notifications',
            subtitle: subtitle,
            icon: icon,
            leading: leading,
            iconColor: iconColor,
            titleColor: titleColor,
            trailingIcon: trailingIcon,
            trailingIconSize: trailingIconSize,
            onTap: onTap ?? () {},
          ),
        ),
      );
    }

    testWidgets('renders the title', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('renders the subtitle when given one', (tester) async {
      await tester.pumpWidget(buildSubject(subtitle: 'Pings and mentions'));

      expect(find.text('Pings and mentions'), findsOneWidget);
    });

    testWidgets('omits the subtitle when absent', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(tester.widget<ListTile>(find.byType(ListTile)).subtitle, isNull);
    });

    testWidgets('renders a design-system leading icon', (tester) async {
      await tester.pumpWidget(buildSubject(icon: DivineIconName.bellSimple));

      final leading =
          tester.widget<ListTile>(find.byType(ListTile)).leading! as DivineIcon;
      expect(leading.icon, DivineIconName.bellSimple);
    });

    testWidgets('applies the icon colour override', (tester) async {
      await tester.pumpWidget(
        buildSubject(icon: DivineIconName.trash, iconColor: VineTheme.error),
      );

      final leading =
          tester.widget<ListTile>(find.byType(ListTile)).leading! as DivineIcon;
      expect(leading.color, VineTheme.error);
    });

    testWidgets('renders an arbitrary leading widget', (tester) async {
      await tester.pumpWidget(
        buildSubject(leading: const Icon(Icons.gavel)),
      );

      expect(find.byIcon(Icons.gavel), findsOneWidget);
    });

    testWidgets('has no leading slot without icon or leading', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(tester.widget<ListTile>(find.byType(ListTile)).leading, isNull);
    });

    testWidgets('applies the title colour override', (tester) async {
      await tester.pumpWidget(buildSubject(titleColor: VineTheme.error));

      expect(
        tester.widget<Text>(find.text('Notifications')).style?.color,
        VineTheme.error,
      );
    });

    testWidgets('defaults to a forward caret', (tester) async {
      await tester.pumpWidget(buildSubject());

      final trailing =
          tester.widget<ListTile>(find.byType(ListTile)).trailing!
              as DivineIcon;
      expect(trailing.icon, DivineIconName.caretRight);
      expect(trailing.size, 24);
    });

    testWidgets('takes a custom trailing affordance', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          trailingIcon: DivineIconName.arrowUpRight,
          trailingIconSize: 20,
        ),
      );

      final trailing =
          tester.widget<ListTile>(find.byType(ListTile)).trailing!
              as DivineIcon;
      expect(trailing.icon, DivineIconName.arrowUpRight);
      expect(trailing.size, 20);
    });

    testWidgets('reports taps', (tester) async {
      var tapped = false;
      await tester.pumpWidget(buildSubject(onTap: () => tapped = true));

      await tester.tap(find.byType(DivineListTile));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('keeps a tap-target-sized row', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        tester.getSize(find.byType(ListTile)).height,
        greaterThanOrEqualTo(DivineListTile.minHeight),
      );
    });
  });

  group(DivineSectionHeader, () {
    testWidgets('renders the label', (tester) async {
      // Built from a runtime value on purpose: a const-evaluated widget never
      // executes its constructor, which leaves it uncovered.
      final label = 'network'.toUpperCase();
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: Scaffold(body: DivineSectionHeader(label)),
        ),
      );

      expect(find.text('NETWORK'), findsOneWidget);
    });

    testWidgets('uses the brand accent and tracked-out label style', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: const Scaffold(body: DivineSectionHeader('NETWORK')),
        ),
      );

      final style = tester.widget<Text>(find.text('NETWORK')).style!;
      expect(style.color, VineTheme.vineGreen);
      expect(style.letterSpacing, 1.2);
    });
  });
}
