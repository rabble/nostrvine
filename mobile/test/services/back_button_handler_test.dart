// ABOUTME: Drives the real org.openvine/navigation channel Android calls into
// ABOUTME: Regression for #3337 - back from the Inbox tab used to close the app

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/router/providers/providers.dart';
import 'package:openvine/services/back_button_handler.dart';

const _navChannel = MethodChannel('org.openvine/navigation');

void main() {
  tearDown(() {
    // The handler BackButtonHandler.initialize installs outlives the test, and
    // holds a disposed GoRouter. Clear both sides so no later suite inherits it.
    _navChannel.setMethodCallHandler(null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_navChannel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  /// Visits [visitedPaths], then delivers a real `onBackPressed` call over the
  /// platform channel and reports what the native side would receive.
  Future<({bool? handled, String location})> pressBackAfterVisiting(
    WidgetTester tester,
    List<String> visitedPaths,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final locations = StreamController<String>.broadcast();
    addTearDown(locations.close);

    final router = GoRouter(
      initialLocation: '/home/0',
      routes: [
        GoRoute(path: '/home/:i', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/explore', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/notifications/:i', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/inbox', builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);

    late WidgetRef capturedRef;
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          routerLocationStreamProvider.overrideWithValue(locations.stream),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Consumer(
            builder: (context, ref, _) {
              capturedRef = ref;
              container = ProviderScope.containerOf(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    container.read(tabHistoryProvider);
    container.listen(pageContextProvider, (_, _) {});

    for (final path in visitedPaths) {
      locations.add(path);
      await tester.pump(Duration.zero);
      await tester.pump(Duration.zero);
    }

    BackButtonHandler.initialize(router, capturedRef);

    bool? handled;
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      _navChannel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onBackPressed'),
      ),
      (ByteData? reply) {
        if (reply == null) return;
        handled = const StandardMethodCodec().decodeEnvelope(reply) as bool?;
      },
    );
    await tester.pump(Duration.zero);
    await tester.pump(Duration.zero);

    final location = router.routeInformationProvider.value.uri.toString();
    // Must be cleared inside the test body: flutter_test asserts every
    // foundation debug variable is unset before tearDown runs.
    debugDefaultTargetPlatformOverride = null;

    return (handled: handled, location: location);
  }

  group(BackButtonHandler, () {
    group('onBackPressed', () {
      // #3337: this returned false, and MainActivity turns false into
      // finish() / super.onBackPressed() — the app closed from a primary tab.
      testWidgets('consumes the press on the Inbox tab and goes home', (
        tester,
      ) async {
        final result = await pressBackAfterVisiting(tester, [
          '/home/0',
          '/inbox',
        ]);

        expect(
          result.handled,
          isTrue,
          reason: 'false lets Android finish the activity, closing the app',
        );
        expect(result.location, equals('/home/0'));
      });

      testWidgets('consumes the press on the notifications feed', (
        tester,
      ) async {
        final result = await pressBackAfterVisiting(tester, [
          '/home/0',
          '/notifications/0',
        ]);

        expect(result.handled, isTrue);
        expect(result.location, equals('/home/0'));
      });

      testWidgets('returns to the previously visited tab', (tester) async {
        final result = await pressBackAfterVisiting(tester, [
          '/home/0',
          '/explore',
          '/inbox',
        ]);

        expect(result.handled, isTrue);
        expect(result.location, equals('/explore'));
      });

      // The one case where reporting the press unhandled is correct: home,
      // nothing pushed, no tab to go back to.
      testWidgets('leaves home with no history to the platform', (
        tester,
      ) async {
        final result = await pressBackAfterVisiting(tester, ['/home/0']);

        expect(result.handled, isFalse);
      });
    });
  });
}
