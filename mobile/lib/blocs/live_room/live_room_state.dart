import 'package:equatable/equatable.dart';
import 'package:openvine/models/live/live_presence.dart';
import 'package:openvine/models/live/live_role.dart';
import 'package:openvine/models/live/live_room.dart';
import 'package:openvine/models/live/live_session.dart';
import 'package:openvine/services/livekit_room_service.dart';

enum LiveRoomStatus { initial, loading, ready, failure }

const int maxActiveVideoSpeakers = 4;

class LiveRoomState extends Equatable {
  const LiveRoomState({
    this.status = LiveRoomStatus.initial,
    this.room,
    this.session,
    this.role,
    this.presence = const <LivePresence>[],
    this.mediaState = const LiveMediaState(),
    this.errorMessage,
    this.stageSpeakerPubkeys,
  });

  final LiveRoomStatus status;
  final LiveRoom? room;
  final LiveSession? session;
  final LiveRole? role;
  final List<LivePresence> presence;
  final LiveMediaState mediaState;
  final String? errorMessage;
  final List<String>? stageSpeakerPubkeys;

  bool get canModerate => role?.canModerate ?? false;

  bool get canPublish => role?.canPublish ?? false;

  String? get sessionAddress {
    final currentRoom = room;
    final currentSession = session;
    if (currentRoom == null || currentSession == null) {
      return null;
    }

    return '30313:${currentRoom.hostPubkey}:${currentSession.id}';
  }

  List<String> get speakerPubkeys {
    final stageSpeakerPubkeys = this.stageSpeakerPubkeys;
    if (stageSpeakerPubkeys != null) {
      return List<String>.unmodifiable(stageSpeakerPubkeys);
    }

    final speakers = <String>{};
    final currentSession = session;
    if (currentSession != null) {
      speakers.addAll(currentSession.speakerPubkeys);
    }
    for (final member in presence) {
      if (member.role.canPublish) {
        speakers.add(member.pubkey);
      }
    }
    return speakers.toList(growable: false);
  }

  List<LivePresence> get raisedHands {
    return presence
        .where(
          (member) =>
              member.handRaised && !speakerPubkeys.contains(member.pubkey),
        )
        .toList(growable: false);
  }

  bool get speakerCapacityReached =>
      speakerPubkeys.length >= maxActiveVideoSpeakers;

  LiveRoomState copyWith({
    LiveRoomStatus? status,
    LiveRoom? room,
    LiveSession? session,
    bool clearSession = false,
    LiveRole? role,
    List<LivePresence>? presence,
    LiveMediaState? mediaState,
    String? errorMessage,
    bool clearErrorMessage = false,
    List<String>? stageSpeakerPubkeys,
    bool clearStageSpeakerPubkeys = false,
  }) {
    return LiveRoomState(
      status: status ?? this.status,
      room: room ?? this.room,
      session: clearSession ? null : (session ?? this.session),
      role: role ?? this.role,
      presence: presence ?? this.presence,
      mediaState: mediaState ?? this.mediaState,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      stageSpeakerPubkeys: clearStageSpeakerPubkeys
          ? null
          : (stageSpeakerPubkeys ?? this.stageSpeakerPubkeys),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    room,
    session,
    role,
    presence,
    mediaState,
    errorMessage,
    stageSpeakerPubkeys,
  ];
}
