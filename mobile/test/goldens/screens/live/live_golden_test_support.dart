import 'package:flutter/material.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/live/live_chat_message.dart';
import 'package:openvine/models/live/live_presence.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_room_recording.dart';
import 'package:openvine/models/live/live_room_token.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/providers/live_providers.dart';
import 'package:openvine/repositories/live_chat_repository.dart';
import 'package:openvine/repositories/live_repository.dart';
import 'package:openvine/screens/live/go_live_page.dart';
import 'package:openvine/screens/live/live_discovery_page.dart';
import 'package:openvine/screens/live/live_room_detail_view.dart';
import 'package:openvine/screens/live/live_room_page.dart';
import 'package:openvine/screens/live/widgets/live_explore_entry_card.dart';
import 'package:openvine/screens/live/widgets/live_room_card.dart';
import 'package:openvine/services/live_api_service.dart';
import 'package:openvine/services/livekit_room_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockLiveRepository extends Mock implements LiveRepository {}

class _MockLiveChatRepository extends Mock implements LiveChatRepository {}

class _MockLiveApiService extends Mock implements LiveApiService {}

class _MockLiveKitRoomService extends Mock implements LiveKitRoomService {}

class LiveGoldenFixtures {
  static const room = LiveRoom(
    id: 'room-123',
    hostPubkey: 'host-pubkey',
    title: 'Signal from the stage',
    summary: 'A live room for creators and the people following along.',
    imageUrl: null,
    relays: <String>[],
    visibility: LiveRoomVisibility.public,
  );

  static final liveSession = LiveSession(
    id: 'session-123',
    roomId: room.id,
    status: LiveSessionStatus.live,
    startedAt: DateTime.utc(2026, 4, 6, 8),
    endedAt: null,
    speakerPubkeys: const <String>['host-pubkey', 'speaker-pubkey'],
    audienceCount: 64,
  );

  static final endedSession = LiveSession(
    id: 'session-ended',
    roomId: room.id,
    status: LiveSessionStatus.ended,
    startedAt: DateTime.utc(2026, 4, 6, 7),
    endedAt: DateTime.utc(2026, 4, 6, 9),
    speakerPubkeys: const <String>['host-pubkey'],
    audienceCount: 64,
  );

  static const replayReadyRecording = LiveRoomRecording(
    playbackUrl: 'https://example.com/replay.m3u8',
    status: RecordingStatus.ready,
  );

  static const replayProcessingRecording = LiveRoomRecording(
    playbackUrl: 'https://example.com/replay.m3u8',
    status: RecordingStatus.processing,
  );

  static const sessionAddress = '30313:host-pubkey:session-123';

  static Widget buildDiscoveryCards() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        LiveExploreEntryCard(onTap: () {}),
        const SizedBox(height: 16),
        LiveRoomCard(
          room: room,
          session: liveSession,
          onTap: () {},
        ),
        const SizedBox(height: 16),
        LiveRoomCard(
          room: room.copyWith(
            id: 'room-456',
            title: 'Tonight after the drop',
            summary: 'A calmer room queued up for later.',
          ),
          session: LiveSession(
            id: 'session-planned',
            roomId: 'room-456',
            status: LiveSessionStatus.planned,
            startedAt: DateTime.utc(2026, 4, 6, 12),
            endedAt: null,
            speakerPubkeys: const <String>['host-pubkey'],
            audienceCount: 12,
          ),
          onTap: () {},
        ),
      ],
    );
  }

  static Future<Widget> buildDiscoveryPage({
    required List<LiveRoom> rooms,
    required List<LiveSession> sessions,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final sharedPreferences = await SharedPreferences.getInstance();
    final liveRepository = _MockLiveRepository();

    when(
      liveRepository.fetchPublicRooms,
    ).thenAnswer((_) async => rooms);
    when(
      liveRepository.fetchSessions,
    ).thenAnswer((_) async => sessions);

    return testMaterialApp(
      mockSharedPreferences: sharedPreferences,
      additionalOverrides: [
        liveRepositoryProvider.overrideWithValue(liveRepository),
      ],
      home: const LiveDiscoveryPage(),
    );
  }

  static Widget buildDetailView({
    required LiveRoom room,
    LiveSession? session,
    LiveRoomRecording? recording,
  }) {
    return LiveRoomDetailView(
      room: room,
      session: session,
      recording: recording,
    );
  }

  static Future<Widget> buildRoomPage({
    required String currentUserPubkey,
  }) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final sharedPreferences = await SharedPreferences.getInstance();
    final authService = createMockAuthService();
    when(() => authService.currentPublicKeyHex).thenReturn(currentUserPubkey);

    final liveRepository = _MockLiveRepository();
    final liveChatRepository = _MockLiveChatRepository();
    final liveApiService = _MockLiveApiService();
    final liveKitRoomService = _MockLiveKitRoomService();

    const audienceToken = LiveRoomToken(
      token: 'audience-token',
      serverUrl: 'wss://live.example.com',
      roomName: 'room-123',
      participantIdentity: 'audience-pubkey',
      canPublish: false,
    );
    const hostToken = LiveRoomToken(
      token: 'host-token',
      serverUrl: 'wss://live.example.com',
      roomName: 'room-123',
      participantIdentity: 'host-pubkey',
      canPublish: true,
    );
    const speakerToken = LiveRoomToken(
      token: 'speaker-token',
      serverUrl: 'wss://live.example.com',
      roomName: 'room-123',
      participantIdentity: 'speaker-pubkey',
      canPublish: true,
    );

    when(liveKitRoomService.watchState).thenAnswer(
      (_) => Stream<LiveMediaState>.value(
        const LiveMediaState(
          status: LiveMediaConnectionStatus.connected,
          canPublish: true,
          cameraEnabled: true,
          microphoneEnabled: true,
        ),
      ),
    );
    when(
      () => liveKitRoomService.connect(audienceToken),
    ).thenAnswer((_) async {});
    when(() => liveKitRoomService.connect(hostToken)).thenAnswer((_) async {});
    when(() => liveKitRoomService.connect(speakerToken)).thenAnswer(
      (_) async {},
    );
    when(liveKitRoomService.disconnect).thenAnswer((_) async {});
    when(
      () => liveKitRoomService.publishLocalTracks(
        cameraEnabled: any(named: 'cameraEnabled'),
        microphoneEnabled: any(named: 'microphoneEnabled'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => liveRepository.watchSessions(roomAddress: room.address),
    ).thenAnswer(
      (_) => Stream<List<LiveSession>>.value(<LiveSession>[liveSession]),
    );
    when(
      () => liveRepository.watchPresence(sessionAddress: sessionAddress),
    ).thenAnswer(
      (_) => Stream<List<LivePresence>>.value(<LivePresence>[
        LivePresence(
          sessionId: liveSession.id,
          pubkey: 'host-pubkey',
          role: LiveRole.host,
          handRaised: false,
          updatedAt: DateTime.utc(2026, 4, 6, 8, 1),
        ),
        LivePresence(
          sessionId: liveSession.id,
          pubkey: 'audience-pubkey',
          role: LiveRole.audience,
          handRaised: true,
          updatedAt: DateTime.utc(2026, 4, 6, 8, 2),
        ),
      ]),
    );
    when(
      () => liveApiService.fetchJoinToken(
        roomId: room.id,
        role: LiveRole.audience,
      ),
    ).thenAnswer((_) async => audienceToken);
    when(
      () => liveApiService.fetchJoinToken(roomId: room.id, role: LiveRole.host),
    ).thenAnswer((_) async => hostToken);
    when(
      () => liveApiService.fetchJoinToken(
        roomId: room.id,
        role: LiveRole.speaker,
      ),
    ).thenAnswer((_) async => speakerToken);
    when(
      () =>
          liveChatRepository.watchChatMessages(sessionAddress: sessionAddress),
    ).thenAnswer(
      (_) => Stream<List<LiveChatMessage>>.value(
        <LiveChatMessage>[
          LiveChatMessage(
            id: 'chat-1',
            sessionAddress: sessionAddress,
            pubkey: 'audience-pubkey',
            content: 'This room is live.',
            createdAt: DateTime.utc(2026, 4, 6, 8, 1),
          ),
        ],
      ),
    );

    return testMaterialApp(
      mockSharedPreferences: sharedPreferences,
      mockAuthService: authService,
      additionalOverrides: [
        liveRepositoryProvider.overrideWithValue(liveRepository),
        liveChatRepositoryProvider.overrideWithValue(liveChatRepository),
        liveApiServiceProvider.overrideWithValue(liveApiService),
        liveKitRoomServiceProvider.overrideWithValue(liveKitRoomService),
      ],
      home: LiveRoomPage(
        roomId: room.id,
        sessionId: liveSession.id,
        initialRoom: room,
        initialSession: liveSession,
      ),
    );
  }

  static Future<Widget> buildGoLivePage() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final sharedPreferences = await SharedPreferences.getInstance();
    final authService = createMockAuthService();
    when(() => authService.currentPublicKeyHex).thenReturn('host-pubkey');

    final liveRepository = _MockLiveRepository();
    final liveApiService = _MockLiveApiService();

    return testMaterialApp(
      mockSharedPreferences: sharedPreferences,
      mockAuthService: authService,
      additionalOverrides: [
        liveRepositoryProvider.overrideWithValue(liveRepository),
        liveApiServiceProvider.overrideWithValue(liveApiService),
      ],
      home: const GoLivePage(),
    );
  }
}
