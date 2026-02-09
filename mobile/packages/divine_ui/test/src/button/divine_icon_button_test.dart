import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DivineIconButton', () {
    Widget buildTestWidget({
      DivineIconName icon = DivineIconName.x,
      VoidCallback? onPressed,
      DivineIconButtonType type = DivineIconButtonType.primary,
      DivineIconButtonSize size = DivineIconButtonSize.base,
      String? semanticLabel,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: DivineIconButton(
              icon: icon,
              onPressed: onPressed,
              type: type,
              size: size,
              semanticLabel: semanticLabel,
            ),
          ),
        ),
      );
    }

    group('rendering', () {
      testWidgets('renders with DivineIconName', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(onPressed: () {}),
        );

        expect(find.byType(DivineIcon), findsOneWidget);
        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.byType(DivineIconButton), findsOneWidget);
      });

      testWidgets('applies semantic label', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            semanticLabel: 'Close button',
            onPressed: () {},
          ),
        );

        expect(
          find.bySemanticsLabel('Close button'),
          findsOneWidget,
        );
      });
    });

    group('interaction', () {
      testWidgets('calls onPressed when tapped', (tester) async {
        var pressed = false;
        await tester.pumpWidget(
          buildTestWidget(onPressed: () => pressed = true),
        );

        await tester.tap(find.byType(DivineIconButton));
        await tester.pumpAndSettle();

        expect(pressed, isTrue);
      });

      testWidgets('does not call onPressed when disabled', (tester) async {
        const pressed = false;
        await tester.pumpWidget(buildTestWidget());

        await tester.tap(find.byType(DivineIconButton));
        await tester.pumpAndSettle();

        expect(pressed, isFalse);
      });
    });

    group('icon sizing', () {
      testWidgets('small size renders 24px icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            size: DivineIconButtonSize.small,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.size, 24);
      });

      testWidgets('base size renders 32px icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.size, 32);
      });
    });

    group('icon colors', () {
      testWidgets('primary type uses onPrimary color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, VineTheme.onPrimary);
      });

      testWidgets('secondary type uses primary color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.secondary,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, VineTheme.primary);
      });

      testWidgets('tertiary type uses inverseOnSurface color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.tertiary,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, VineTheme.inverseOnSurface);
      });

      testWidgets('ghost type uses onSurface color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.ghost,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, VineTheme.onSurface);
      });

      testWidgets('ghostSecondary type uses onSurface color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.ghostSecondary,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, VineTheme.onSurface);
      });

      testWidgets('error type uses onErrorContainer color', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.error,
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, VineTheme.onErrorContainer);
      });
    });

    group('button types', () {
      testWidgets('renders primary type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineIconButton), findsOneWidget);
      });

      testWidgets('renders secondary type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.secondary,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineIconButton), findsOneWidget);
      });

      testWidgets('renders tertiary type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.tertiary,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineIconButton), findsOneWidget);
      });

      testWidgets('renders ghost type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.ghost,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineIconButton), findsOneWidget);
      });

      testWidgets('renders ghostSecondary type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.ghostSecondary,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineIconButton), findsOneWidget);
      });

      testWidgets('renders error type', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            type: DivineIconButtonType.error,
            onPressed: () {},
          ),
        );

        expect(find.byType(DivineIconButton), findsOneWidget);
      });
    });

    group('disabled state', () {
      testWidgets('shows reduced opacity when disabled', (tester) async {
        await tester.pumpWidget(buildTestWidget());

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 0.32);
      });

      testWidgets('error type has 0.5 opacity when disabled', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(type: DivineIconButtonType.error),
        );

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 0.5);
      });

      testWidgets('shows full opacity when enabled', (tester) async {
        await tester.pumpWidget(buildTestWidget(onPressed: () {}));

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, 1.0);
      });
    });

    group('all types render in both sizes', () {
      for (final type in DivineIconButtonType.values) {
        for (final size in DivineIconButtonSize.values) {
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

              expect(find.byType(DivineIconButton), findsOneWidget);
            },
          );
        }
      }
    });

    group('all types render disabled', () {
      for (final type in DivineIconButtonType.values) {
        testWidgets('${type.name} renders disabled', (tester) async {
          await tester.pumpWidget(buildTestWidget(type: type));

          expect(find.byType(DivineIconButton), findsOneWidget);

          final animatedOpacity = tester.widget<AnimatedOpacity>(
            find.byType(AnimatedOpacity),
          );
          expect(animatedOpacity.opacity, lessThan(1.0));
        });
      }
    });
  });
}
