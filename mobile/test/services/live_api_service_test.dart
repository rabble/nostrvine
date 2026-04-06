import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room_recording.dart';
import 'package:openvine/services/live_api_service.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  late _MockHttpClient mockClient;
  late LiveApiService service;

  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.com'));
    registerFallbackValue(<String, String>{});
  });

  setUp(() {
    mockClient = _MockHttpClient();
    service = LiveApiService(
      client: mockClient,
      baseUrl: 'https://api.example.com',
    );
  });

  group('LiveApiService', () {
    test(
      'createRoomDraft posts room metadata and parses the response',
      () async {
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'id': 'room-abc',
              'hostPubkey': 'host-pubkey',
              'title': 'Divine Live',
              'summary': 'Public room for mobile creators',
              'imageUrl': 'https://example.com/cover.jpg',
              'relays': ['wss://relay.example.com'],
              'visibility': 'public',
            }),
            200,
          ),
        );

        final room = await service.createRoomDraft(
          title: 'Divine Live',
          summary: 'Public room for mobile creators',
          imageUrl: 'https://example.com/cover.jpg',
          relays: const ['wss://relay.example.com'],
        );

        expect(room.id, 'room-abc');
        expect(room.title, 'Divine Live');
        expect(room.summary, 'Public room for mobile creators');

        verify(
          () => mockClient.post(
            Uri.parse('https://api.example.com/v1/live/rooms'),
            headers: any(named: 'headers'),
            body: jsonEncode({
              'title': 'Divine Live',
              'summary': 'Public room for mobile creators',
              'imageUrl': 'https://example.com/cover.jpg',
              'relays': ['wss://relay.example.com'],
            }),
          ),
        ).called(1);
      },
    );

    test('startSession posts a backend start request', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('', 200));

      await service.startSession(roomId: 'room-abc', sessionId: 'session-abc');

      verify(
        () => mockClient.post(
          Uri.parse('https://api.example.com/v1/live/rooms/room-abc/sessions'),
          headers: any(named: 'headers'),
          body: jsonEncode({'sessionId': 'session-abc'}),
        ),
      ).called(1);
    });

    test('fetchJoinToken returns a publish token for hosts', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'token': 'jwt-token',
            'roomName': 'room-abc',
            'participantIdentity': 'host-pubkey',
            'serverUrl': 'wss://livekit.example.com',
            'canPublish': true,
          }),
          200,
        ),
      );

      final token = await service.fetchJoinToken(
        roomId: 'room-abc',
        role: LiveRole.host,
      );

      expect(token.token, 'jwt-token');
      expect(token.roomName, 'room-abc');
      expect(token.participantIdentity, 'host-pubkey');
      expect(token.serverUrl, 'wss://livekit.example.com');
      expect(token.canPublish, isTrue);
    });

    test('endSession posts a backend end request', () async {
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => http.Response('', 200));

      await service.endSession(roomId: 'room-abc', sessionId: 'session-abc');

      verify(
        () => mockClient.post(
          Uri.parse(
            'https://api.example.com/v1/live/rooms/room-abc/sessions/session-abc/end',
          ),
          headers: any(named: 'headers'),
          body: jsonEncode(const <String, dynamic>{}),
        ),
      ).called(1);
    });

    test('fetchRecording parses recording status when present', () async {
      when(
        () => mockClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'status': 'ready',
            'playbackUrl': 'https://example.com/replay.m3u8',
          }),
          200,
        ),
      );

      final recording = await service.fetchRecording(roomId: 'room-abc');

      expect(recording, isNotNull);
      expect(recording!.status, RecordingStatus.ready);
      expect(recording.playbackUrl, 'https://example.com/replay.m3u8');
    });

    test(
      'fetchRecording returns null when the room has no replay yet',
      () async {
        when(
          () => mockClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer((_) async => http.Response('', 404));

        final recording = await service.fetchRecording(roomId: 'room-abc');

        expect(recording, isNull);
      },
    );
  });
}
