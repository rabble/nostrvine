// ABOUTME: Tests for DivineSecondaryButton widget
// ABOUTME: Verifies label rendering, tap callback, and loading state

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/divine_secondary_button.dart';

void main() {
  group(DivineSecondaryButton, () {
    Widget createTestWidget({
      required String label,
      VoidCallback? onPressed,
      bool isLoading = false,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: DivineSecondaryButton(
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
          createTestWidget(label: 'Import Nostr key', onPressed: () {}),
        );

        expect(find.text('Import Nostr key'), findsOneWidget);
      });

      testWidgets('displays $OutlinedButton', (tester) async {
        await tester.pumpWidget(
          createTestWidget(label: 'Continue', onPressed: () {}),
        );

        expect(find.byType(OutlinedButton), findsOneWidget);
      });

      testWidgets('shows $CircularProgressIndicator when isLoading is true', (
        tester,
      ) async {
        await tester.pumpWidget(
          createTestWidget(
            label: 'Connecting',
            onPressed: () {},
            isLoading: true,
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Connecting'), findsNothing);
      });

      testWidgets('hides label when isLoading is true', (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            label: 'Sign in with Amber',
            onPressed: () {},
            isLoading: true,
          ),
        );

        expect(find.text('Sign in with Amber'), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('calls onPressed when tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          createTestWidget(
            label: 'Import Nostr key',
            onPressed: () => tapped = true,
          ),
        );

        await tester.tap(find.byType(OutlinedButton));
        expect(tapped, isTrue);
      });

      testWidgets('does not call onPressed when isLoading', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          createTestWidget(
            label: 'Connecting',
            onPressed: () => tapped = true,
            isLoading: true,
          ),
        );

        await tester.tap(find.byType(OutlinedButton));
        expect(tapped, isFalse);
      });

      testWidgets('does not call onPressed when onPressed is null', (
        tester,
      ) async {
        await tester.pumpWidget(createTestWidget(label: 'Disabled'));

        final button = tester.widget<OutlinedButton>(
          find.byType(OutlinedButton),
        );
        expect(button.onPressed, isNull);
      });
    });
  });
}
