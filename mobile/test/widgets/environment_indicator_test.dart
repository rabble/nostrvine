// ABOUTME: Widget tests for environment indicator components
// ABOUTME: Tests badge, banner visibility and behavior across environments
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/environment_indicator.dart';

void main() {
  const stagingConfig = EnvironmentConfig(environment: AppEnvironment.staging);

  const devConfig = EnvironmentConfig(environment: AppEnvironment.dev);

  group('EnvironmentBadge', () {
    testWidgets('shows STG badge for staging environment', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => stagingConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Stack(children: [EnvironmentBadge()])),
          ),
        ),
      );

      expect(find.text('STG'), findsOneWidget);
      expect(find.byType(Container), findsOneWidget);
    });

    testWidgets('shows DEV badge for development environment', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => devConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Stack(children: [EnvironmentBadge()])),
          ),
        ),
      );

      expect(find.text('DEV'), findsOneWidget);
      expect(find.byType(Container), findsOneWidget);
    });

    testWidgets('hides badge for production environment', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith(
              (ref) => EnvironmentConfig.production,
            ),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Stack(children: [EnvironmentBadge()])),
          ),
        ),
      );

      expect(find.text('STG'), findsNothing);
      expect(find.text('DEV'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('hides badge when indicator is disabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => stagingConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => false),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Stack(children: [EnvironmentBadge()])),
          ),
        ),
      );

      expect(find.text('STG'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('badge has correct styling for staging', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => stagingConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Stack(children: [EnvironmentBadge()])),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(EnvironmentBadge),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Color(stagingConfig.indicatorColorValue));
      expect(decoration.borderRadius, isA<BorderRadius>());
    });

    testWidgets('badge has correct styling for development', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => devConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Stack(children: [EnvironmentBadge()])),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(EnvironmentBadge),
          matching: find.byType(Container),
        ),
      );

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Color(devConfig.indicatorColorValue));
    });
  });

  group('EnvironmentBanner', () {
    testWidgets('shows staging banner with correct text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => stagingConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(children: [EnvironmentBanner(onTap: () {})]),
            ),
          ),
        ),
      );

      expect(
        find.text('Environment: Staging (Funnelcake) - Tap for options'),
        findsOneWidget,
      );
      expect(find.byType(GestureDetector), findsOneWidget);
    });

    testWidgets('shows development banner with correct text', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => devConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(children: [EnvironmentBanner(onTap: () {})]),
            ),
          ),
        ),
      );

      expect(
        find.textContaining('Environment: Dev'),
        findsOneWidget,
      ); // Matches "Dev - Umbra"
    });

    testWidgets('hides banner for production environment', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith(
              (ref) => EnvironmentConfig.production,
            ),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(children: [EnvironmentBanner(onTap: () {})]),
            ),
          ),
        ),
      );

      expect(find.textContaining('Environment: Staging'), findsNothing);
      expect(find.textContaining('Environment: Dev'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('hides banner when indicator is disabled', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => stagingConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => false),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(children: [EnvironmentBanner(onTap: () {})]),
            ),
          ),
        ),
      );

      expect(find.text('Environment: Staging'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('calls onTap callback when tapped', (
      WidgetTester tester,
    ) async {
      var tapped = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => stagingConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  EnvironmentBanner(
                    onTap: () {
                      tapped = true;
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(GestureDetector));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('banner has correct styling for staging', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => stagingConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(children: [EnvironmentBanner(onTap: () {})]),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GestureDetector),
          matching: find.byType(Container),
        ),
      );

      expect(container.color, Color(stagingConfig.indicatorColorValue));
    });

    testWidgets('banner has correct styling for development', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentEnvironmentProvider.overrideWith((ref) => devConfig),
            showEnvironmentIndicatorProvider.overrideWith((ref) => true),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Stack(children: [EnvironmentBanner(onTap: () {})]),
            ),
          ),
        ),
      );

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(GestureDetector),
          matching: find.byType(Container),
        ),
      );

      expect(container.color, Color(devConfig.indicatorColorValue));
    });
  });

  group('getEnvironmentAppBarColor', () {
    test('returns environment color for staging environment', () {
      final color = getEnvironmentAppBarColor(stagingConfig);
      expect(color, Color(stagingConfig.indicatorColorValue));
    });

    test('returns environment color for development environment', () {
      final color = getEnvironmentAppBarColor(devConfig);
      expect(color, Color(devConfig.indicatorColorValue));
    });

    test('returns VineTheme.navGreen for production environment', () {
      final color = getEnvironmentAppBarColor(EnvironmentConfig.production);
      expect(color, VineTheme.navGreen);
    });
  });
}
