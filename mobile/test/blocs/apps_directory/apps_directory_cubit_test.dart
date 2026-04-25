import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/blocs/apps_directory/apps_directory_cubit.dart';

class _MockDirectoryService extends Mock implements NostrAppDirectoryService {}

void main() {
  group(AppsDirectoryCubit, () {
    late _MockDirectoryService mockService;

    setUp(() {
      mockService = _MockDirectoryService();
    });

    test('initial state is correct', () {
      final cubit = AppsDirectoryCubit(directoryService: mockService);
      expect(cubit.state.status, AppsDirectoryStatus.initial);
      expect(cubit.state.apps, isEmpty);
    });

    blocTest<AppsDirectoryCubit, AppsDirectoryState>(
      'emits [loading, loaded] when loadApps succeeds',
      setUp: () {
        when(
          mockService.fetchApprovedApps,
        ).thenAnswer((_) async => [_fixture()]);
      },
      build: () => AppsDirectoryCubit(directoryService: mockService),
      act: (cubit) => cubit.loadApps(),
      expect: () => [
        const AppsDirectoryState(status: AppsDirectoryStatus.loading),
        isA<AppsDirectoryState>()
            .having((s) => s.status, 'status', AppsDirectoryStatus.loaded)
            .having((s) => s.apps.length, 'apps.length', 1),
      ],
    );

    blocTest<AppsDirectoryCubit, AppsDirectoryState>(
      'emits [loading, error] when loadApps fails',
      setUp: () {
        when(
          mockService.fetchApprovedApps,
        ).thenThrow(Exception('network error'));
      },
      build: () => AppsDirectoryCubit(directoryService: mockService),
      act: (cubit) => cubit.loadApps(),
      expect: () => [
        const AppsDirectoryState(status: AppsDirectoryStatus.loading),
        const AppsDirectoryState(status: AppsDirectoryStatus.error),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<AppsDirectoryCubit, AppsDirectoryState>(
      'emits [loaded] when refreshApps succeeds',
      setUp: () {
        when(
          mockService.fetchApprovedApps,
        ).thenAnswer((_) async => [_fixture()]);
      },
      build: () => AppsDirectoryCubit(directoryService: mockService),
      act: (cubit) => cubit.refreshApps(),
      expect: () => [
        isA<AppsDirectoryState>()
            .having((s) => s.status, 'status', AppsDirectoryStatus.loaded)
            .having((s) => s.apps.length, 'apps.length', 1),
      ],
    );

    blocTest<AppsDirectoryCubit, AppsDirectoryState>(
      'emits [error] when refreshApps fails',
      setUp: () {
        when(
          mockService.fetchApprovedApps,
        ).thenThrow(Exception('network error'));
      },
      build: () => AppsDirectoryCubit(directoryService: mockService),
      act: (cubit) => cubit.refreshApps(),
      expect: () => [
        const AppsDirectoryState(status: AppsDirectoryStatus.error),
      ],
      errors: () => [isA<Exception>()],
    );
  });
}

NostrAppDirectoryEntry _fixture() {
  return NostrAppDirectoryEntry(
    id: 'app-primal',
    slug: 'primal',
    name: 'Primal',
    tagline: 'Fast Nostr feeds and messages',
    description: 'A vetted Nostr client.',
    iconUrl: 'https://cdn.divine.video/primal.png',
    launchUrl: 'https://primal.net',
    allowedOrigins: const ['https://primal.net'],
    allowedMethods: const ['getPublicKey'],
    allowedSignEventKinds: const [1],
    promptRequiredFor: const ['signEvent'],
    status: 'approved',
    sortOrder: 1,
    createdAt: DateTime.parse('2026-03-24T08:00:00Z'),
    updatedAt: DateTime.parse('2026-03-25T08:00:00Z'),
  );
}
