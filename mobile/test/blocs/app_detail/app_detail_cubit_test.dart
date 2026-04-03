import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/blocs/app_detail/app_detail_cubit.dart';

class _MockDirectoryService extends Mock implements NostrAppDirectoryService {}

void main() {
  group(AppDetailCubit, () {
    late _MockDirectoryService mockService;

    setUp(() {
      mockService = _MockDirectoryService();
    });

    test(
      'initial state is loaded when initialEntry is '
      'provided',
      () {
        final cubit = AppDetailCubit(
          slug: 'primal',
          directoryService: mockService,
          initialEntry: _fixture(),
        );
        expect(cubit.state, isA<AppDetailLoaded>());
        final loaded = cubit.state as AppDetailLoaded;
        expect(loaded.app.slug, 'primal');
      },
    );

    test(
      'initial state is loading when initialEntry is '
      'null',
      () {
        final cubit = AppDetailCubit(
          slug: 'primal',
          directoryService: mockService,
        );
        expect(cubit.state, isA<AppDetailLoading>());
      },
    );

    blocTest<AppDetailCubit, AppDetailState>(
      'emits [loaded] when load finds the app',
      setUp: () {
        when(mockService.fetchApprovedApps).thenAnswer(
          (_) async => [_fixture()],
        );
      },
      build: () => AppDetailCubit(
        slug: 'primal',
        directoryService: mockService,
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<AppDetailLoaded>().having(
          (s) => s.app.slug,
          'slug',
          'primal',
        ),
      ],
    );

    blocTest<AppDetailCubit, AppDetailState>(
      'emits [notFound] when load does not find the app',
      setUp: () {
        when(mockService.fetchApprovedApps).thenAnswer(
          (_) async => const [],
        );
      },
      build: () => AppDetailCubit(
        slug: 'missing',
        directoryService: mockService,
      ),
      act: (cubit) => cubit.load(),
      expect: () => [isA<AppDetailNotFound>()],
    );

    blocTest<AppDetailCubit, AppDetailState>(
      'emits [notFound] when load throws',
      setUp: () {
        when(mockService.fetchApprovedApps).thenThrow(
          Exception('network error'),
        );
      },
      build: () => AppDetailCubit(
        slug: 'primal',
        directoryService: mockService,
      ),
      act: (cubit) => cubit.load(),
      expect: () => [isA<AppDetailNotFound>()],
      errors: () => [isA<Exception>()],
    );

    blocTest<AppDetailCubit, AppDetailState>(
      'does not re-fetch when already loaded',
      setUp: () {
        when(mockService.fetchApprovedApps).thenAnswer(
          (_) async => [_fixture()],
        );
      },
      build: () => AppDetailCubit(
        slug: 'primal',
        directoryService: mockService,
        initialEntry: _fixture(),
      ),
      act: (cubit) => cubit.load(),
      expect: () => <AppDetailState>[],
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
