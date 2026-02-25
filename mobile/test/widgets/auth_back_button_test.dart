// ABOUTME: Tests for AuthBackButton widget
// ABOUTME: Verifies icon rendering and custom onPressed callback

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/auth_back_button.dart';
import 'package:openvine/widgets/rounded_icon_button.dart';

void main() {
  group(AuthBackButton, () {
    group('renders', () {
      testWidgets('displays $RoundedIconButton', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: const Scaffold(body: AuthBackButton(onPressed: _noop)),
          ),
        );

        expect(find.byType(RoundedIconButton), findsOneWidget);
      });

      testWidgets('displays chevron_left icon', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: const Scaffold(body: AuthBackButton(onPressed: _noop)),
          ),
        );

        expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      });

      testWidgets('uses vineGreenLight color for icon', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: const Scaffold(body: AuthBackButton(onPressed: _noop)),
          ),
        );

        final icon = tester.widget<Icon>(find.byIcon(Icons.chevron_left));
        expect(icon.color, equals(VineTheme.vineGreenLight));
      });
    });

    group('interactions', () {
      testWidgets('calls custom onPressed when tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          MaterialApp(
            theme: VineTheme.theme,
            home: Scaffold(
              body: AuthBackButton(onPressed: () => tapped = true),
            ),
          ),
        );

        await tester.tap(find.byType(RoundedIconButton));
        expect(tapped, isTrue);
      });
    });
  });
}

void _noop() {}
