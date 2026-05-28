// ABOUTME: State for AudioDeviceCubit — currently-selected microphone
// ABOUTME: preference. The device list itself is fetched lazily by the View
// ABOUTME: via DivineCamera.listAudioDevices(); only the user pick lives here.

import 'package:equatable/equatable.dart';

/// Load lifecycle of the audio-device picker tile.
enum AudioDeviceStatus { loading, ready }

/// State for `AudioDeviceCubit`.
///
/// [currentDeviceId] is null when the user has chosen "Auto (recommended)",
/// matching the persisted-null convention of `AudioDevicePreferenceService`.
class AudioDeviceState extends Equatable {
  const AudioDeviceState({
    this.status = AudioDeviceStatus.loading,
    this.currentDeviceId,
  });

  final AudioDeviceStatus status;
  final String? currentDeviceId;

  AudioDeviceState copyWith({
    AudioDeviceStatus? status,
    String? currentDeviceId,
    bool clearDeviceId = false,
  }) {
    return AudioDeviceState(
      status: status ?? this.status,
      currentDeviceId: clearDeviceId
          ? null
          : (currentDeviceId ?? this.currentDeviceId),
    );
  }

  @override
  List<Object?> get props => [status, currentDeviceId];
}
