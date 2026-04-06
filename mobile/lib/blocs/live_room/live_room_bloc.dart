import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:openvine/blocs/live_room/live_room_event.dart';
import 'package:openvine/blocs/live_room/live_room_state.dart';
import 'package:openvine/models/live/live_presence.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_room_token.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/repositories/live_repository.dart';
import 'package:openvine/services/live_api_service.dart';
import 'package:openvine/services/livekit_room_service.dart';

export 'package:openvine/blocs/live_room/live_room_event.dart';
export 'package:openvine/blocs/live_room/live_room_state.dart';

class LiveRoomBloc extends Bloc<LiveRoomEvent, LiveRoomState> {
  LiveRoomBloc({
    required LiveRepository liveRepository,
    required LiveApiService liveApiService,
    required LiveKitRoomService liveKitRoomService,
    String currentUserPubkey = '',
  }) : _liveRepository = liveRepository,
       _liveApiService = liveApiService,
       _liveKitRoomService = liveKitRoomService,
       _currentUserPubkey = currentUserPubkey,
       super(const LiveRoomState()) {
    on<LiveRoomJoinRequested>(_onJoinRequested);
    on<LiveRoomSessionsUpdated>(_onSessionsUpdated);
    on<LiveRoomPresenceUpdated>(_onPresenceUpdated);
    on<LiveRoomMediaStateChanged>(_onMediaStateChanged);
    on<LiveRoomSubscriptionFailed>(_onSubscriptionFailed);
    on<ToggleMicrophoneRequested>(_onToggleMicrophoneRequested);
    on<ToggleCameraRequested>(_onToggleCameraRequested);
    on<SwitchCameraRequested>(_onSwitchCameraRequested);
    on<PromoteSpeakerRequested>(_onPromoteSpeakerRequested);
    on<DemoteSpeakerRequested>(_onDemoteSpeakerRequested);
    on<EnableAudioOnlyRequested>(_onEnableAudioOnlyRequested);
    on<LiveRoomAppForegroundChanged>(_onAppForegroundChanged);

    _mediaSubscription = _liveKitRoomService.watchState().listen(
      (mediaState) => add(LiveRoomMediaStateChanged(mediaState)),
      onError: (Object error, StackTrace _) {
        add(LiveRoomSubscriptionFailed(error));
      },
    );
  }

  final LiveRepository _liveRepository;
  final LiveApiService _liveApiService;
  final LiveKitRoomService _liveKitRoomService;
  final String _currentUserPubkey;

  StreamSubscription<List<LiveSession>>? _sessionsSubscription;
  StreamSubscription<List<LivePresence>>? _presenceSubscription;
  late final StreamSubscription<LiveMediaState> _mediaSubscription;
  String? _presenceSessionAddress;
  String? _connectedSessionKey;
  final Map<LiveRole, LiveRoomToken> _cachedJoinTokens =
      <LiveRole, LiveRoomToken>{};

  Future<void> _onJoinRequested(
    LiveRoomJoinRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    await _sessionsSubscription?.cancel();
    await _presenceSubscription?.cancel();
    _presenceSessionAddress = null;
    _connectedSessionKey = null;
    _cachedJoinTokens.clear();

    emit(
      state.copyWith(
        status: LiveRoomStatus.loading,
        room: event.room,
        role: event.role,
        clearSession: true,
        presence: const <LivePresence>[],
        mediaState: const LiveMediaState(),
        clearErrorMessage: true,
        clearStageSpeakerPubkeys: true,
      ),
    );

    _sessionsSubscription = _liveRepository
        .watchSessions(roomAddress: event.room.address)
        .listen(
          (sessions) => add(LiveRoomSessionsUpdated(sessions)),
          onError: (Object error, StackTrace _) {
            add(LiveRoomSubscriptionFailed(error));
          },
        );
  }

  Future<void> _onSessionsUpdated(
    LiveRoomSessionsUpdated event,
    Emitter<LiveRoomState> emit,
  ) async {
    final nextSession = _selectSession(event.sessions);
    final currentRoom = state.room;
    final currentRole = state.role;
    final nextRole = currentRoom == null || currentRole == null
        ? currentRole
        : _resolveRole(
            room: currentRoom,
            session: nextSession,
            presence: state.presence,
            fallbackRole: currentRole,
          );
    emit(
      state.copyWith(
        status: LiveRoomStatus.ready,
        session: nextSession,
        clearSession: nextSession == null,
        role: nextRole,
        presence: nextSession == null ? const <LivePresence>[] : state.presence,
        clearErrorMessage: true,
        clearStageSpeakerPubkeys: true,
      ),
    );

    if (nextSession == null || currentRoom == null || nextRole == null) {
      await _presenceSubscription?.cancel();
      _presenceSessionAddress = null;
      return;
    }

    final sessionAddress = _sessionAddress(currentRoom, nextSession);
    if (_presenceSessionAddress != sessionAddress) {
      await _presenceSubscription?.cancel();
      _presenceSessionAddress = sessionAddress;
      _presenceSubscription = _liveRepository
          .watchPresence(sessionAddress: sessionAddress)
          .listen(
            (presence) => add(LiveRoomPresenceUpdated(presence)),
            onError: (Object error, StackTrace _) {
              add(LiveRoomSubscriptionFailed(error));
            },
          );
    }

    if (nextSession.isLive) {
      await _connectToLiveSession(
        room: currentRoom,
        session: nextSession,
        role: nextRole,
        emit: emit,
      );
    }
  }

  Future<void> _onPresenceUpdated(
    LiveRoomPresenceUpdated event,
    Emitter<LiveRoomState> emit,
  ) async {
    final currentRoom = state.room;
    final currentSession = state.session;
    final currentRole = state.role;
    final nextRole = currentRoom == null || currentRole == null
        ? currentRole
        : _resolveRole(
            room: currentRoom,
            session: currentSession,
            presence: event.presence,
            fallbackRole: currentRole,
          );
    emit(
      state.copyWith(
        role: nextRole,
        presence: event.presence,
        clearErrorMessage: true,
      ),
    );

    if (currentRoom == null ||
        currentSession == null ||
        nextRole == null ||
        !currentSession.isLive ||
        nextRole == currentRole) {
      return;
    }

    await _connectToLiveSession(
      room: currentRoom,
      session: currentSession,
      role: nextRole,
      emit: emit,
    );
  }

  void _onMediaStateChanged(
    LiveRoomMediaStateChanged event,
    Emitter<LiveRoomState> emit,
  ) {
    emit(
      state.copyWith(
        mediaState: event.mediaState,
        clearErrorMessage:
            event.mediaState.status != LiveMediaConnectionStatus.failed,
      ),
    );
  }

  void _onSubscriptionFailed(
    LiveRoomSubscriptionFailed event,
    Emitter<LiveRoomState> emit,
  ) {
    emit(
      state.copyWith(
        status: LiveRoomStatus.failure,
        errorMessage: '${event.error}',
      ),
    );
  }

  Future<void> _onToggleMicrophoneRequested(
    ToggleMicrophoneRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    if (!state.canPublish) {
      return;
    }

    try {
      await _liveKitRoomService.setMicrophoneEnabled(
        !state.mediaState.microphoneEnabled,
      );
    } catch (error) {
      emit(state.copyWith(errorMessage: '$error'));
    }
  }

  Future<void> _onToggleCameraRequested(
    ToggleCameraRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    if (!state.canPublish) {
      return;
    }

    try {
      await _liveKitRoomService.setCameraEnabled(
        !state.mediaState.cameraEnabled,
      );
    } catch (error) {
      emit(state.copyWith(errorMessage: '$error'));
    }
  }

  Future<void> _onSwitchCameraRequested(
    SwitchCameraRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    if (!state.canPublish) {
      return;
    }

    try {
      await _liveKitRoomService.switchCamera();
    } catch (error) {
      emit(state.copyWith(errorMessage: '$error'));
    }
  }

  Future<void> _onPromoteSpeakerRequested(
    PromoteSpeakerRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    await _updateSpeakerRoster(
      emit: emit,
      pubkey: event.pubkey,
      shouldPromote: true,
    );
  }

  Future<void> _onDemoteSpeakerRequested(
    DemoteSpeakerRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    await _updateSpeakerRoster(
      emit: emit,
      pubkey: event.pubkey,
      shouldPromote: false,
    );
  }

  Future<void> _onEnableAudioOnlyRequested(
    EnableAudioOnlyRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    if (!state.canPublish) {
      return;
    }

    try {
      await _liveKitRoomService.enableAudioOnly();
    } catch (error) {
      emit(state.copyWith(errorMessage: '$error'));
    }
  }

  Future<void> _onAppForegroundChanged(
    LiveRoomAppForegroundChanged event,
    Emitter<LiveRoomState> emit,
  ) async {
    final room = state.room;
    final session = state.session;
    final role = state.role;
    if (room == null || session == null || role == null || !session.isLive) {
      return;
    }

    if (!event.isForeground) {
      if (!role.canPublish) {
        _connectedSessionKey = null;
        await _liveKitRoomService.disconnect();
      }
      return;
    }

    if (!role.canPublish) {
      await _connectToLiveSession(
        room: room,
        session: session,
        role: role,
        emit: emit,
      );
    }
  }

  Future<void> _connectToLiveSession({
    required LiveRoom room,
    required LiveSession session,
    required LiveRole role,
    required Emitter<LiveRoomState> emit,
  }) async {
    final sessionKey = '${_sessionAddress(room, session)}:${role.name}';
    if (_connectedSessionKey == sessionKey) {
      return;
    }

    try {
      if (_connectedSessionKey != null && _connectedSessionKey != sessionKey) {
        _connectedSessionKey = null;
        await _liveKitRoomService.disconnect();
      }

      var joinToken = _cachedJoinTokens[role];
      final usedCachedToken = joinToken != null;
      joinToken ??= await _liveApiService.fetchJoinToken(
        roomId: room.id,
        role: role,
      );
      _cachedJoinTokens[role] = joinToken;

      try {
        await _liveKitRoomService.connect(joinToken);
      } catch (error) {
        if (!usedCachedToken) {
          rethrow;
        }

        _cachedJoinTokens.remove(role);
        joinToken = await _liveApiService.fetchJoinToken(
          roomId: room.id,
          role: role,
        );
        _cachedJoinTokens[role] = joinToken;
        await _liveKitRoomService.connect(joinToken);
      }

      _connectedSessionKey = sessionKey;

      if (role.canPublish) {
        await _liveKitRoomService.publishLocalTracks(
          cameraEnabled: true,
          microphoneEnabled: true,
        );
      }
    } catch (error) {
      _connectedSessionKey = null;
      final mediaFailed =
          state.mediaState.status == LiveMediaConnectionStatus.failed;
      emit(
        state.copyWith(
          status: mediaFailed ? LiveRoomStatus.ready : LiveRoomStatus.failure,
          mediaState: mediaFailed
              ? state.mediaState
              : LiveMediaState(
                  status: LiveMediaConnectionStatus.failed,
                  canPublish: role.canPublish,
                ),
          errorMessage: '$error',
        ),
      );
    }
  }

  LiveSession? _selectSession(List<LiveSession> sessions) {
    for (final session in sessions) {
      if (session.status == LiveSessionStatus.live) {
        return session;
      }
    }
    return sessions.isEmpty ? null : sessions.first;
  }

  String _sessionAddress(LiveRoom room, LiveSession session) {
    return '30313:${room.hostPubkey}:${session.id}';
  }

  LiveRole _resolveRole({
    required LiveRoom room,
    required LiveSession? session,
    required List<LivePresence> presence,
    required LiveRole fallbackRole,
  }) {
    if (_currentUserPubkey.isEmpty) {
      return fallbackRole;
    }

    if (room.hostPubkey == _currentUserPubkey) {
      return LiveRole.host;
    }

    for (final member in presence) {
      if (member.pubkey == _currentUserPubkey) {
        if (member.role.canModerate) {
          return member.role;
        }
        if (member.role.canPublish) {
          return LiveRole.speaker;
        }
      }
    }

    if (session?.speakerPubkeys.contains(_currentUserPubkey) ?? false) {
      return LiveRole.speaker;
    }

    return LiveRole.audience;
  }

  Future<void> _updateSpeakerRoster({
    required Emitter<LiveRoomState> emit,
    required String pubkey,
    required bool shouldPromote,
  }) async {
    final room = state.room;
    final session = state.session;
    if (room == null || session == null || !state.canModerate) {
      return;
    }

    final nextSpeakerPubkeys = List<String>.from(state.speakerPubkeys);
    if (shouldPromote) {
      if (nextSpeakerPubkeys.contains(pubkey)) {
        return;
      }
      if (nextSpeakerPubkeys.length >= maxActiveVideoSpeakers) {
        emit(
          state.copyWith(
            errorMessage:
                'Only $maxActiveVideoSpeakers active video speakers are supported in beta.',
          ),
        );
        return;
      }
      nextSpeakerPubkeys.add(pubkey);
    } else {
      if (pubkey == room.hostPubkey) {
        return;
      }
      nextSpeakerPubkeys.remove(pubkey);
    }

    final nextSession = session.copyWith(speakerPubkeys: nextSpeakerPubkeys);
    await _liveRepository.publishSession(
      session: nextSession,
      roomAddress: room.address,
      hostPubkey: room.hostPubkey,
    );
    emit(
      state.copyWith(
        session: nextSession,
        stageSpeakerPubkeys: nextSpeakerPubkeys,
        clearErrorMessage: true,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sessionsSubscription?.cancel();
    await _presenceSubscription?.cancel();
    await _mediaSubscription.cancel();
    await _liveKitRoomService.disconnect();
    return super.close();
  }
}
