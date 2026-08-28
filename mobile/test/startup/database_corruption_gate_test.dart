import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/database_corruption_provider.dart';
import 'package:openvine/services/database_corruption_service.dart';
import 'package:openvine/startup/database_corruption_gate.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppLocalizations l10n;
  late SharedPreferences prefs;

  setUp(() async {
    l10n = lookupAppLocalizations(const Locale('en'));
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  /// Mirrors how `main.dart` installs the gate — as `MaterialApp.builder`,
  /// above the routes but below Localizations. The screen therefore renders a
  /// Scaffold with no Navigator ancestor, which this pins.
  Widget buildSubject(DatabaseCorruptionService? service) {
    return ProviderScope(
      overrides: [
        databaseCorruptionServiceProvider.overrideWithValue(service),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Text('app content'),
        builder: (context, child) =>
            DatabaseCorruptionGate(child: child ?? const SizedBox.shrink()),
      ),
    );
  }

  DatabaseCorruptionService buildService() {
    final service = DatabaseCorruptionService(preferences: prefs);
    addTearDown(service.dispose);
    return service;
  }

  group(DatabaseCorruptionGate, () {
    testWidgets('renders the app while the database is healthy', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(buildService()));

      expect(find.text('app content'), findsOneWidget);
      expect(find.text(l10n.databaseCorruptionTitle), findsNothing);
    });

    testWidgets('renders the app when no service is wired', (tester) async {
      await tester.pumpWidget(buildSubject(null));

      expect(find.text('app content'), findsOneWidget);
    });

    testWidgets('takes over the moment corruption surfaces', (tester) async {
      final service = buildService();
      await tester.pumpWidget(buildSubject(service));

      service.report(
        Exception('database disk image is malformed'),
        StackTrace.current,
      );
      await tester.pump();

      expect(find.text(l10n.databaseCorruptionTitle), findsOneWidget);
      expect(
        find.text('app content'),
        findsNothing,
        reason: 'every screen is broken once the database is; say so instead',
      );
    });
  });

  group(DatabaseCorruptionScreen, () {
    Widget buildScreen(
      VoidCallback onCloseApp, {
      Future<void> Function()? awaitRecoveryPersisted,
      bool? canCloseApp,
    }) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: DatabaseCorruptionScreen(
        awaitRecoveryPersisted: awaitRecoveryPersisted,
        canCloseApp: canCloseApp,
        onCloseApp: onCloseApp,
      ),
    );

    testWidgets('explains the restart repairs the database', (tester) async {
      await tester.pumpWidget(buildScreen(() {}));
      await tester.pump();

      expect(find.text(l10n.databaseCorruptionTitle), findsOneWidget);
      expect(find.text(l10n.databaseCorruptionBody), findsOneWidget);
    });

    testWidgets('closes the app when the button is tapped', (tester) async {
      var closed = false;
      await tester.pumpWidget(buildScreen(() => closed = true));
      await tester.pump();

      await tester.tap(find.text(l10n.databaseCorruptionCloseButton));
      await tester.pump();

      expect(closed, isTrue);
    });

    testWidgets('hides the close action on iOS by platform default', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        await tester.pumpWidget(buildScreen(() {}));
        await tester.pump();

        expect(find.byType(DivineButton), findsNothing);
        expect(find.text(l10n.databaseCorruptionBody), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('uses SystemNavigator.pop by default on Android', (
      tester,
    ) async {
      final methodCalls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        methodCalls.add(call);
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DatabaseCorruptionScreen(),
        ),
      );
      await tester.pump();

      await tester.tap(find.text(l10n.databaseCorruptionCloseButton));
      await tester.pump();

      expect(
        methodCalls.where((call) => call.method == 'SystemNavigator.pop'),
        hasLength(1),
      );
    });

    testWidgets('will not close until the recovery flag is durable', (
      tester,
    ) async {
      var closed = false;
      final persisted = Completer<void>();
      await tester.pumpWidget(
        buildScreen(
          () => closed = true,
          awaitRecoveryPersisted: () => persisted.future,
        ),
      );
      await tester.pump();

      // Closing before the flag lands strands the user on the same corrupt
      // database: the restart only repairs anything if the next launch can
      // read the flag this write is still committing.
      expect(find.byType(DivineButton), findsNothing);
      expect(find.text(l10n.databaseCorruptionBody), findsNothing);
      expect(find.text(l10n.commonLoading), findsOneWidget);
      expect(closed, isFalse);

      persisted.complete();
      await tester.pump();
      await tester.tap(find.byType(DivineButton));
      await tester.pump();

      expect(closed, isTrue);
    });

    testWidgets('holds iOS restart instructions until recovery is durable', (
      tester,
    ) async {
      final persisted = Completer<void>();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      try {
        await tester.pumpWidget(
          buildScreen(
            () {},
            awaitRecoveryPersisted: () => persisted.future,
          ),
        );
        await tester.pump();

        expect(find.byType(DivineButton), findsNothing);
        expect(find.text(l10n.databaseCorruptionBody), findsNothing);
        expect(find.text(l10n.commonLoading), findsOneWidget);
        expect(
          tester.getSemantics(find.byType(CircularProgressIndicator)),
          matchesSemantics(label: l10n.commonLoading),
        );

        persisted.complete();
        await tester.pump();

        expect(find.byType(DivineButton), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.text(l10n.commonLoading), findsNothing);
        expect(find.text(l10n.databaseCorruptionBody), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
