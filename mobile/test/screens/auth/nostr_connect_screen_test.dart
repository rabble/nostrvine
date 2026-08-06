// ABOUTME: Widget tests for NostrConnectScreen.
// ABOUTME: Route constants plus the skeleton-loading vs real-QR state contract.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/auth/nostr_connect_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  group('NostrConnectScreen route constants', () {
    test('has correct path', () {
      expect(NostrConnectScreen.path, equals('/nostr-connect'));
    });

    test('has correct route name', () {
      expect(NostrConnectScreen.routeName, equals('nostr-connect'));
    });
  });

  group('NostrConnectScreen loading contract', () {
    late _MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = _MockAuthService();
      // dispose() reads this before deciding whether to cancel the session.
      when(
        () => mockAuthService.isNostrConnectCallbackHandoffActive,
      ).thenReturn(false);
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          ...getStandardTestOverrides(mockAuthService: mockAuthService),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          routerConfig: GoRouter(
            initialLocation: NostrConnectScreen.path,
            routes: [
              GoRoute(path: '/', builder: (_, _) => const Scaffold()),
              GoRoute(
                path: NostrConnectScreen.path,
                builder: (_, _) => const NostrConnectScreen(),
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('generating state skeletonizes and omits the real QR encoder', (
      tester,
    ) async {
      when(() => mockAuthService.nostrConnectUrl).thenReturn(null);
      when(() => mockAuthService.nostrConnectState).thenReturn(null);
      // Never resolves, so the screen stays in the generating state.
      when(
        () => mockAuthService.initiateNostrConnect(),
      ).thenAnswer((_) => Completer<NostrConnectSession>().future);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      final l10n = lookupAppLocalizations(const Locale('en'));

      // Skeleton.replace must swap the QR out entirely — otherwise the
      // encoder would run over the empty placeholder payload.
      expect(find.byType(QrImageView), findsNothing);
      expect(
        tester.widget<Skeletonizer>(find.bySubtype<Skeletonizer>()).enabled,
        isTrue,
      );
      expect(find.text(l10n.authGeneratingConnection), findsOneWidget);

      // Unmount to run dispose() and cancel any pending timers.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('listening state renders the real QR for the connect URL', (
      tester,
    ) async {
      const connectUrl =
          'nostrconnect://abc123?relay=wss://relay.example.com&secret=xyz';
      when(() => mockAuthService.nostrConnectUrl).thenReturn(connectUrl);
      when(
        () => mockAuthService.nostrConnectState,
      ).thenReturn(NostrConnectState.listening);
      // Never resolves, so the screen stays in the listening state.
      when(
        () => mockAuthService.waitForNostrConnectResponse(),
      ).thenAnswer((_) => Completer<AuthResult>().future);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Skeleton.replace is off, so the real QR encoder is built (not the
      // shimmer placeholder shown while generating).
      expect(find.byType(QrImageView), findsOneWidget);
      expect(
        tester.widget<Skeletonizer>(find.bySubtype<Skeletonizer>()).enabled,
        isFalse,
      );

      await tester.pumpWidget(const SizedBox());
    });
  });
}
