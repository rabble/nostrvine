import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/apps/app_detail_screen.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';

import '../../helpers/go_router.dart';

class _MockNostrAppDirectoryService extends Mock
    implements NostrAppDirectoryService {}

void main() {
  group('AppDetailScreen', () {
    late _MockNostrAppDirectoryService mockDirectoryService;

    setUp(() {
      mockDirectoryService = _MockNostrAppDirectoryService();
    });

    testWidgets(
      'shows approved integration messaging and opens the launch action',
      (tester) async {
        final mockGoRouter = MockGoRouter();
        when(
          () => mockGoRouter.push(any(), extra: any(named: 'extra')),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              nostrAppDirectoryServiceProvider.overrideWithValue(
                mockDirectoryService,
              ),
            ],
            child: MockGoRouterProvider(
              goRouter: mockGoRouter,
              child: MaterialApp(
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: AppDetailScreen(
                  slug: 'primal',
                  initialEntry: _fixtureApp(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.appsDetailHowItWorksTitle), findsOneWidget);
        expect(find.text(l10n.appsDetailHowItWorksBody), findsOneWidget);
        expect(find.text(l10n.appsDetailPrimaryOriginTitle), findsOneWidget);
        expect(find.text('https://primal.net'), findsWidgets);
        expect(find.text('https://primal.net/app'), findsNothing);
        await tester.scrollUntilVisible(
          find.text(l10n.appsDetailApprovedOriginsTitle),
          300,
        );
        expect(find.text(l10n.appsDetailApprovedOriginsTitle), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(l10n.appsDetailCapabilitiesTitle),
          300,
        );
        expect(find.text(l10n.appsDetailCapabilitiesTitle), findsOneWidget);
        expect(find.text(l10n.appsDetailAskBeforeTitle), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text(l10n.appsDetailOpenButton),
          300,
        );
        expect(find.text(l10n.appsDetailOpenButton), findsOneWidget);
        await tester.tap(find.byType(DivineButton));
        await tester.pumpAndSettle();

        final captured = verify(
          () => mockGoRouter.push(
            NostrAppSandboxScreen.pathForAppId('primal-app'),
            extra: captureAny(named: 'extra'),
          ),
        ).captured;
        final pushedApp = captured.single as NostrAppDirectoryEntry;
        expect(pushedApp.id, 'primal-app');
        expect(pushedApp.slug, 'primal');
      },
    );
  });
}

NostrAppDirectoryEntry _fixtureApp() {
  return NostrAppDirectoryEntry(
    id: 'primal-app',
    slug: 'primal',
    name: 'Primal',
    tagline: 'Fast Nostr feeds and messages',
    description: 'A vetted Nostr client for timelines and DMs.',
    iconUrl: 'https://cdn.divine.video/primal.png',
    launchUrl: 'https://primal.net/app',
    allowedOrigins: const ['https://primal.net'],
    allowedMethods: const ['getPublicKey', 'signEvent'],
    allowedSignEventKinds: const [1],
    promptRequiredFor: const ['signEvent'],
    status: 'approved',
    sortOrder: 1,
    createdAt: DateTime.parse('2026-03-24T08:00:00Z'),
    updatedAt: DateTime.parse('2026-03-25T08:00:00Z'),
  );
}
