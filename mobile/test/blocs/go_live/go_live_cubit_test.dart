import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/go_live/go_live_cubit.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/repositories/live_repository.dart';
import 'package:openvine/services/live_api_service.dart';

class _MockLiveApiService extends Mock implements LiveApiService {}

class _MockLiveRepository extends Mock implements LiveRepository {}

void main() {
  group('GoLiveCubit', () {
    late _MockLiveApiService mockApiService;
    late _MockLiveRepository mockRepository;

    const hostPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const roomDraft = LiveRoom(
      id: 'room-abc',
      hostPubkey: hostPubkey,
      title: 'Divine Live',
      summary: 'Public room for creators',
      imageUrl: null,
      relays: <String>[],
      visibility: LiveRoomVisibility.public,
    );

    setUpAll(() {
      registerFallbackValue(roomDraft);
      registerFallbackValue(
        LiveSession(
          id: 'session-abc',
          roomId: roomDraft.id,
          status: LiveSessionStatus.live,
          startedAt: DateTime.utc(2026, 4, 6, 12),
          endedAt: null,
          speakerPubkeys: const <String>[hostPubkey],
          audienceCount: 0,
        ),
      );
    });

    setUp(() {
      mockApiService = _MockLiveApiService();
      mockRepository = _MockLiveRepository();

      when(
        () => mockApiService.createRoomDraft(
          title: 'Divine Live',
          summary: 'Public room for creators',
        ),
      ).thenAnswer((_) async => roomDraft);
      when(
        () => mockRepository.publishRoom(roomDraft),
      ).thenAnswer((_) async => null);
      when(
        () => mockRepository.publishSession(
          session: any(named: 'session'),
          roomAddress: roomDraft.address,
          hostPubkey: hostPubkey,
        ),
      ).thenAnswer((_) async => null);
      when(
        () => mockApiService.startSession(
          roomId: roomDraft.id,
          sessionId: 'session-abc',
        ),
      ).thenAnswer((_) async {});
    });

    test('title updates drive form validity', () {
      final cubit = GoLiveCubit(
        liveApiService: mockApiService,
        liveRepository: mockRepository,
        currentUserPubkey: hostPubkey,
      );

      expect(cubit.state.isValid, isFalse);

      cubit.titleChanged('Divine Live');

      expect(cubit.state.title, 'Divine Live');
      expect(cubit.state.isValid, isTrue);
    });

    blocTest<GoLiveCubit, GoLiveState>(
      'submit validates the title before creating a room',
      build: () => GoLiveCubit(
        liveApiService: mockApiService,
        liveRepository: mockRepository,
        currentUserPubkey: hostPubkey,
      ),
      act: (cubit) => cubit.submit(),
      expect: () => <GoLiveState>[
        const GoLiveState(
          titleError: 'Enter a title to go live.',
        ),
      ],
      verify: (_) {
        verifyNever(
          () => mockApiService.createRoomDraft(
            title: any(named: 'title'),
            summary: any(named: 'summary'),
          ),
        );
      },
    );

    blocTest<GoLiveCubit, GoLiveState>(
      'submit creates a room draft, publishes the room and session, and marks success',
      build: () {
        final cubit = GoLiveCubit(
          liveApiService: mockApiService,
          liveRepository: mockRepository,
          currentUserPubkey: hostPubkey,
          now: () => DateTime.utc(2026, 4, 6, 12),
          sessionIdBuilder: () => 'session-abc',
        );
        cubit.titleChanged('Divine Live');
        cubit.summaryChanged('Public room for creators');
        return cubit;
      },
      act: (cubit) => cubit.submit(),
      expect: () => <dynamic>[
        isA<GoLiveState>().having(
          (state) => state.status,
          'status',
          GoLiveStatus.submitting,
        ),
        isA<GoLiveState>()
            .having((state) => state.status, 'status', GoLiveStatus.success)
            .having((state) => state.room, 'room', roomDraft)
            .having((state) => state.session?.id, 'session.id', 'session-abc'),
      ],
      verify: (_) {
        verify(
          () => mockApiService.createRoomDraft(
            title: 'Divine Live',
            summary: 'Public room for creators',
          ),
        ).called(1);
        verify(() => mockRepository.publishRoom(roomDraft)).called(1);
        verify(
          () => mockRepository.publishSession(
            session: any(named: 'session'),
            roomAddress: roomDraft.address,
            hostPubkey: hostPubkey,
          ),
        ).called(1);
        verify(
          () => mockApiService.startSession(
            roomId: roomDraft.id,
            sessionId: 'session-abc',
          ),
        ).called(1);
      },
    );
  });
}
