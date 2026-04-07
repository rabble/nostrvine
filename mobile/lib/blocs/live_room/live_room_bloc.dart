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
    on<ToggleHandRaiseRequested>(_onToggleHandRaiseRequested);
    on<EndSessionRequested>(_onEndSessionRequested);
    on<UpdateRoomMetadataRequested>(_onUpdateRoomMetadataRequested);
    on<ApproveRaisedHandRequested>(_onApproveRaisedHandRequested);
    on<DenyRaisedHandRequested>(_onDenyRaisedHandRequested);
    on<MuteParticipantRequested>(_onMuteParticipantRequested);
    on<MuteChatParticipantRequested>(_onMuteChatParticipantRequested);
    on<RemoveParticipantRequested>(_onRemoveParticipantRequested);
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
        clearDismissedHandPubkeys: true,
        clearMutedParticipantPubkeys: true,
        clearMutedChatParticipantPubkeys: true,
        clearRemovedParticipantPubkeys: true,
        currentUserHandRaised: false,
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
    final currentSession = state.session;
    final sessionChanged = currentSession?.id != nextSession?.id;
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
        presence: nextSession == null || sessionChanged
            ? const <LivePresence>[]
            : state.presence,
        clearErrorMessage: true,
        clearStageSpeakerPubkeys: nextSession == null || sessionChanged,
        clearDismissedHandPubkeys: nextSession == null || sessionChanged,
        clearMutedParticipantPubkeys: nextSession == null || sessionChanged,
        clearMutedChatParticipantPubkeys: nextSession == null || sessionChanged,
        clearRemovedParticipantPubkeys: nextSession == null || sessionChanged,
        currentUserHandRaised:
            !(nextSession == null || sessionChanged) &&
            _isCurrentUserHandRaised(state.presence),
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
        currentUserHandRaised: _isCurrentUserHandRaised(event.presence),
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

  Future<void> _onToggleHandRaiseRequested(
    ToggleHandRaiseRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    final room = state.room;
    final session = state.session;
    final role = state.role;
    if (room == null ||
        session == null ||
        role == null ||
        state.canPublish ||
        _currentUserPubkey.isEmpty) {
      return;
    }

    final nextHandRaised = !state.currentUserHandRaised;
    final sessionAddress = _sessionAddress(room, session);

    try {
      await _liveRepository.publishPresence(
        sessionAddress: sessionAddress,
        role: role,
        handRaised: nextHandRaised,
      );

      final nextPresence = List<LivePresence>.from(state.presence);
      final nextMember = LivePresence(
        sessionId: session.id,
        pubkey: _currentUserPubkey,
        role: role,
        handRaised: nextHandRaised,
        updatedAt: DateTime.now().toUtc(),
      );
      final existingIndex = nextPresence.indexWhere(
        (member) => member.pubkey == _currentUserPubkey,
      );
      if (existingIndex == -1) {
        nextPresence.add(nextMember);
      } else {
        nextPresence[existingIndex] = nextMember;
      }

      emit(
        state.copyWith(
          presence: nextPresence,
          currentUserHandRaised: nextHandRaised,
          clearErrorMessage: true,
        ),
      );
    } catch (error) {
      emit(state.copyWith(errorMessage: '$error'));
    }
  }

  Future<void> _onEndSessionRequested(
    EndSessionRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    final room = state.room;
    final session = state.session;
    if (room == null || session == null || !state.canModerate) {
      return;
    }

    final endedSession = session.copyWith(
      status: LiveSessionStatus.ended,
      endedAt: DateTime.now().toUtc(),
    );

    try {
      await _liveApiService.endSession(
        roomId: room.id,
        sessionId: session.id,
      );
      await _liveRepository.publishSession(
        session: endedSession,
        roomAddress: room.address,
        hostPubkey: room.hostPubkey,
      );
      _connectedSessionKey = null;
      await _presenceSubscription?.cancel();
      _presenceSubscription = null;
      _presenceSessionAddress = null;
      await _liveKitRoomService.disconnect();
      emit(
        state.copyWith(
          session: endedSession,
          presence: const <LivePresence>[],
          mediaState: const LiveMediaState(),
          stageSpeakerPubkeys: const <String>[],
          clearDismissedHandPubkeys: true,
          clearMutedParticipantPubkeys: true,
          clearMutedChatParticipantPubkeys: true,
          clearRemovedParticipantPubkeys: true,
          currentUserHandRaised: false,
          clearErrorMessage: true,
        ),
      );
    } catch (error) {
      emit(state.copyWith(errorMessage: '$error'));
    }
  }

  Future<void> _onUpdateRoomMetadataRequested(
    UpdateRoomMetadataRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    final room = state.room;
    if (room == null || !state.canModerate) {
      return;
    }

    final nextRoom = room.copyWith(
      title: event.title ?? room.title,
      summary: event.summary ?? room.summary,
      visibility: event.visibility ?? room.visibility,
    );

    try {
      await _liveRepository.publishRoom(nextRoom);
      emit(
        state.copyWith(
          room: nextRoom,
          clearErrorMessage: true,
        ),
      );
    } catch (error) {
      emit(state.copyWith(errorMessage: '$error'));
    }
  }

  Future<void> _onApproveRaisedHandRequested(
    ApproveRaisedHandRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    await _setParticipantHandDecision(
      emit: emit,
      pubkey: event.pubkey,
      shouldApprove: true,
    );
  }

  Future<void> _onDenyRaisedHandRequested(
    DenyRaisedHandRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    await _setParticipantHandDecision(
      emit: emit,
      pubkey: event.pubkey,
      shouldApprove: false,
    );
  }

  Future<void> _onMuteParticipantRequested(
    MuteParticipantRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    await _setParticipantMuteState(
      emit: emit,
      pubkey: event.pubkey,
      isMuted: true,
    );
  }

  Future<void> _onMuteChatParticipantRequested(
    MuteChatParticipantRequested event,
    Emitter<LiveRoomState> emit,
  ) {
    final nextMutedChatParticipants = List<String>.from(
      state.mutedChatParticipantPubkeys,
    );
    if (!nextMutedChatParticipants.contains(event.pubkey)) {
      nextMutedChatParticipants.add(event.pubkey);
    }

    emit(
      state.copyWith(
        mutedChatParticipantPubkeys: nextMutedChatParticipants,
        clearErrorMessage: true,
      ),
    );
    return Future<void>.value();
  }

  Future<void> _onRemoveParticipantRequested(
    RemoveParticipantRequested event,
    Emitter<LiveRoomState> emit,
  ) async {
    await _removeParticipant(emit: emit, pubkey: event.pubkey);
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

  bool _isCurrentUserHandRaised(List<LivePresence> presence) {
    if (_currentUserPubkey.isEmpty) {
      return false;
    }

    for (final member in presence) {
      if (member.pubkey == _currentUserPubkey) {
        return member.handRaised;
      }
    }

    return false;
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

  Future<void> _setParticipantHandDecision({
    required Emitter<LiveRoomState> emit,
    required String pubkey,
    required bool shouldApprove,
  }) async {
    final room = state.room;
    final session = state.session;
    if (room == null || session == null || !state.canModerate) {
      return;
    }

    if (shouldApprove && !state.speakerPubkeys.contains(pubkey)) {
      await _updateSpeakerRoster(
        emit: emit,
        pubkey: pubkey,
        shouldPromote: true,
      );
    } else if (!shouldApprove && state.speakerPubkeys.contains(pubkey)) {
      await _updateSpeakerRoster(
        emit: emit,
        pubkey: pubkey,
        shouldPromote: false,
      );
    }

    final nextDismissedHands = List<String>.from(state.dismissedHandPubkeys);
    final nextRemovedParticipants = List<String>.from(
      state.removedParticipantPubkeys,
    );
    if (shouldApprove) {
      nextDismissedHands.remove(pubkey);
      nextRemovedParticipants.remove(pubkey);
    } else if (!nextDismissedHands.contains(pubkey)) {
      nextDismissedHands.add(pubkey);
    }

    emit(
      state.copyWith(
        dismissedHandPubkeys: nextDismissedHands,
        removedParticipantPubkeys: nextRemovedParticipants,
        clearErrorMessage: true,
      ),
    );
  }

  Future<void> _setParticipantMuteState({
    required Emitter<LiveRoomState> emit,
    required String pubkey,
    required bool isMuted,
  }) {
    final nextMutedParticipants = List<String>.from(
      state.mutedParticipantPubkeys,
    );
    if (isMuted) {
      if (!nextMutedParticipants.contains(pubkey)) {
        nextMutedParticipants.add(pubkey);
      }
    } else {
      nextMutedParticipants.remove(pubkey);
    }

    emit(
      state.copyWith(
        mutedParticipantPubkeys: nextMutedParticipants,
        clearErrorMessage: true,
      ),
    );
    return Future<void>.value();
  }

  Future<void> _removeParticipant({
    required Emitter<LiveRoomState> emit,
    required String pubkey,
  }) async {
    final room = state.room;
    final session = state.session;
    if (room == null || session == null || !state.canModerate) {
      return;
    }

    final nextRemovedParticipants = List<String>.from(
      state.removedParticipantPubkeys,
    );
    if (!nextRemovedParticipants.contains(pubkey)) {
      nextRemovedParticipants.add(pubkey);
    }

    final nextMutedParticipants = List<String>.from(
      state.mutedParticipantPubkeys,
    );
    if (!nextMutedParticipants.contains(pubkey)) {
      nextMutedParticipants.add(pubkey);
    }
    final nextMutedChatParticipants = List<String>.from(
      state.mutedChatParticipantPubkeys,
    );
    if (!nextMutedChatParticipants.contains(pubkey)) {
      nextMutedChatParticipants.add(pubkey);
    }
    final nextDismissedHands = List<String>.from(state.dismissedHandPubkeys);
    nextDismissedHands.remove(pubkey);

    if (state.speakerPubkeys.contains(pubkey)) {
      await _updateSpeakerRoster(
        emit: emit,
        pubkey: pubkey,
        shouldPromote: false,
      );
    }

    emit(
      state.copyWith(
        mutedParticipantPubkeys: nextMutedParticipants,
        mutedChatParticipantPubkeys: nextMutedChatParticipants,
        dismissedHandPubkeys: nextDismissedHands,
        removedParticipantPubkeys: nextRemovedParticipants,
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
