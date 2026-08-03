import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DivineSnackbarContainer', () {
    Widget buildTestWidget({
      required String label,
      bool error = false,
      String? actionLabel,
      VoidCallback? onActionPressed,
      String? secondaryActionLabel,
      VoidCallback? onSecondaryActionPressed,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: DivineSnackbarContainer(
            label: label,
            error: error,
            actionLabel: actionLabel,
            onActionPressed: onActionPressed,
            secondaryActionLabel: secondaryActionLabel,
            onSecondaryActionPressed: onSecondaryActionPressed,
          ),
        ),
      );
    }

    testWidgets('renders with label text', (tester) async {
      await tester.pumpWidget(buildTestWidget(label: 'Test message'));

      expect(find.text('Test message'), findsOneWidget);
    });

    testWidgets('renders non-error state correctly', (tester) async {
      await tester.pumpWidget(buildTestWidget(label: 'Info message'));

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;

      expect(decoration.color, VineTheme.cardBackground);
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(16)),
      );
    });

    testWidgets('renders error state correctly', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(label: 'Error message', error: true),
      );

      final decoratedBox = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox),
      );
      final decoration = decoratedBox.decoration as BoxDecoration;

      expect(decoration.color, VineTheme.errorContainer);
    });

    testWidgets('renders error text with red color', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(label: 'Error message', error: true),
      );

      final text = tester.widget<Text>(find.text('Error message'));
      expect(text.style?.color, VineTheme.likeRed);
    });

    testWidgets('renders non-error text without red color', (tester) async {
      await tester.pumpWidget(buildTestWidget(label: 'Info message'));

      final text = tester.widget<Text>(find.text('Info message'));
      expect(text.style?.color, isNot(VineTheme.likeRed));
    });

    testWidgets('does not render action button when actionLabel is null', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget(label: 'Test message'));

      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('does not render action button when onActionPressed is null', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(label: 'Test message', actionLabel: 'Retry'),
      );

      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('renders action button when both actionLabel and '
        'onActionPressed are provided', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          label: 'Test message',
          actionLabel: 'Retry',
          onActionPressed: () {},
        ),
      );

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('calls onActionPressed when action button is tapped', (
      tester,
    ) async {
      var actionPressed = false;
      await tester.pumpWidget(
        buildTestWidget(
          label: 'Test message',
          actionLabel: 'Retry',
          onActionPressed: () => actionPressed = true,
        ),
      );

      await tester.tap(find.text('Retry'));
      expect(actionPressed, isTrue);
    });

    testWidgets('action button has green color in non-error state', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          label: 'Test message',
          actionLabel: 'Retry',
          onActionPressed: () {},
        ),
      );

      final actionText = tester.widget<Text>(find.text('Retry'));
      expect(actionText.style?.color, VineTheme.vineGreen);
    });

    testWidgets('action button has red color in error state', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          label: 'Error message',
          error: true,
          actionLabel: 'Retry',
          onActionPressed: () {},
        ),
      );

      final actionText = tester.widget<Text>(find.text('Retry'));
      expect(actionText.style?.color, VineTheme.likeRed);
    });

    group('secondary action', () {
      testWidgets('renders both actions when a secondary is provided', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            label: 'Message not delivered',
            error: true,
            actionLabel: 'Resend',
            onActionPressed: () {},
            secondaryActionLabel: 'Delete',
            onSecondaryActionPressed: () {},
          ),
        );

        expect(find.text('Resend'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
      });

      testWidgets('primary stays green and secondary is red even in an '
          'error snackbar', (tester) async {
        await tester.pumpWidget(
          buildTestWidget(
            label: 'Message not delivered',
            error: true,
            actionLabel: 'Resend',
            onActionPressed: () {},
            secondaryActionLabel: 'Delete',
            onSecondaryActionPressed: () {},
          ),
        );

        expect(
          tester.widget<Text>(find.text('Resend')).style?.color,
          VineTheme.vineGreen,
        );
        expect(
          tester.widget<Text>(find.text('Delete')).style?.color,
          VineTheme.likeRed,
        );
      });

      testWidgets('calls onSecondaryActionPressed when tapped', (tester) async {
        var deletePressed = false;
        await tester.pumpWidget(
          buildTestWidget(
            label: 'Message not delivered',
            actionLabel: 'Resend',
            onActionPressed: () {},
            secondaryActionLabel: 'Delete',
            onSecondaryActionPressed: () => deletePressed = true,
          ),
        );

        await tester.tap(find.text('Delete'));
        expect(deletePressed, isTrue);
      });

      testWidgets('omits the secondary when its callback is null', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildTestWidget(
            label: 'Message not delivered',
            actionLabel: 'Resend',
            onActionPressed: () {},
            secondaryActionLabel: 'Delete',
          ),
        );

        expect(find.text('Delete'), findsNothing);
      });
    });

    group('snackBar factory', () {
      testWidgets('returns a $SnackBar wrapping $DivineSnackbarContainer', (
        tester,
      ) async {
        final snackBar = DivineSnackbarContainer.snackBar('Hello');

        expect(snackBar, isA<SnackBar>());
        expect(snackBar.backgroundColor, Colors.transparent);
        expect(snackBar.elevation, 0);
        expect(snackBar.behavior, SnackBarBehavior.floating);
        expect(snackBar.padding, EdgeInsets.zero);
        expect(snackBar.content, isA<DivineSnackbarContainer>());

        final container = snackBar.content as DivineSnackbarContainer;
        expect(container.label, 'Hello');
        expect(container.error, isFalse);
        expect(container.actionLabel, isNull);
        expect(container.onActionPressed, isNull);
      });

      testWidgets('passes error and action parameters through', (
        tester,
      ) async {
        void onAction() {}

        void onDelete() {}

        final snackBar = DivineSnackbarContainer.snackBar(
          'Error occurred',
          error: true,
          actionLabel: 'Retry',
          onActionPressed: onAction,
          secondaryActionLabel: 'Delete',
          onSecondaryActionPressed: onDelete,
        );

        final container = snackBar.content as DivineSnackbarContainer;
        expect(container.label, 'Error occurred');
        expect(container.error, isTrue);
        expect(container.actionLabel, 'Retry');
        expect(container.onActionPressed, equals(onAction));
        expect(container.secondaryActionLabel, 'Delete');
        expect(container.onSecondaryActionPressed, equals(onDelete));
      });
    });

    testWidgets('has correct padding', (tester) async {
      await tester.pumpWidget(buildTestWidget(label: 'Test message'));

      final padding = tester.widget<Padding>(find.byType(Padding));
      expect(
        padding.padding,
        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      );
    });

    testWidgets('uses Row with spaceBetween alignment', (tester) async {
      await tester.pumpWidget(buildTestWidget(label: 'Test message'));

      final row = tester.widget<Row>(find.byType(Row));
      expect(row.mainAxisAlignment, MainAxisAlignment.spaceBetween);
    });

    testWidgets('paints a custom surface colour when given one', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: const Scaffold(
            body: DivineSnackbarContainer(
              label: 'Switched to staging',
              backgroundColor: Color(0xFF123456),
            ),
          ),
        ),
      );

      final box = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      expect(
        (box.decoration as BoxDecoration).color,
        const Color(0xFF123456),
      );
    });

    testWidgets('a custom surface wins over the error surface', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: const Scaffold(
            body: DivineSnackbarContainer(
              label: 'Switched to production',
              error: true,
              backgroundColor: Color(0xFF123456),
            ),
          ),
        ),
      );

      final box = tester.widget<DecoratedBox>(
        find.byType(DecoratedBox).first,
      );
      expect(
        (box.decoration as BoxDecoration).color,
        const Color(0xFF123456),
      );
    });

    testWidgets('a light custom surface flips the label to dark ink', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: const Scaffold(
            body: DivineSnackbarContainer(
              label: 'Switched to Staging',
              // The staging indicator yellow — white text is unreadable on it.
              backgroundColor: Color(0xFFFFF140),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Switched to Staging'));
      expect(text.style?.color, VineTheme.primaryDarkGreen);
    });

    testWidgets('a dark custom surface keeps the light label', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: VineTheme.theme,
          home: const Scaffold(
            body: DivineSnackbarContainer(
              label: 'Switched to Production',
              backgroundColor: Color(0xFF123456),
            ),
          ),
        ),
      );

      final text = tester.widget<Text>(find.text('Switched to Production'));
      expect(text.style?.color, VineTheme.primaryText);
    });

    testWidgets('snackBar forwards the custom surface colour', (tester) async {
      final snackBar = DivineSnackbarContainer.snackBar(
        'Switched to staging',
        backgroundColor: const Color(0xFF123456),
      );

      expect(
        (snackBar.content as DivineSnackbarContainer).backgroundColor,
        const Color(0xFF123456),
      );
    });
  });
}
