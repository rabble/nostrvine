// ABOUTME: Tests the environment/relay indicator line color logic and widget.
// ABOUTME: Purple when on non-Divine relays; environment color otherwise.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/widgets/environment_indicator_line.dart';

void main() {
  const divineRelays = ['wss://relay.divine.video'];
  const withNonDivineRelay = [
    'wss://relay.divine.video',
    'wss://purplepag.es',
  ];

  group('environmentIndicatorColor', () {
    test('hidden in production on Divine-only relays', () {
      expect(
        environmentIndicatorColor(
          environment: EnvironmentConfig.production,
          configuredRelays: divineRelays,
        ),
        isNull,
      );
    });

    test('environment color in non-production on Divine-only relays', () {
      const staging = EnvironmentConfig(environment: AppEnvironment.staging);
      expect(
        environmentIndicatorColor(
          environment: staging,
          configuredRelays: divineRelays,
        ),
        equals(Color(staging.indicatorColorValue)),
      );
    });

    test('purple in production when a non-Divine relay is configured', () {
      expect(
        environmentIndicatorColor(
          environment: EnvironmentConfig.production,
          configuredRelays: withNonDivineRelay,
        ),
        equals(VineTheme.accentPurple),
      );
    });

    test('purple wins over the environment color', () {
      expect(
        environmentIndicatorColor(
          environment: const EnvironmentConfig(
            environment: AppEnvironment.staging,
          ),
          configuredRelays: withNonDivineRelay,
        ),
        equals(VineTheme.accentPurple),
      );
    });
  });

  group(EnvironmentIndicatorLine, () {
    Widget pump(Color? color) {
      return ProviderScope(
        overrides: [
          environmentIndicatorColorProvider.overrideWithValue(color),
        ],
        child: const MaterialApp(home: EnvironmentIndicatorLine()),
      );
    }

    Finder lineBox() => find.descendant(
      of: find.byType(EnvironmentIndicatorLine),
      matching: find.byType(ColoredBox),
    );

    testWidgets('renders a colored line when the color is non-null', (
      tester,
    ) async {
      await tester.pumpWidget(pump(VineTheme.accentPurple));

      final box = tester.widget<ColoredBox>(lineBox());
      expect(box.color, equals(VineTheme.accentPurple));
    });

    testWidgets('renders nothing when the color is null', (tester) async {
      await tester.pumpWidget(pump(null));

      expect(lineBox(), findsNothing);
    });
  });
}
