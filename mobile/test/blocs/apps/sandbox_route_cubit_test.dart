import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/apps/sandbox_route_cubit.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/services/nostr_app_directory_service.dart';

class _MockNostrAppDirectoryService extends Mock
    implements NostrAppDirectoryService {}

void main() {
  group('SandboxRouteCubit', () {
    late _MockNostrAppDirectoryService mockDirectoryService;

    setUp(() {
      mockDirectoryService = _MockNostrAppDirectoryService();
    });

    blocTest<SandboxRouteCubit, SandboxRouteState>(
      'resolves the initial app without reloading the directory',
      build: () => SandboxRouteCubit(
        directoryService: mockDirectoryService,
        appId: 'primal-app',
        initialApp: _fixtureApp(),
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<SandboxRouteState>()
            .having(
              (state) => state.status,
              'status',
              SandboxRouteStatus.resolved,
            )
            .having((state) => state.app?.id, 'app id', 'primal-app'),
      ],
      verify: (_) {
        verifyNever(() => mockDirectoryService.fetchApprovedApps());
      },
    );

    blocTest<SandboxRouteCubit, SandboxRouteState>(
      'emits missing when the approved app cannot be found',
      setUp: () {
        when(
          () => mockDirectoryService.fetchApprovedApps(),
        ).thenAnswer((_) async => const []);
      },
      build: () => SandboxRouteCubit(
        directoryService: mockDirectoryService,
        appId: 'missing-app',
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<SandboxRouteState>().having(
          (state) => state.status,
          'status',
          SandboxRouteStatus.loading,
        ),
        isA<SandboxRouteState>().having(
          (state) => state.status,
          'status',
          SandboxRouteStatus.missing,
        ),
      ],
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
