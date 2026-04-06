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
    const audiencePubkey =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
    const audienceTwoPubkey =
        'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
    const audienceThreePubkey =
        'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
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
    final raisedHandPresence = LivePresence(
      sessionId: liveSession.id,
      pubkey: audiencePubkey,
      role: LiveRole.audience,
      handRaised: true,
      updatedAt: DateTime.utc(2026, 4, 6, 12, 3),
    );
    final audienceTwoPresence = LivePresence(
      sessionId: liveSession.id,
      pubkey: audienceTwoPubkey,
      role: LiveRole.audience,
      handRaised: true,
      updatedAt: DateTime.utc(2026, 4, 6, 12, 4),
    );
    final audienceThreePresence = LivePresence(
      sessionId: liveSession.id,
      pubkey: audienceThreePubkey,
      role: LiveRole.audience,
      handRaised: true,
      updatedAt: DateTime.utc(2026, 4, 6, 12, 5),
    );
    const joinToken = LiveRoomToken(
      token: 'jwt-token',
      roomName: 'room-abc',
      participantIdentity: hostPubkey,
      serverUrl: 'wss://livekit.example.com',
      canPublish: true,
    );
    const audienceJoinToken = LiveRoomToken(
      token: 'audience-jwt-token',
      roomName: 'room-abc',
      participantIdentity: audiencePubkey,
      serverUrl: 'wss://livekit.example.com',
      canPublish: false,
    );
    const speakerJoinToken = LiveRoomToken(
      token: 'speaker-jwt-token',
      roomName: 'room-abc',
      participantIdentity: audiencePubkey,
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
      registerFallbackValue(liveSession);
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
        () => mockApiService.fetchJoinToken(
          roomId: room.id,
          role: LiveRole.audience,
        ),
      ).thenAnswer((_) async => audienceJoinToken);
      when(
        () => mockApiService.fetchJoinToken(
          roomId: room.id,
          role: LiveRole.speaker,
        ),
      ).thenAnswer((_) async => speakerJoinToken);
      when(
        () => mockMediaService.watchState(),
      ).thenAnswer((_) => mediaController.stream);
      when(() => mockMediaService.connect(joinToken)).thenAnswer((_) async {});
      when(
        () => mockMediaService.connect(audienceJoinToken),
      ).thenAnswer((_) async {});
      when(
        () => mockMediaService.connect(speakerJoinToken),
      ).thenAnswer((_) async {});
      when(() => mockMediaService.disconnect()).thenAnswer((_) async {});
      when(
        () => mockMediaService.setMicrophoneEnabled(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockMediaService.setCameraEnabled(any()),
      ).thenAnswer((_) async {});
      when(() => mockMediaService.switchCamera()).thenAnswer((_) async {});
      when(() => mockMediaService.enableAudioOnly()).thenAnswer((_) async {});
      when(
        () => mockMediaService.publishLocalTracks(
          cameraEnabled: any(named: 'cameraEnabled'),
          microphoneEnabled: any(named: 'microphoneEnabled'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => mockRepository.publishSession(
          session: any(named: 'session'),
          roomAddress: room.address,
          hostPubkey: room.hostPubkey,
        ),
      ).thenAnswer((_) async => null);
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

    test('publish control events delegate to the media service', () async {
      final bloc = LiveRoomBloc(
        liveRepository: mockRepository,
        liveApiService: mockApiService,
        liveKitRoomService: mockMediaService,
      );

      bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
      await _flush();

      sessionsController.add(<LiveSession>[liveSession]);
      await _flush();

      mediaController.add(connectedMediaState);
      await _flush();

      bloc
        ..add(const ToggleMicrophoneRequested())
        ..add(const ToggleCameraRequested())
        ..add(const SwitchCameraRequested())
        ..add(const EnableAudioOnlyRequested());
      await _flush();

      verify(() => mockMediaService.setMicrophoneEnabled(false)).called(1);
      verify(() => mockMediaService.setCameraEnabled(false)).called(1);
      verify(() => mockMediaService.switchCamera()).called(1);
      verify(() => mockMediaService.enableAudioOnly()).called(1);

      await bloc.close();
    });

    test(
      'audience members promoted onto the stage reconnect as speakers and gain publish access',
      () async {
        final promotedSession = liveSession.copyWith(
          speakerPubkeys: const <String>[
            hostPubkey,
            speakerPubkey,
            audiencePubkey,
          ],
        );
        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
          currentUserPubkey: audiencePubkey,
        );

        bloc.add(
          const LiveRoomJoinRequested(room: room, role: LiveRole.audience),
        );
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        expect(bloc.state.canPublish, isFalse);

        sessionsController.add(<LiveSession>[promotedSession]);
        await _flush();

        expect(bloc.state.role, LiveRole.speaker);
        expect(bloc.state.canPublish, isTrue);
        verify(
          () => mockApiService.fetchJoinToken(
            roomId: room.id,
            role: LiveRole.speaker,
          ),
        ).called(1);
        verify(() => mockMediaService.connect(speakerJoinToken)).called(1);

        await bloc.close();
      },
    );

    test(
      'host can promote and demote speakers while enforcing the publisher cap',
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

        presenceController.add(<LivePresence>[
          hostPresence,
          speakerPresence,
          raisedHandPresence,
          audienceTwoPresence,
          audienceThreePresence,
        ]);
        await _flush();

        bloc
          ..add(const PromoteSpeakerRequested(audiencePubkey))
          ..add(const PromoteSpeakerRequested(audienceTwoPubkey));
        await _flush();

        expect(
          bloc.state.speakerPubkeys,
          containsAll(<String>[
            hostPubkey,
            speakerPubkey,
            audiencePubkey,
            audienceTwoPubkey,
          ]),
        );

        bloc.add(const PromoteSpeakerRequested(audienceThreePubkey));
        await _flush();

        expect(bloc.state.speakerPubkeys, isNot(contains(audienceThreePubkey)));
        expect(bloc.state.errorMessage, contains('4 active video speakers'));

        bloc.add(const DemoteSpeakerRequested(audiencePubkey));
        await _flush();
        bloc.add(const PromoteSpeakerRequested(audienceThreePubkey));
        await _flush();

        expect(bloc.state.speakerPubkeys, isNot(contains(audiencePubkey)));
        expect(bloc.state.speakerPubkeys, contains(audienceThreePubkey));

        await bloc.close();
      },
    );

    test('audience backgrounds cleanly and reconnects on foreground', () async {
      final bloc = LiveRoomBloc(
        liveRepository: mockRepository,
        liveApiService: mockApiService,
        liveKitRoomService: mockMediaService,
      );

      bloc.add(
        const LiveRoomJoinRequested(room: room, role: LiveRole.audience),
      );
      await _flush();

      sessionsController.add(<LiveSession>[liveSession]);
      await _flush();

      bloc
        ..add(const LiveRoomAppForegroundChanged(false))
        ..add(const LiveRoomAppForegroundChanged(true));
      await _flush();

      verify(
        () => mockApiService.fetchJoinToken(
          roomId: room.id,
          role: LiveRole.audience,
        ),
      ).called(1);
      verify(() => mockMediaService.disconnect()).called(1);
      verify(() => mockMediaService.connect(audienceJoinToken)).called(2);

      await bloc.close();
    });

    test(
      'audience reconnect fetches a fresh token after a stale-token failure',
      () async {
        const refreshedAudienceJoinToken = LiveRoomToken(
          token: 'audience-jwt-token-fresh',
          roomName: 'room-abc',
          participantIdentity: audiencePubkey,
          serverUrl: 'wss://livekit.example.com',
          canPublish: false,
        );
        var audienceTokenCalls = 0;
        var audienceConnectCalls = 0;
        when(
          () => mockApiService.fetchJoinToken(
            roomId: room.id,
            role: LiveRole.audience,
          ),
        ).thenAnswer((_) async {
          audienceTokenCalls += 1;
          return audienceTokenCalls == 1
              ? audienceJoinToken
              : refreshedAudienceJoinToken;
        });
        when(
          () => mockMediaService.connect(audienceJoinToken),
        ).thenAnswer((_) async {
          audienceConnectCalls += 1;
          if (audienceConnectCalls > 1) {
            throw Exception('stale token');
          }
        });
        when(
          () => mockMediaService.connect(refreshedAudienceJoinToken),
        ).thenAnswer((_) async {});

        final bloc = LiveRoomBloc(
          liveRepository: mockRepository,
          liveApiService: mockApiService,
          liveKitRoomService: mockMediaService,
        );

        bloc.add(
          const LiveRoomJoinRequested(room: room, role: LiveRole.audience),
        );
        await _flush();

        sessionsController.add(<LiveSession>[liveSession]);
        await _flush();

        bloc
          ..add(const LiveRoomAppForegroundChanged(false))
          ..add(const LiveRoomAppForegroundChanged(true));
        await _flush();

        verify(
          () => mockApiService.fetchJoinToken(
            roomId: room.id,
            role: LiveRole.audience,
          ),
        ).called(2);
        verify(
          () => mockMediaService.connect(refreshedAudienceJoinToken),
        ).called(1);

        await bloc.close();
      },
    );

    test('hosts stay connected when the app backgrounds', () async {
      final bloc = LiveRoomBloc(
        liveRepository: mockRepository,
        liveApiService: mockApiService,
        liveKitRoomService: mockMediaService,
      );

      bloc.add(const LiveRoomJoinRequested(room: room, role: LiveRole.host));
      await _flush();

      sessionsController.add(<LiveSession>[liveSession]);
      await _flush();

      bloc.add(const LiveRoomAppForegroundChanged(false));
      await _flush();

      verifyNever(() => mockMediaService.disconnect());

      await bloc.close();
    });
  });
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
