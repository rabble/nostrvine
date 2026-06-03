// ABOUTME: Cubit backing the audio-input-device picker in
// ABOUTME: ContentPreferencesScreen. Owns only the selected device id —
// ABOUTME: the device list is fetched lazily by the View via FutureBuilder.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/audio_device/audio_device_state.dart';
import 'package:openvine/services/audio_device_preference_service.dart';

/// Cubit backing the `_AudioDeviceSelector` tile in
/// `ContentPreferencesScreen`.
///
/// The list of available audio devices is fetched by the View via
/// `DivineCamera.listAudioDevices()` — it's a one-shot async UI concern
/// (the picker isn't reactive to hot-plugging mid-screen), so the Cubit
/// only owns the persisted selection. `null` means the user is on
/// "Auto (recommended)".
class AudioDeviceCubit extends Cubit<AudioDeviceState> {
  AudioDeviceCubit({required AudioDevicePreferenceService service})
    : _service = service,
      super(const AudioDeviceState());

  final AudioDevicePreferenceService _service;

  Future<void> load() async {
    await _service.initialize();
    _emitSnapshot();
  }

  Future<void> setDeviceId(String? deviceId) async {
    await _service.setPreferredDeviceId(deviceId);
    _emitSnapshot();
  }

  void _emitSnapshot() {
    final preferredDeviceId = _service.preferredDeviceId;
    emit(
      state.copyWith(
        status: AudioDeviceStatus.ready,
        currentDeviceId: preferredDeviceId,
        clearDeviceId: preferredDeviceId == null,
      ),
    );
  }
}
