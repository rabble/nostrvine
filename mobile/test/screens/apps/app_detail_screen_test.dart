import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/screens/apps/app_detail_screen.dart';
import 'package:openvine/screens/apps/nostr_app_sandbox_screen.dart';

import '../../helpers/go_router.dart';

void main() {
  group('AppDetailScreen', () {
    testWidgets('opens the sandbox route from the launch action', (
      tester,
    ) async {
      final mockGoRouter = MockGoRouter();
      when(
        () => mockGoRouter.push(any(), extra: any(named: 'extra')),
      ).thenAnswer((_) async => null);

      await tester.pumpWidget(
        ProviderScope(
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

      await tester.scrollUntilVisible(find.byType(DivineButton), 300);
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
    });
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
