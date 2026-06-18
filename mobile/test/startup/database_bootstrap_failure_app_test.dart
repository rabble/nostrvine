import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/startup/database_bootstrap_failure_app.dart';

void main() {
  group('resolveDatabaseBootstrapForAppStart', () {
    test('returns the cipher key without rendering failure UI', () async {
      var removedSplash = false;
      Widget? renderedApp;

      final result = await resolveDatabaseBootstrapForAppStart(
        resolveCipherKey: () async => 'a' * 64,
        removeNativeSplash: () => removedSplash = true,
        runApp: (app) => renderedApp = app,
      );

      expect(result.didRenderFailureApp, isFalse);
      expect(result.cipherKey, equals('a' * 64));
      expect(removedSplash, isFalse);
      expect(renderedApp, isNull);
    });

    test(
      'renders a visible failure app and removes native splash on error',
      () async {
        var removedSplash = false;
        Widget? renderedApp;
        final error = StateError('secure storage unavailable');

        final result = await resolveDatabaseBootstrapForAppStart(
          resolveCipherKey: () async => throw error,
          removeNativeSplash: () => removedSplash = true,
          runApp: (app) => renderedApp = app,
        );

        expect(result.didRenderFailureApp, isTrue);
        expect(result.cipherKey, isNull);
        expect(removedSplash, isTrue);
        expect(renderedApp, isA<DatabaseBootstrapFailureApp>());
      },
    );
  });

  group(DatabaseBootstrapFailureApp, () {
    testWidgets('shows a visible database startup failure screen', (
      tester,
    ) async {
      var closed = false;

      await tester.pumpWidget(
        DatabaseBootstrapFailureApp(
          error: StateError('secure storage unavailable'),
          stack: StackTrace.current,
          onCloseApp: () => closed = true,
        ),
      );

      expect(
        find.text("couldn't unlock your local database"),
        findsOneWidget,
      );
      expect(find.textContaining('Restart Divine'), findsOneWidget);

      await tester.tap(find.text('close Divine'));
      expect(closed, isTrue);
    });
  });
}
