// ABOUTME: State for VideoCollaboratorStatusCubit.
// ABOUTME: Status enum + per-pubkey map; no error strings in state.

part of 'video_collaborator_status_cubit.dart';

enum VideoCollaboratorStatusLoad { loading, ready, failure }

class VideoCollaboratorStatusState extends Equatable {
  const VideoCollaboratorStatusState({
    this.load = VideoCollaboratorStatusLoad.loading,
    this.statusByPubkey = const {},
  });

  final VideoCollaboratorStatusLoad load;
  final Map<String, CollaboratorStatus> statusByPubkey;

  CollaboratorStatus statusFor(String pubkey) =>
      statusByPubkey[pubkey] ?? CollaboratorStatus.pending;

  VideoCollaboratorStatusState copyWith({
    VideoCollaboratorStatusLoad? load,
    Map<String, CollaboratorStatus>? statusByPubkey,
  }) {
    return VideoCollaboratorStatusState(
      load: load ?? this.load,
      statusByPubkey: statusByPubkey ?? this.statusByPubkey,
    );
  }

  @override
  List<Object?> get props => [load, statusByPubkey];
}
