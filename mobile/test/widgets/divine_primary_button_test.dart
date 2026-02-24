// ABOUTME: Tests for DivinePrimaryButton widget
// ABOUTME: Verifies label rendering, tap callback, and loading state

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/divine_primary_button.dart';

void main() {
  group(DivinePrimaryButton, () {
    Widget createTestWidget({
      required String label,
      VoidCallback? onPressed,
      bool isLoading = false,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: DivinePrimaryButton(
            label: label,
            onPressed: onPressed,
            isLoading: isLoading,
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('displays label text', (tester) async {
        await tester.pumpWidget(
          createTestWidget(label: 'Sign in', onPressed: () {}),
        );

        expect(find.text('Sign in'), findsOneWidget);
      });

      testWidgets('displays $ElevatedButton', (tester) async {
        await tester.pumpWidget(
          createTestWidget(label: 'Continue', onPressed: () {}),
        );

        expect(find.byType(ElevatedButton), findsOneWidget);
      });

      testWidgets('shows $CircularProgressIndicator when isLoading is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(label: 'Sign in', onPressed: () {}, isLoading: true),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Sign in'), findsNothing);
      });

      testWidgets('hides label when isLoading is true', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            label: 'Create account',
            onPressed: () {},
            isLoading: true,
          ),
        );

        expect(find.text('Create account'), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('calls onPressed when tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          createTestWidget(label: 'Sign in', onPressed: () => tapped = true),
        );

        await tester.tap(find.byType(ElevatedButton));
        expect(tapped, isTrue);
      });

      testWidgets('does not call onPressed when isLoading', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          createTestWidget(
            label: 'Sign in',
            onPressed: () => tapped = true,
            isLoading: true,
          ),
        );

        await tester.tap(find.byType(ElevatedButton));
        expect(tapped, isFalse);
      });

      testWidgets('does not call onPressed when onPressed is null', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget(label: 'Disabled'));

        // Button should still render but be disabled
        final button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(button.onPressed, isNull);
      });
    });
  });
}
