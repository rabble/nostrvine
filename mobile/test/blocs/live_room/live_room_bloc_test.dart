import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/live_room/live_room_bloc.dart';
import 'package:openvine/models/live/live_presence.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_room_token.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/repositories/live_repository.dart';
import 'package:openvine/services/live_api_service.dart';
import 'package:openvine/services/livekit_room_service.dart';

class _MockLiveRepository extends Mock implements LiveRepository {}

class _MockLiveApiService extends Mock implements LiveApiService {}

class _MockLiveKitRoomService extends Mock implements LiveKitRoomService {}

void main() {
  group('LiveRoomBloc', () {
    late _MockLiveRepository mockRepository;
    late _MockLiveApiService mockApiService;
    late _MockLiveKitRoomService mockMediaService;
    late StreamController<List<LiveSession>> sessionsController;
    late StreamController<List<LivePresence>> presenceController;
    late StreamController<LiveMediaState> mediaController;

    const hostPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const speakerPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const room = LiveRoom(
      id: 'room-abc',
      hostPubkey: hostPubkey,
      title: 'Divine Live',
      summary: 'Public room',
      imageUrl: null,
      relays: <String>[],
      visibility: LiveRoomVisibility.public,
    );
    final liveSession = LiveSession(
      id: 'session-abc',
      roomId: room.id,
      status: LiveSessionStatus.live,
      startedAt: DateTime.utc(2026, 4, 6, 12),
      endedAt: null,
      speakerPubkeys: const <String>[hostPubkey, speakerPubkey],
      audienceCount: 42,
    );
    final hostPresence = LivePresence(
      sessionId: liveSession.id,
      pubkey: hostPubkey,
      role: LiveRole.host,
      handRaised: false,
      updatedAt: DateTime.utc(2026, 4, 6, 12, 1),
    );
    final speakerPresence = LivePresence(
      sessionId: liveSession.id,
      pubkey: speakerPubkey,
      role: LiveRole.speaker,
      handRaised: false,
      updatedAt: DateTime.utc(2026, 4, 6, 12, 2),
    );
    const joinToken = LiveRoomToken(
      token: 'jwt-token',
      roomName: 'room-abc',
      participantIdentity: hostPubkey,
      serverUrl: 'wss://livekit.example.com',
      canPublish: true,
    );
    const connectedMediaState = LiveMediaState(
      status: LiveMediaConnectionStatus.connected,
      canPublish: true,
      cameraEnabled: true,
      microphoneEnabled: true,
    );

    setUpAll(() {
      registerFallbackValue(room);
      registerFallbackValue(joinToken);
    });

    setUp(() {
      mockRepository = _MockLiveRepository();
      mockApiService = _MockLiveApiService();
      mockMediaService = _MockLiveKitRoomService();
      sessionsController = StreamController<List<LiveSession>>.broadcast(
        sync: true,
      );
      presenceController = StreamController<List<LivePresence>>.broadcast(
        sync: true,
      );
      mediaController = StreamController<LiveMediaState>.broadcast(sync: true);

      when(
        () => mockRepository.watchSessions(roomAddress: room.address),
      ).thenAnswer((_) => sessionsController.stream);
      when(
        () => mockRepository.watchPresence(
          sessionAddress: '30313:$hostPubkey:${liveSession.id}',
        ),
      ).thenAnswer((_) => presenceController.stream);
      when(
        () => mockApiService.fetchJoinToken(
          roomId: room.id,
          role: LiveRole.host,
        ),
      ).thenAnswer((_) async => joinToken);
      when(
        () => mockMediaService.watchState(),
      ).thenAnswer((_) => mediaController.stream);
      when(() => mockMediaService.connect(joinToken)).thenAnswer((_) async {});
      when(() => mockMediaService.disconnect()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await sessionsController.close();
      await presenceController.close();
      await mediaController.close();
    });

    test(
      'join request watches room state, fetches a token, and exposes host speaker state',
      () async {
        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
        );

        bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        presenceController.add(<LivePresence>[hostPresence, speakerPresence]);
        mediaController.add(connectedMediaState);
        await _flush();

        expect(bloc.state.status, LiveRoomStatus.ready);
        expect(bloc.state.room, room);
        expect(bloc.state.session, liveSession);
        expect(
          bloc.state.speakerPubkeys,
          containsAll(<String>[hostPubkey, speakerPubkey]),
        );
        expect(bloc.state.canModerate, isTrue);
        expect(bloc.state.canPublish, isTrue);
        expect(bloc.state.mediaState, connectedMediaState);

        verify(
          () => mockRepository.watchSessions(roomAddress: room.address),
        ).called(1);
        verify(
          () => mockRepository.watchPresence(
            sessionAddress: '30313:$hostPubkey:${liveSession.id}',
          ),
        ).called(1);
        verify(
          () => mockApiService.fetchJoinToken(
            roomId: room.id,
            role: LiveRole.host,
          ),
        ).called(1);
        verify(() => mockMediaService.connect(joinToken)).called(1);

        await bloc.close();
      },
    );

    test('join request emits failure when token fetch fails', () async {
      when(
        () => mockApiService.fetchJoinToken(
          roomId: room.id,
          role: LiveRole.host,
        ),
      ).thenThrow(Exception('token failed'));

      final bloc = LiveRoomBloc(
        liveRepository: mockRepository,
        liveApiService: mockApiService,
        liveKitRoomService: mockMediaService,
      );

      bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
      await _flush();

      sessionsController.add(<LiveSession>[liveSession]);
      await _flush();

      expect(bloc.state.status, LiveRoomStatus.failure);
      expect(bloc.state.errorMessage, contains('token failed'));
      verifyNever(() => mockMediaService.connect(any()));

      await bloc.close();
    });
  });
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
