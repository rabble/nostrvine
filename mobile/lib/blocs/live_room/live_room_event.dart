import 'package:equatable/equatable.dart';
import 'package:openvine/models/live/live_presence.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/services/livekit_room_service.dart';

sealed class LiveRoomEvent extends Equatable {
  const LiveRoomEvent();

  @override
  List<Object?> get props => const <Object?>[];
}

class LiveRoomJoinRequested extends LiveRoomEvent {
  const LiveRoomJoinRequested({
    required this.room,
    required this.role,
  });

  final LiveRoom room;
  final LiveRole role;

  @override
  List<Object?> get props => <Object?>[room, role];
}

class LiveRoomSessionsUpdated extends LiveRoomEvent {
  const LiveRoomSessionsUpdated(this.sessions);

  final List<LiveSession> sessions;

  @override
  List<Object?> get props => <Object?>[sessions];
}

class LiveRoomPresenceUpdated extends LiveRoomEvent {
  const LiveRoomPresenceUpdated(this.presence);

  final List<LivePresence> presence;

  @override
  List<Object?> get props => <Object?>[presence];
}

class LiveRoomMediaStateChanged extends LiveRoomEvent {
  const LiveRoomMediaStateChanged(this.mediaState);

  final LiveMediaState mediaState;

  @override
  List<Object?> get props => <Object?>[mediaState];
}

class LiveRoomSubscriptionFailed extends LiveRoomEvent {
  const LiveRoomSubscriptionFailed(this.error);

  final Object error;

  @override
  List<Object?> get props => <Object?>[error];
}
