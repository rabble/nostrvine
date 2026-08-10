// ABOUTME: State for VideoCollaboratorStatusCubit.
// ABOUTME: Status enum + per-pubkey map; no error strings in state.

part of 'video_collaborator_status_cubit.dart';

enum VideoCollaboratorStatusLoad { loading, ready, failure }

class VideoCollaboratorStatusState extends Equatable {
  const VideoCollaboratorStatusState({
    this.load = VideoCollaboratorStatusLoad.loading,
    this.statusByPubkey = const {},
    this.isResolved = false,
  });

  final VideoCollaboratorStatusLoad load;
  final Map<String, CollaboratorStatus> statusByPubkey;

  /// Whether the acceptance query has finished (relay EOSE).
  ///
  /// Distinct from [load]: `ready` means a snapshot arrived, which happens
  /// immediately and before any relay answer. Surfaces that hide unconfirmed
  /// collaborators must gate on this instead. A failure before EOSE leaves it
  /// false, so an unreachable relay keeps third-party surfaces hidden rather
  /// than falling back to crediting unconfirmed pubkeys.
  final bool isResolved;

  CollaboratorStatus statusFor(String pubkey) =>
      statusByPubkey[pubkey] ?? CollaboratorStatus.pending;

  VideoCollaboratorStatusState copyWith({
    VideoCollaboratorStatusLoad? load,
    Map<String, CollaboratorStatus>? statusByPubkey,
    bool? isResolved,
  }) {
    return VideoCollaboratorStatusState(
      load: load ?? this.load,
      statusByPubkey: statusByPubkey ?? this.statusByPubkey,
      isResolved: isResolved ?? this.isResolved,
    );
  }

  @override
  List<Object?> get props => [load, statusByPubkey, isResolved];
}
