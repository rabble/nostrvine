import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DivineButton', () {
    Widget buildTestWidget({
      String label = 'Test',
      VoidCallback? onPressed,
      DivineButtonType type = DivineButtonType.primary,
      DivineButtonSize size = DivineButtonSize.base,
      DivineIconName? leadingIcon,
      DivineIconName? trailingIcon,
      bool expanded = false,
      bool isLoading = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: DivineButton(
              label: label,
              onPressed: onPressed,
              type: type,
              size: size,
              leadingIcon: leadingIcon,
              trailingIcon: trailingIcon,
              expanded: expanded,
              isLoading: isLoading,
            ),
          ),
        ),
      );
    }

    group('rendering', () {
      testWidgets('renders with label', (tester) async {
        await tester.pumpWidget(buildTestWidget(label: 'Click Me'));

        expect(find.text('Click Me'), findsOneWidget);
        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('renders leading icon when provided', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            leadingIcon: DivineIconName.envelope,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineIcon), findsOneWidget);
        expect(find.byType(SvgPicture), findsOneWidget);
      });

      testWidgets('renders trailing icon when provided', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            trailingIcon: DivineIconName.arrowRight,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineIcon), findsOneWidget);
      });

      testWidgets('renders both icons when provided', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            leadingIcon: DivineIconName.envelope,
            trailingIcon: DivineIconName.arrowRight,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineIcon), findsNWidgets(2));
      });
    });

    group('icon colors', () {
      testWidgets('primary type icon uses onPrimary color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            leadingIcon: DivineIconName.envelope,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, VineTheme.onPrimary);
      });

      testWidgets('secondary type icon uses primary color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineButtonType.secondary,
            leadingIcon: DivineIconName.key,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, VineTheme.primary);
      });

      testWidgets('tertiary type icon uses inverseOnSurface color', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineButtonType.tertiary,
            leadingIcon: DivineIconName.gear,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, VineTheme.inverseOnSurface);
      });

      testWidgets('ghost type icon uses onSurface color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineButtonType.ghost,
            leadingIcon: DivineIconName.x,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, VineTheme.onSurface);
      });

      testWidgets('error type icon uses onErrorContainer color', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineButtonType.error,
            leadingIcon: DivineIconName.trash,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, VineTheme.onErrorContainer);
      });
    });

    group('icon sizing', () {
      testWidgets('base size renders 24px icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            leadingIcon: DivineIconName.envelope,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.size, 24);
      });

      testWidgets('small size renders 20px icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            size: DivineButtonSize.small,
            leadingIcon: DivineIconName.envelope,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.size, 20);
      });
    });

    group('interaction', () {
      testWidgets('calls onPressed when tapped', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildTestWidget(onPressed: () => pressed = true),
        );

        await tester.tap(find.byType(DivineButton));
        await tester.pumpAndSettle();

        expect(pressed, isTrue);
      });

      testWidgets('does not call onPressed when disabled', (tester) async {
        const pressed = false;
        await tester.pumpWidget(
          buildTestWidget(),
        );

        await tester.tap(find.byType(DivineButton));
        await tester.pumpAndSettle();

        expect(pressed, isFalse);
      });
    });

    group('button types', () {
      testWidgets('renders primary type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('renders secondary type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineButtonType.secondary,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('renders tertiary type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineButtonType.tertiary,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('renders ghost type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineButtonType.ghost,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('renders ghostSecondary type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineButtonType.ghostSecondary,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('renders link type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineButtonType.link,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('renders error type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineButtonType.error,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineButton), findsOneWidget);
      });
    });

    group('button sizes', () {
      testWidgets('renders small size', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            size: DivineButtonSize.small,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineButton), findsOneWidget);
      });

      testWidgets('renders base size', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineButton), findsOneWidget);
      });
    });

    group('disabled state', () {
      testWidgets('shows reduced opacity when disabled', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(),
        );

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 0.32);
      });

      testWidgets('error type has 0.5 opacity when disabled', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineButtonType.error,
          ),
        );

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 0.5);
      });

      testWidgets('shows full opacity when enabled', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(onPressed: () {}),
        );

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 1.0);
      });
    });

    group('expanded mode', () {
      testWidgets('expands to fill width when expanded is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            expanded: true,
            onPressed: () {},
          ),
        );

        final sizedBox = tester.widget<SizedBox>(
          find.ancestor(
            of: find.byType(AnimatedOpacity),
            matching: find.byType(SizedBox),
          ),
        );
        expect(sizedBox.width, double.infinity);
      });
    });

    group('all types render in both sizes', () {
      for (final type in DivineButtonType.values) {
        for (final size in DivineButtonSize.values) {
          testWidgets(
            '${type.name} renders in ${size.name} size',
            (tester) async {
              await tester.pumpWidget(
                buildTestWidget(
                  type: type,
                  size: size,
                  onPressed: () {},
                ),
              );

              expect(find.byType(DivineButton), findsOneWidget);
            },
          );
        }
      }
    });

    group('loading state', () {
      testWidgets('renders CircularProgressIndicator when isLoading', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            isLoading: true,
            onPressed: () {},
          ),
        );

        expect(
          find.byType(CircularProgressIndicator),
          findsOneWidget,
        );
      });

      testWidgets('does not render leading icon when isLoading', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            isLoading: true,
            leadingIcon: DivineIconName.envelope,
            onPressed: () {},
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(DivineIcon), findsNothing);
      });

      testWidgets('shows reduced opacity when isLoading', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            isLoading: true,
            onPressed: () {},
          ),
        );

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 0.32);
      });
    });

    group('all types render disabled', () {
      for (final type in DivineButtonType.values) {
        testWidgets('${type.name} renders disabled', (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              type: type,
            ),
          );

          expect(find.byType(DivineButton), findsOneWidget);

          final animatedOpacity = tester.widget<AnimatedOpacity>(
            find.byType(AnimatedOpacity),
          );
          expect(animatedOpacity.opacity, lessThan(1.0));
        });
      }
    });
  });

  group('DivineTextLink', () {
    Widget buildTestWidget({
      String text = 'Link',
      VoidCallback? onTap,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: DivineTextLink(
              text: text,
              onTap: onTap,
            ),
          ),
        ),
      );
    }

    testWidgets('renders with text', (tester) async {
      await tester.pumpWidget(buildTestWidget(text: 'Click here'));

      expect(find.text('Click here'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        buildTestWidget(onTap: () => tapped = true),
      );

      await tester.tap(find.byType(DivineTextLink));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('does not call onTap when disabled', (tester) async {
      const tapped = false;
      await tester.pumpWidget(buildTestWidget());

      await tester.tap(find.byType(DivineTextLink));
      await tester.pumpAndSettle();

      expect(tapped, isFalse);
    });

    group('span', () {
      testWidgets('creates TextSpan with correct text', (tester) async {
        final span = DivineTextLink.span(
          text: 'Link',
          onTap: () {},
        );

        expect(span.text, 'Link');
        expect(span.recognizer, isA<TapGestureRecognizer>());
      });

      testWidgets('span has no recognizer when onTap is null', (tester) async {
        final span = DivineTextLink.span(
          text: 'Disabled Link',
          onTap: null,
        );

        expect(span.text, 'Disabled Link');
        expect(span.recognizer, isNull);
      });

      testWidgets('span recognizer calls onTap', (tester) async {
        var tapped = false;
        final span = DivineTextLink.span(
          text: 'Link',
          onTap: () => tapped = true,
        );

        (span.recognizer! as TapGestureRecognizer).onTap!();

        expect(tapped, isTrue);
      });
    });
  });
}
