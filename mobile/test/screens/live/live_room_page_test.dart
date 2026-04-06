import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/live/live_chat_message.dart';
import 'package:openvine/models/live/live_presence.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_room_token.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/providers/live_providers.dart';
import 'package:openvine/repositories/live_chat_repository.dart';
import 'package:openvine/repositories/live_repository.dart';
import 'package:openvine/screens/live/live_room_page.dart';
import 'package:openvine/services/live_api_service.dart';
import 'package:openvine/services/livekit_room_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockLiveRepository extends Mock implements LiveRepository {}

class _MockLiveChatRepository extends Mock implements LiveChatRepository {}

class _MockLiveApiService extends Mock implements LiveApiService {}

class _MockLiveKitRoomService extends Mock implements LiveKitRoomService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LiveRoomPage', () {
    late _MockLiveRepository mockLiveRepository;
    late _MockLiveChatRepository mockLiveChatRepository;
    late _MockLiveApiService mockLiveApiService;
    late _MockLiveKitRoomService mockLiveKitRoomService;

    const room = LiveRoom(
      id: 'room-123',
      hostPubkey: 'host-pubkey',
      title: 'Signal from the stage',
      summary: 'A live room for creators and the people following along.',
      imageUrl: null,
      relays: <String>[],
      visibility: LiveRoomVisibility.public,
    );
    final session = LiveSession(
      id: 'session-123',
      roomId: 'room-123',
      status: LiveSessionStatus.live,
      startedAt: DateTime.utc(2026, 4, 6, 8),
      endedAt: null,
      speakerPubkeys: const <String>['host-pubkey'],
      audienceCount: 64,
    );
    const sessionAddress = '30313:host-pubkey:session-123';
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

    setUp(() {
      mockLiveRepository = _MockLiveRepository();
      mockLiveChatRepository = _MockLiveChatRepository();
      mockLiveApiService = _MockLiveApiService();
      mockLiveKitRoomService = _MockLiveKitRoomService();

      when(() => mockLiveKitRoomService.watchState()).thenAnswer(
        (_) => Stream<LiveMediaState>.value(const LiveMediaState()),
      );
      when(
        () => mockLiveRepository.watchSessions(roomAddress: room.address),
      ).thenAnswer(
        (_) => Stream<List<LiveSession>>.value(<LiveSession>[session]),
      );
      when(
        () => mockLiveRepository.watchPresence(sessionAddress: sessionAddress),
      ).thenAnswer(
        (_) => Stream<List<LivePresence>>.value(const <LivePresence>[]),
      );
      when(
        () => mockLiveChatRepository.watchChatMessages(
          sessionAddress: sessionAddress,
        ),
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
      when(() => mockLiveKitRoomService.connect(audienceToken)).thenAnswer(
        (_) async {},
      );
      when(() => mockLiveKitRoomService.connect(hostToken)).thenAnswer(
        (_) async {},
      );
      when(() => mockLiveKitRoomService.disconnect()).thenAnswer((_) async {});
      when(
        () => mockLiveApiService.fetchJoinToken(
          roomId: room.id,
          role: LiveRole.audience,
        ),
      ).thenAnswer((_) async => audienceToken);
      when(
        () => mockLiveApiService.fetchJoinToken(
          roomId: room.id,
          role: LiveRole.host,
        ),
      ).thenAnswer((_) async => hostToken);
    });

    testWidgets('host controls appear for hosts, not audience members', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final hostAuth = createMockAuthService();
      when(() => hostAuth.currentPublicKeyHex).thenReturn('host-pubkey');

      await tester.pumpWidget(
        testMaterialApp(
          mockSharedPreferences: sharedPreferences,
          mockAuthService: hostAuth,
          additionalOverrides: [
            liveRepositoryProvider.overrideWithValue(mockLiveRepository),
            liveChatRepositoryProvider.overrideWithValue(
              mockLiveChatRepository,
            ),
            liveApiServiceProvider.overrideWithValue(mockLiveApiService),
            liveKitRoomServiceProvider.overrideWithValue(
              mockLiveKitRoomService,
            ),
          ],
          home: LiveRoomPage(
            roomId: room.id,
            sessionId: session.id,
            initialRoom: room,
            initialSession: session,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Host controls'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
    });

    testWidgets('audience members do not see host controls', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final sharedPreferences = await SharedPreferences.getInstance();
      final audienceAuth = createMockAuthService();
      when(() => audienceAuth.currentPublicKeyHex).thenReturn(
        'audience-pubkey',
      );

      await tester.pumpWidget(
        testMaterialApp(
          mockSharedPreferences: sharedPreferences,
          mockAuthService: audienceAuth,
          additionalOverrides: [
            liveRepositoryProvider.overrideWithValue(mockLiveRepository),
            liveChatRepositoryProvider.overrideWithValue(
              mockLiveChatRepository,
            ),
            liveApiServiceProvider.overrideWithValue(mockLiveApiService),
            liveKitRoomServiceProvider.overrideWithValue(
              mockLiveKitRoomService,
            ),
          ],
          home: LiveRoomPage(
            roomId: room.id,
            sessionId: session.id,
            initialRoom: room,
            initialSession: session,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Host controls'), findsNothing);
      expect(find.text('Raise hand'), findsOneWidget);
    });
  });
}
