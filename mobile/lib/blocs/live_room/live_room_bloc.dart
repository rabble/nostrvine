import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:openvine/blocs/live_room/live_room_event.dart';
import 'package:openvine/blocs/live_room/live_room_state.dart';
import 'package:openvine/models/live/live_presence.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
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
  }) : _liveRepository = liveRepository,
       _liveApiService = liveApiService,
       _liveKitRoomService = liveKitRoomService,
       super(const LiveRoomState()) {
    on<LiveRoomJoinRequested>(_onJoinRequested);
    on<LiveRoomSessionsUpdated>(_onSessionsUpdated);
    on<LiveRoomPresenceUpdated>(_onPresenceUpdated);
    on<LiveRoomMediaStateChanged>(_onMediaStateChanged);
    on<LiveRoomSubscriptionFailed>(_onSubscriptionFailed);

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

  StreamSubscription<List<LiveSession>>? _sessionsSubscription;
  StreamSubscription<List<LivePresence>>? _presenceSubscription;
  late final StreamSubscription<LiveMediaState> _mediaSubscription;
  String? _presenceSessionAddress;
  String? _connectedSessionKey;

  Future<void> _onJoinRequested(
    LiveRoomJoinRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    await _sessionsSubscription?.cancel();
    await _presenceSubscription?.cancel();
    _presenceSessionAddress = null;
    _connectedSessionKey = null;

    emit(
      state.copyWith(
        status: LiveRoomStatus.loading,
        room: event.room,
        role: event.role,
        clearSession: true,
        presence: const <LivePresence>[],
        mediaState: const LiveMediaState(),
        clearErrorMessage: true,
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
    emit(
      state.copyWith(
        status: LiveRoomStatus.ready,
        session: nextSession,
        clearSession: nextSession == null,
        presence: nextSession == null ? const <LivePresence>[] : state.presence,
        clearErrorMessage: true,
      ),
    );

    final currentRoom = state.room;
    final currentRole = state.role;
    if (nextSession == null || currentRoom == null || currentRole == null) {
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
        role: currentRole,
        emit: emit,
      );
    }
  }

  void _onPresenceUpdated(
    LiveRoomPresenceUpdated event,
    Emitter<LiveRoomState> emit,
  ) {
    emit(
      state.copyWith(
        presence: event.presence,
        clearErrorMessage: true,
      ),
    );
  }

  void _onMediaStateChanged(
    LiveRoomMediaStateChanged event,
    Emitter<LiveRoomState> emit,
  ) {
    emit(state.copyWith(mediaState: event.mediaState));
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
      final joinToken = await _liveApiService.fetchJoinToken(
        roomId: room.id,
        role: role,
      );
      await _liveKitRoomService.connect(joinToken);
      _connectedSessionKey = sessionKey;
    } catch (error) {
      _connectedSessionKey = null;
      emit(
        state.copyWith(
          status: LiveRoomStatus.failure,
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

  @override
  Future<void> close() async {
    await _sessionsSubscription?.cancel();
    await _presenceSubscription?.cancel();
    await _mediaSubscription.cancel();
    await _liveKitRoomService.disconnect();
    return super.close();
  }
}
