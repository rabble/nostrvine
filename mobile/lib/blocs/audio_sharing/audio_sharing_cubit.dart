// ABOUTME: Cubit backing the audio-sharing toggle in ContentPreferencesScreen.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/audio_sharing/audio_sharing_state.dart';
import 'package:openvine/services/audio_sharing_preference_service.dart';

/// Cubit backing the `_AudioSharingToggle` tile in `ContentPreferencesScreen`.
class AudioSharingCubit extends Cubit<AudioSharingState> {
  AudioSharingCubit({required AudioSharingPreferenceService service})
    : _service = service,
      super(const AudioSharingState());

  final AudioSharingPreferenceService _service;

  void load() {
    emit(
      state.copyWith(
        status: AudioSharingStatus.ready,
        isEnabled: _service.isAudioSharingEnabled,
      ),
    );
  }

  Future<void> setEnabled(bool value) async {
    await _service.setAudioSharingEnabled(value);
    emit(state.copyWith(isEnabled: _service.isAudioSharingEnabled));
  }
}
