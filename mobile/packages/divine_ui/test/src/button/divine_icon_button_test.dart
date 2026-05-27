import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DivineIconButton', () {
    Widget buildTestWidget({
      DivineIconName icon = DivineIconName.x,
      VoidCallback? onPressed,
      VoidCallback? onLongPress,
      DivineIconButtonType type = DivineIconButtonType.primary,
      DivineIconButtonSize size = DivineIconButtonSize.base,
      Color? backgroundColor,
      Color? foregroundColor,
      String? semanticLabel,
      String? semanticLongPressHint,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: DivineIconButton(
              icon: icon,
              onPressed: onPressed,
              onLongPress: onLongPress,
              type: type,
              size: size,
              backgroundColor: backgroundColor,
              foregroundColor: foregroundColor,
              semanticLabel: semanticLabel,
              semanticLongPressHint: semanticLongPressHint,
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

      testWidgets('applies semantic long-press hint when set', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            semanticLongPressHint: 'Mute all tracks',
            onLongPress: () {},
          ),
        );

        final semantics = tester.getSemantics(find.byType(DivineIconButton));
        expect(semantics.hintOverrides?.onLongPressHint, 'Mute all tracks');
        expect(
          semantics.getSemanticsData().hasAction(SemanticsAction.longPress),
          isTrue,
        );
      });

      testWidgets(
        'has no long-press hint when semanticLongPressHint is null',
        (tester) async {
          await tester.pumpWidget(buildTestWidget(onPressed: () {}));

          final semantics = tester.getSemantics(
            find.byType(DivineIconButton),
          );
          expect(semantics.hintOverrides?.onLongPressHint, isNull);
        },
      );
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

      testWidgets('calls onLongPress when long-pressed', (tester) async {
        var longPressed = false;
        await tester.pumpWidget(
          buildTestWidget(
            onPressed: () {},
            onLongPress: () => longPressed = true,
          ),
        );

        await tester.longPress(find.byType(DivineIconButton));
        await tester.pumpAndSettle();

        expect(longPressed, isTrue);
      });

      testWidgets(
        'is enabled and fires onLongPress when only onLongPress is set',
        (tester) async {
          var longPressed = false;
          await tester.pumpWidget(
            buildTestWidget(onLongPress: () => longPressed = true),
          );

          await tester.longPress(find.byType(DivineIconButton));
          await tester.pumpAndSettle();

          expect(longPressed, isTrue);
        },
      );
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

      testWidgets('base size renders 24px icon', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            onPressed: () {},
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.size, 24);
      });
    });

    group('icon colors', () {
      testWidgets('foregroundColor override takes precedence', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            onPressed: () {},
            foregroundColor: Colors.purple,
          ),
        );

        final divineIcon = tester.widget<DivineIcon>(
          find.byType(DivineIcon),
        );
        expect(divineIcon.color, Colors.purple);
      });

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

    group('background colors', () {
      testWidgets('backgroundColor override takes precedence', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            onPressed: () {},
            backgroundColor: Colors.orange,
          ),
        );

        final ink = tester.widget<Ink>(find.byType(Ink));
        final decoration = ink.decoration! as BoxDecoration;
        expect(decoration.color, Colors.orange);
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

    group('border-compensating outer padding', () {
      // No-border variants wrap their content in a 2px Padding to match the
      // visual footprint of the secondary type's 2px border.  Removing or
      // changing that compensation would silently reintroduce the size
      // mismatch this fix addressed.

      testWidgets(
        'no-border type (primary) applies 2px outer padding to compensate for '
        'missing border',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              onPressed: () {},
            ),
          );

          // Walk up from AnimatedOpacity: the nearest Padding ancestor is the
          // border-compensation wrapper, not the inner icon padding.
          final compensatingPadding = tester.widget<Padding>(
            find
                .ancestor(
                  of: find.byType(AnimatedOpacity),
                  matching: find.byType(Padding),
                )
                .first,
          );
          expect(
            compensatingPadding.padding,
            equals(const EdgeInsets.all(2)),
          );
        },
      );

      testWidgets(
        'bordered type (secondary) applies no outer compensating padding',
        (tester) async {
          await tester.pumpWidget(
            buildTestWidget(
              type: DivineIconButtonType.secondary,
              onPressed: () {},
            ),
          );

          final compensatingPadding = tester.widget<Padding>(
            find
                .ancestor(
                  of: find.byType(AnimatedOpacity),
                  matching: find.byType(Padding),
                )
                .first,
          );
          expect(compensatingPadding.padding, equals(EdgeInsets.zero));
        },
      );
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
