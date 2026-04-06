import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/live/live_room_token.dart';
import 'package:openvine/services/livekit_room_service.dart';

void main() {
  late _FakeLiveKitRoomClient client;
  late LiveKitRoomService service;

  setUp(() {
    client = _FakeLiveKitRoomClient();
    service = LiveKitRoomService(clientFactory: () => client);
  });

  tearDown(() async {
    await service.dispose();
    await client.dispose();
  });

  group('LiveKitRoomService', () {
    test(
      'connect uses the token boundary and publishes connected state',
      () async {
        final states = <LiveMediaState>[];
        final subscription = service.watchState().listen(states.add);

        await service.connect(
          const LiveRoomToken(
            token: 'jwt-token',
            roomName: 'room-abc',
            participantIdentity: 'host-pubkey',
            serverUrl: 'wss://livekit.example.com',
            canPublish: true,
          ),
        );

        expect(client.prepareCalls, 1);
        expect(client.connectCalls, 1);
        expect(client.lastUrl, 'wss://livekit.example.com');
        expect(client.lastToken, 'jwt-token');
        expect(
          service.currentState.status,
          LiveMediaConnectionStatus.connected,
        );
        expect(service.currentState.canPublish, isTrue);
        expect(
          states.map((state) => state.status),
          containsAll([
            LiveMediaConnectionStatus.disconnected,
            LiveMediaConnectionStatus.connecting,
            LiveMediaConnectionStatus.connected,
          ]),
        );

        await subscription.cancel();
      },
    );

    test(
      'publishLocalTracks delegates camera and microphone toggles',
      () async {
        await service.connect(
          const LiveRoomToken(
            token: 'jwt-token',
            roomName: 'room-abc',
            participantIdentity: 'host-pubkey',
            serverUrl: 'wss://livekit.example.com',
            canPublish: true,
          ),
        );

        await service.publishLocalTracks(
          cameraEnabled: true,
          microphoneEnabled: false,
        );

        expect(client.cameraEnabledCalls, [true]);
        expect(client.microphoneEnabledCalls, [false]);
        expect(service.currentState.cameraEnabled, isTrue);
        expect(service.currentState.microphoneEnabled, isFalse);
      },
    );

    test('switchCamera delegates to the room client', () async {
      await service.connect(
        const LiveRoomToken(
          token: 'jwt-token',
          roomName: 'room-abc',
          participantIdentity: 'host-pubkey',
          serverUrl: 'wss://livekit.example.com',
          canPublish: true,
        ),
      );

      await service.switchCamera();

      expect(client.switchCameraCalls, 1);
    });

    test('disconnect resets the state to disconnected', () async {
      await service.connect(
        const LiveRoomToken(
          token: 'jwt-token',
          roomName: 'room-abc',
          participantIdentity: 'audience-pubkey',
          serverUrl: 'wss://livekit.example.com',
          canPublish: false,
        ),
      );

      await service.disconnect();

      expect(client.disconnectCalls, 1);
      expect(
        service.currentState.status,
        LiveMediaConnectionStatus.disconnected,
      );
      expect(service.currentState.canPublish, isFalse);
      expect(service.currentState.cameraEnabled, isFalse);
      expect(service.currentState.microphoneEnabled, isFalse);
    });
  });
}

class _FakeLiveKitRoomClient implements LiveKitRoomClient {
  final StreamController<LiveKitRoomClientEvent> _eventsController =
      StreamController<LiveKitRoomClientEvent>.broadcast();

  int prepareCalls = 0;
  int connectCalls = 0;
  int disconnectCalls = 0;
  int switchCameraCalls = 0;
  String? lastUrl;
  String? lastToken;
  final List<bool> cameraEnabledCalls = <bool>[];
  final List<bool> microphoneEnabledCalls = <bool>[];

  @override
  Stream<LiveKitRoomClientEvent> get events => _eventsController.stream;

  @override
  Future<void> connect(String serverUrl, String token) async {
    connectCalls += 1;
    lastUrl = serverUrl;
    lastToken = token;
    _eventsController.add(LiveKitRoomClientEvent.connected);
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls += 1;
    _eventsController.add(LiveKitRoomClientEvent.disconnected);
  }

  @override
  Future<void> prepareConnection(String serverUrl, String token) async {
    prepareCalls += 1;
    lastUrl = serverUrl;
    lastToken = token;
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    cameraEnabledCalls.add(enabled);
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    microphoneEnabledCalls.add(enabled);
  }

  @override
  Future<void> switchCamera() async {
    switchCameraCalls += 1;
  }

  @override
  Future<void> dispose() async {
    if (!_eventsController.isClosed) {
      await _eventsController.close();
    }
  }
}
