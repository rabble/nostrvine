import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/blocs/sandbox_route/sandbox_route_cubit.dart';

class _MockDirectoryService extends Mock implements NostrAppDirectoryService {}

void main() {
  group(SandboxRouteCubit, () {
    late _MockDirectoryService mockService;

    setUp(() {
      mockService = _MockDirectoryService();
    });

    test('initial state is resolved when initialApp is '
        'provided', () {
      final cubit = SandboxRouteCubit(
        appId: 'primal-app',
        directoryService: mockService,
        initialApp: _fixture(),
      );
      expect(cubit.state, isA<SandboxRouteResolved>());
    });

    test('initial state is loading when initialApp is null', () {
      final cubit = SandboxRouteCubit(
        appId: 'primal-app',
        directoryService: mockService,
      );
      expect(cubit.state, isA<SandboxRouteLoading>());
    });

    blocTest<SandboxRouteCubit, SandboxRouteState>(
      'emits [resolved] when load finds the app',
      setUp: () {
        when(
          mockService.fetchApprovedApps,
        ).thenAnswer((_) async => [_fixture()]);
      },
      build: () =>
          SandboxRouteCubit(appId: 'primal-app', directoryService: mockService),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<SandboxRouteResolved>().having(
          (s) => s.app.id,
          'app.id',
          'primal-app',
        ),
      ],
    );

    blocTest<SandboxRouteCubit, SandboxRouteState>(
      'emits [resolved] when load matches the app by slug',
      setUp: () {
        when(
          mockService.fetchApprovedApps,
        ).thenAnswer((_) async => [_remoteBadgesFixture()]);
      },
      build: () =>
          SandboxRouteCubit(appId: 'badges', directoryService: mockService),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<SandboxRouteResolved>().having(
          (s) => s.app.id,
          'app.id',
          'app-badges',
        ),
      ],
    );

    blocTest<SandboxRouteCubit, SandboxRouteState>(
      'emits [notFound] when neither id nor slug matches',
      setUp: () {
        when(
          mockService.fetchApprovedApps,
        ).thenAnswer((_) async => [_fixture()]);
      },
      build: () =>
          SandboxRouteCubit(appId: 'badges', directoryService: mockService),
      act: (cubit) => cubit.load(),
      expect: () => [isA<SandboxRouteNotFound>()],
    );

    blocTest<SandboxRouteCubit, SandboxRouteState>(
      'emits [notFound] when load does not find the app',
      setUp: () {
        when(mockService.fetchApprovedApps).thenAnswer((_) async => const []);
      },
      build: () => SandboxRouteCubit(
        appId: 'missing-app',
        directoryService: mockService,
      ),
      act: (cubit) => cubit.load(),
      expect: () => [isA<SandboxRouteNotFound>()],
    );

    blocTest<SandboxRouteCubit, SandboxRouteState>(
      'emits [notFound] when load throws',
      setUp: () {
        when(
          mockService.fetchApprovedApps,
        ).thenThrow(Exception('network error'));
      },
      build: () =>
          SandboxRouteCubit(appId: 'primal-app', directoryService: mockService),
      act: (cubit) => cubit.load(),
      expect: () => [isA<SandboxRouteNotFound>()],
      errors: () => [isA<Exception>()],
    );

    blocTest<SandboxRouteCubit, SandboxRouteState>(
      'does not re-fetch when already resolved',
      setUp: () {
        when(
          mockService.fetchApprovedApps,
        ).thenAnswer((_) async => [_fixture()]);
      },
      build: () => SandboxRouteCubit(
        appId: 'primal-app',
        directoryService: mockService,
        initialApp: _fixture(),
      ),
      act: (cubit) => cubit.load(),
      expect: () => <SandboxRouteState>[],
      verify: (_) {
        verifyNever(mockService.fetchApprovedApps);
      },
    );
  });
}

NostrAppDirectoryEntry _fixture() {
  return NostrAppDirectoryEntry(
    id: 'primal-app',
    slug: 'primal',
    name: 'Primal',
    tagline: 'Fast Nostr feeds and messages',
    description: 'A vetted Nostr client.',
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

/// A remote directory entry that replaced the bundled badges app under
/// a different ID but the same `badges` slug.
NostrAppDirectoryEntry _remoteBadgesFixture() {
  return const NostrAppDirectoryEntry(
    id: 'app-badges',
    slug: 'badges',
    name: 'Remote Divine Badges',
    tagline: 'Remote directory entry',
    description: 'A remotely merged badges entry.',
    iconUrl: 'https://badges.divine.video/icon.png',
    launchUrl: 'https://badges.divine.video/remote',
    allowedOrigins: ['https://badges.divine.video'],
    allowedMethods: ['getPublicKey'],
    allowedSignEventKinds: [],
    promptRequiredFor: [],
    status: 'approved',
    sortOrder: 15,
    createdAt: null,
    updatedAt: null,
  );
}
