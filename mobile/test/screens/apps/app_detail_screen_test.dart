import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
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
          () => mockGoRouter.push(
            any(),
            extra: any(named: 'extra'),
          ),
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
                home: AppDetailScreen(
                  slug: 'primal',
                  initialEntry: _fixtureApp(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('How it works'), findsOneWidget);
        expect(
          find.text(
            'This is an approved third-party app that runs inside Divine. Divine only grants reviewed capabilities for this integration, and blocks navigation outside its approved origins.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Primary origin'),
          findsOneWidget,
        );
        expect(
          find.text('https://primal.net'),
          findsWidgets,
        );
        expect(
          find.text('https://primal.net/app'),
          findsNothing,
        );
        expect(
          find.text('Approved origins'),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.text('Available capabilities'),
          300,
        );
        expect(
          find.text('Available capabilities'),
          findsOneWidget,
        );
        expect(find.text('Ask before'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Open Integration'),
          300,
        );
        expect(
          find.text('Open Integration'),
          findsOneWidget,
        );
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
