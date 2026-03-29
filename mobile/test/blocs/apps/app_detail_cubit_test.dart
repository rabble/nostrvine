import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/apps/app_detail_cubit.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/services/nostr_app_directory_service.dart';

class _MockNostrAppDirectoryService extends Mock
    implements NostrAppDirectoryService {}

void main() {
  group('AppDetailCubit', () {
    late _MockNostrAppDirectoryService mockDirectoryService;

    setUp(() {
      mockDirectoryService = _MockNostrAppDirectoryService();
    });

    blocTest<AppDetailCubit, AppDetailState>(
      'emits the initial entry without hitting the directory service',
      build: () => AppDetailCubit(
        directoryService: mockDirectoryService,
        slug: 'primal',
        initialEntry: _fixtureApp(),
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<AppDetailState>()
            .having((state) => state.status, 'status', AppDetailStatus.loaded)
            .having((state) => state.app?.slug, 'slug', 'primal'),
      ],
      verify: (_) {
        verifyNever(() => mockDirectoryService.fetchApprovedApps());
      },
    );

    blocTest<AppDetailCubit, AppDetailState>(
      'loads the matching app from the approved directory entries',
      setUp: () {
        when(() => mockDirectoryService.fetchApprovedApps()).thenAnswer(
          (_) async => [_fixtureApp()],
        );
      },
      build: () => AppDetailCubit(
        directoryService: mockDirectoryService,
        slug: 'primal',
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<AppDetailState>().having(
          (state) => state.status,
          'status',
          AppDetailStatus.loading,
        ),
        isA<AppDetailState>()
            .having((state) => state.status, 'status', AppDetailStatus.loaded)
            .having((state) => state.app?.id, 'id', 'primal-app'),
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
