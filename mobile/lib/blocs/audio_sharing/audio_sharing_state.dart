// ABOUTME: State for AudioSharingCubit — the audio-sharing toggle preference.

import 'package:equatable/equatable.dart';

/// Load lifecycle of the audio-sharing tile.
enum AudioSharingStatus { loading, ready }

/// State for `AudioSharingCubit`.
class AudioSharingState extends Equatable {
  const AudioSharingState({
    this.status = AudioSharingStatus.loading,
    this.isEnabled = false,
  });

  final AudioSharingStatus status;
  final bool isEnabled;

  AudioSharingState copyWith({
    AudioSharingStatus? status,
    bool? isEnabled,
  }) {
    return AudioSharingState(
      status: status ?? this.status,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  @override
  List<Object?> get props => [status, isEnabled];
}
