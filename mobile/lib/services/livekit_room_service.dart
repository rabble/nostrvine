import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:openvine/models/live/live_room_token.dart';

@immutable
enum LiveMediaConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  audioOnly,
  failed,
}

@immutable
class LiveMediaState extends Equatable {
  const LiveMediaState({
    this.status = LiveMediaConnectionStatus.disconnected,
    this.canPublish = false,
    this.cameraEnabled = false,
    this.microphoneEnabled = false,
  });

  final LiveMediaConnectionStatus status;
  final bool canPublish;
  final bool cameraEnabled;
  final bool microphoneEnabled;

  LiveMediaState copyWith({
    LiveMediaConnectionStatus? status,
    bool? canPublish,
    bool? cameraEnabled,
    bool? microphoneEnabled,
  }) {
    return LiveMediaState(
      status: status ?? this.status,
      canPublish: canPublish ?? this.canPublish,
      cameraEnabled: cameraEnabled ?? this.cameraEnabled,
      microphoneEnabled: microphoneEnabled ?? this.microphoneEnabled,
    );
  }

  @override
  List<Object?> get props => [
    status,
    canPublish,
    cameraEnabled,
    microphoneEnabled,
  ];
}

enum LiveKitRoomClientEvent { connected, reconnecting, disconnected }

abstract class LiveKitRoomClient {
  Stream<LiveKitRoomClientEvent> get events;

  Future<void> prepareConnection(String serverUrl, String token);

  Future<void> connect(String serverUrl, String token);

  Future<void> disconnect();

  Future<void> setCameraEnabled(bool enabled);

  Future<void> setMicrophoneEnabled(bool enabled);

  Future<void> switchCamera();

  Future<void> enableAudioOnly();

  Future<void> dispose();
}

class LiveKitRoomService {
  LiveKitRoomService({
    LiveKitRoomClient Function()? clientFactory,
  }) : _client = (clientFactory ?? _defaultClientFactory).call() {
    _eventsSubscription = _client.events.listen(_handleClientEvent);
  }

  final LiveKitRoomClient _client;
  final StreamController<LiveMediaState> _stateController =
      StreamController<LiveMediaState>.broadcast(sync: true);
  late final StreamSubscription<LiveKitRoomClientEvent> _eventsSubscription;

  LiveMediaState _currentState = const LiveMediaState();
  bool _isDisposed = false;
  bool _disconnectRequested = false;

  static LiveKitRoomClient _defaultClientFactory() => _SdkLiveKitRoomClient();

  LiveMediaState get currentState => _currentState;

  Stream<LiveMediaState> watchState() {
    late final StreamController<LiveMediaState> controller;
    StreamSubscription<LiveMediaState>? subscription;

    controller = StreamController<LiveMediaState>(
      sync: true,
      onListen: () {
        controller.add(_currentState);
        subscription = _stateController.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
      },
      onCancel: () async {
        await subscription?.cancel();
      },
    );

    return controller.stream;
  }

  Future<void> connect(LiveRoomToken token) async {
    _disconnectRequested = false;
    _updateState(
      LiveMediaState(
        status: LiveMediaConnectionStatus.connecting,
        canPublish: token.canPublish,
      ),
    );

    try {
      await _client.prepareConnection(token.serverUrl, token.token);
      await _client.connect(token.serverUrl, token.token);
      _updateState(
        _currentState.copyWith(
          status: _connectedStatusForCurrentTracks(),
        ),
      );
    } catch (_) {
      _updateState(
        LiveMediaState(
          status: LiveMediaConnectionStatus.failed,
          canPublish: token.canPublish,
        ),
      );
      rethrow;
    }
  }

  Future<void> publishLocalTracks({
    required bool cameraEnabled,
    required bool microphoneEnabled,
  }) async {
    if (!_currentState.canPublish) {
      return;
    }

    await setCameraEnabled(cameraEnabled);
    await setMicrophoneEnabled(microphoneEnabled);
  }

  Future<void> setCameraEnabled(bool enabled) async {
    if (!_currentState.canPublish) {
      return;
    }

    await _client.setCameraEnabled(enabled);
    _updateState(
      _currentState.copyWith(
        status: _localTrackStatus(
          cameraEnabled: enabled,
          microphoneEnabled: _currentState.microphoneEnabled,
        ),
        cameraEnabled: enabled,
      ),
    );
  }

  Future<void> setMicrophoneEnabled(bool enabled) async {
    if (!_currentState.canPublish) {
      return;
    }

    await _client.setMicrophoneEnabled(enabled);
    _updateState(
      _currentState.copyWith(
        status: _localTrackStatus(
          cameraEnabled: _currentState.cameraEnabled,
          microphoneEnabled: enabled,
        ),
        microphoneEnabled: enabled,
      ),
    );
  }

  Future<void> switchCamera() async {
    if (!_currentState.canPublish) {
      return;
    }

    await _client.switchCamera();
  }

  Future<void> enableAudioOnly() async {
    if (!_currentState.canPublish) {
      return;
    }

    await _client.setCameraEnabled(false);
    await _client.setMicrophoneEnabled(true);
    _updateState(
      _currentState.copyWith(
        status: LiveMediaConnectionStatus.audioOnly,
        cameraEnabled: false,
        microphoneEnabled: true,
      ),
    );
  }

  Future<void> disconnect() async {
    _disconnectRequested = true;
    try {
      await _client.disconnect();
    } finally {
      _updateState(const LiveMediaState());
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;

    await _eventsSubscription.cancel();
    await _client.dispose();
    await _stateController.close();
  }

  void _handleClientEvent(LiveKitRoomClientEvent event) {
    switch (event) {
      case LiveKitRoomClientEvent.connected:
        _disconnectRequested = false;
        _updateState(
          _currentState.copyWith(
            status: _connectedStatusForCurrentTracks(),
          ),
        );
      case LiveKitRoomClientEvent.reconnecting:
        _updateState(
          _currentState.copyWith(
            status: LiveMediaConnectionStatus.reconnecting,
          ),
        );
      case LiveKitRoomClientEvent.disconnected:
        if (_disconnectRequested) {
          _updateState(const LiveMediaState());
          return;
        }
        _updateState(
          _currentState.copyWith(
            status: LiveMediaConnectionStatus.failed,
            cameraEnabled: false,
          ),
        );
    }
  }

  void _updateState(LiveMediaState nextState) {
    if (_isDisposed || _stateController.isClosed) {
      return;
    }

    _currentState = nextState;
    _stateController.add(nextState);
  }

  LiveMediaConnectionStatus _localTrackStatus({
    required bool cameraEnabled,
    required bool microphoneEnabled,
  }) {
    final currentStatus = _currentState.status;
    if (currentStatus == LiveMediaConnectionStatus.connecting ||
        currentStatus == LiveMediaConnectionStatus.reconnecting ||
        currentStatus == LiveMediaConnectionStatus.failed ||
        currentStatus == LiveMediaConnectionStatus.disconnected) {
      return currentStatus;
    }

    if (!cameraEnabled && microphoneEnabled) {
      return LiveMediaConnectionStatus.audioOnly;
    }

    return LiveMediaConnectionStatus.connected;
  }

  LiveMediaConnectionStatus _connectedStatusForCurrentTracks() {
    if (!_currentState.cameraEnabled && _currentState.microphoneEnabled) {
      return LiveMediaConnectionStatus.audioOnly;
    }

    return LiveMediaConnectionStatus.connected;
  }
}

class _SdkLiveKitRoomClient implements LiveKitRoomClient {
  _SdkLiveKitRoomClient({
    lk.Room? room,
  }) : _room = room ?? lk.Room() {
    _roomEventsListener = _room.createListener();
    _roomEventsListener.on<lk.RoomConnectedEvent>(
      (_) => _eventsController.add(LiveKitRoomClientEvent.connected),
    );
    _roomEventsListener.on<lk.RoomReconnectedEvent>(
      (_) => _eventsController.add(LiveKitRoomClientEvent.connected),
    );
    _roomEventsListener.on<lk.RoomReconnectingEvent>(
      (_) => _eventsController.add(LiveKitRoomClientEvent.reconnecting),
    );
    _roomEventsListener.on<lk.RoomDisconnectedEvent>(
      (_) => _eventsController.add(LiveKitRoomClientEvent.disconnected),
    );
  }

  final lk.Room _room;
  final StreamController<LiveKitRoomClientEvent> _eventsController =
      StreamController<LiveKitRoomClientEvent>.broadcast();
  late final lk.EventsListener<lk.RoomEvent> _roomEventsListener;

  @override
  Stream<LiveKitRoomClientEvent> get events => _eventsController.stream;

  @override
  Future<void> prepareConnection(String serverUrl, String token) {
    return _room.prepareConnection(serverUrl, token);
  }

  @override
  Future<void> connect(String serverUrl, String token) {
    return _room.connect(serverUrl, token);
  }

  @override
  Future<void> disconnect() {
    return _room.disconnect();
  }

  @override
  Future<void> setCameraEnabled(bool enabled) async {
    final participant = _room.localParticipant;
    if (participant == null) {
      return;
    }

    await participant.setCameraEnabled(enabled);
  }

  @override
  Future<void> setMicrophoneEnabled(bool enabled) async {
    final participant = _room.localParticipant;
    if (participant == null) {
      return;
    }

    await participant.setMicrophoneEnabled(enabled);
  }

  @override
  Future<void> switchCamera() async {
    final devices = await lk.Hardware.instance.videoInputs();
    if (devices.length < 2) {
      return;
    }

    final currentDeviceId =
        lk.Hardware.instance.selectedVideoInput?.deviceId ??
        _room.roomOptions.defaultCameraCaptureOptions.deviceId;
    final currentIndex = devices.indexWhere(
      (device) => device.deviceId == currentDeviceId,
    );
    final nextIndex = currentIndex == -1
        ? 0
        : (currentIndex + 1) % devices.length;

    await _room.setVideoInputDevice(devices[nextIndex]);
  }

  @override
  Future<void> enableAudioOnly() async {
    final participant = _room.localParticipant;
    if (participant == null) {
      return;
    }

    await participant.setCameraEnabled(false);
    await participant.setMicrophoneEnabled(true);
  }

  @override
  Future<void> dispose() async {
    await _roomEventsListener.dispose();
    if (!_eventsController.isClosed) {
      await _eventsController.close();
    }
    await _room.dispose();
  }
}
