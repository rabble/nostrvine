import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/apps/apps_directory_cubit.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/services/nostr_app_directory_service.dart';

class _MockNostrAppDirectoryService extends Mock
    implements NostrAppDirectoryService {}

void main() {
  group('AppsDirectoryCubit', () {
    late _MockNostrAppDirectoryService mockDirectoryService;

    setUp(() {
      mockDirectoryService = _MockNostrAppDirectoryService();
    });

    blocTest<AppsDirectoryCubit, AppsDirectoryState>(
      'loads the approved app list',
      setUp: () {
        when(() => mockDirectoryService.fetchApprovedApps()).thenAnswer(
          (_) async => [_fixtureApp()],
        );
      },
      build: () => AppsDirectoryCubit(directoryService: mockDirectoryService),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<AppsDirectoryState>().having(
          (state) => state.status,
          'status',
          AppsDirectoryStatus.loading,
        ),
        isA<AppsDirectoryState>()
            .having(
              (state) => state.status,
              'status',
              AppsDirectoryStatus.loaded,
            )
            .having((state) => state.apps.single.id, 'app id', 'app-primal'),
      ],
    );

    blocTest<AppsDirectoryCubit, AppsDirectoryState>(
      'emits a failure state when the directory request throws',
      setUp: () {
        when(
          () => mockDirectoryService.fetchApprovedApps(),
        ).thenThrow(Exception('boom'));
      },
      build: () => AppsDirectoryCubit(directoryService: mockDirectoryService),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<AppsDirectoryState>().having(
          (state) => state.status,
          'status',
          AppsDirectoryStatus.loading,
        ),
        isA<AppsDirectoryState>().having(
          (state) => state.status,
          'status',
          AppsDirectoryStatus.failure,
        ),
      ],
    );
  });
}

NostrAppDirectoryEntry _fixtureApp() {
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
