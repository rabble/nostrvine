import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/apps/app_detail_screen.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';
import 'package:openvine/services/nostr_app_directory_service.dart';

import '../../helpers/go_router.dart';

class _MockNostrAppDirectoryService extends Mock
    implements NostrAppDirectoryService {}

void main() {
  group('AppsDirectoryScreen', () {
    late _MockNostrAppDirectoryService mockDirectoryService;

    setUp(() {
      mockDirectoryService = _MockNostrAppDirectoryService();
    });

    Widget buildSubject({MockGoRouter? goRouter}) {
      final app = MaterialApp(home: const AppsDirectoryScreen());
      return ProviderScope(
        overrides: [
          nostrAppDirectoryServiceProvider.overrideWithValue(
            mockDirectoryService,
          ),
        ],
        child: goRouter == null
            ? app
            : MockGoRouterProvider(goRouter: goRouter, child: app),
      );
    }

    testWidgets('loads approved apps from the directory service', (
      tester,
    ) async {
      when(
        () => mockDirectoryService.fetchApprovedApps(useCacheOnly: false),
      ).thenAnswer((_) async => [_fixture()]);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Primal'), findsOneWidget);
      expect(find.text('Fast Nostr feeds and messages'), findsOneWidget);
    });

    testWidgets('tapping an app opens its detail route', (tester) async {
      final mockGoRouter = MockGoRouter();
      when(
        () => mockGoRouter.push(any(), extra: any(named: 'extra')),
      ).thenAnswer((_) async => null);
      when(
        () => mockDirectoryService.fetchApprovedApps(useCacheOnly: false),
      ).thenAnswer((_) async => [_fixture()]);

      await tester.pumpWidget(buildSubject(goRouter: mockGoRouter));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Primal'));
      await tester.pumpAndSettle();

      verify(
        () => mockGoRouter.push(
          AppDetailScreen.pathForSlug('primal'),
          extra: any(named: 'extra'),
        ),
      ).called(1);
    });

    testWidgets('shows an empty state when there are no approved apps', (
      tester,
    ) async {
      when(
        () => mockDirectoryService.fetchApprovedApps(useCacheOnly: false),
      ).thenAnswer((_) async => const []);

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('No vetted apps yet'), findsOneWidget);
      expect(
        find.text('Check back after the directory refreshes.'),
        findsOneWidget,
      );
    });
  });
}

NostrAppDirectoryEntry _fixture() {
  return NostrAppDirectoryEntry(
    id: 'app-primal',
    slug: 'primal',
    name: 'Primal',
    tagline: 'Fast Nostr feeds and messages',
    description: 'A vetted Nostr client for timelines and DMs.',
    iconUrl: 'https://cdn.divine.video/primal.png',
    launchUrl: 'https://primal.net',
    allowedOrigins: const ['https://primal.net'],
    allowedMethods: const ['getPublicKey', 'signEvent'],
    allowedSignEventKinds: const [1, 7],
    promptRequiredFor: const ['signEvent'],
    status: 'approved',
    sortOrder: 1,
    createdAt: DateTime.parse('2026-03-24T08:00:00Z'),
    updatedAt: DateTime.parse('2026-03-25T08:00:00Z'),
  );
}
