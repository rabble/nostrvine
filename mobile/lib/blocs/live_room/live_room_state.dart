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
    this.dismissedHandPubkeys = const <String>[],
    this.mutedParticipantPubkeys = const <String>[],
    this.mutedChatParticipantPubkeys = const <String>[],
    this.removedParticipantPubkeys = const <String>[],
    this.currentUserHandRaised = false,
  });

  final LiveRoomStatus status;
  final LiveRoom? room;
  final LiveSession? session;
  final LiveRole? role;
  final List<LivePresence> presence;
  final LiveMediaState mediaState;
  final String? errorMessage;
  final List<String>? stageSpeakerPubkeys;
  final List<String> dismissedHandPubkeys;
  final List<String> mutedParticipantPubkeys;
  final List<String> mutedChatParticipantPubkeys;
  final List<String> removedParticipantPubkeys;
  final bool currentUserHandRaised;

  bool get canModerate => role?.canModerate ?? false;

  bool get canPublish => role?.canPublish ?? false;

  List<LivePresence> get visiblePresence {
    if (removedParticipantPubkeys.isEmpty) {
      return presence;
    }

    return presence
        .where((member) => !removedParticipantPubkeys.contains(member.pubkey))
        .toList(growable: false);
  }

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
      return stageSpeakerPubkeys
          .where((pubkey) => !removedParticipantPubkeys.contains(pubkey))
          .toList(growable: false);
    }

    final speakers = <String>{};
    final currentSession = session;
    if (currentSession != null) {
      speakers.addAll(currentSession.speakerPubkeys);
    }
    speakers.removeAll(removedParticipantPubkeys);
    for (final member in visiblePresence) {
      if (member.role.canPublish) {
        speakers.add(member.pubkey);
      }
    }
    return speakers.toList(growable: false);
  }

  List<LivePresence> get raisedHands {
    return visiblePresence
        .where(
          (member) =>
              member.handRaised &&
              !speakerPubkeys.contains(member.pubkey) &&
              !dismissedHandPubkeys.contains(member.pubkey),
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
    List<String>? dismissedHandPubkeys,
    bool clearDismissedHandPubkeys = false,
    List<String>? mutedParticipantPubkeys,
    bool clearMutedParticipantPubkeys = false,
    List<String>? mutedChatParticipantPubkeys,
    bool clearMutedChatParticipantPubkeys = false,
    List<String>? removedParticipantPubkeys,
    bool clearRemovedParticipantPubkeys = false,
    bool? currentUserHandRaised,
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
      dismissedHandPubkeys: clearDismissedHandPubkeys
          ? const <String>[]
          : (dismissedHandPubkeys ?? this.dismissedHandPubkeys),
      mutedParticipantPubkeys: clearMutedParticipantPubkeys
          ? const <String>[]
          : (mutedParticipantPubkeys ?? this.mutedParticipantPubkeys),
      mutedChatParticipantPubkeys: clearMutedChatParticipantPubkeys
          ? const <String>[]
          : (mutedChatParticipantPubkeys ?? this.mutedChatParticipantPubkeys),
      removedParticipantPubkeys: clearRemovedParticipantPubkeys
          ? const <String>[]
          : (removedParticipantPubkeys ?? this.removedParticipantPubkeys),
      currentUserHandRaised:
          currentUserHandRaised ?? this.currentUserHandRaised,
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
    dismissedHandPubkeys,
    mutedParticipantPubkeys,
    mutedChatParticipantPubkeys,
    removedParticipantPubkeys,
    currentUserHandRaised,
  ];
}
