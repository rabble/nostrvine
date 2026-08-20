// ABOUTME: Cubit backing the Music mode toggle in ContentPreferencesScreen.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/music_mode/music_mode_state.dart';
import 'package:openvine/services/music_mode_preference_service.dart';

/// Cubit backing the `_MusicModeToggle` tile in `ContentPreferencesScreen`.
class MusicModeCubit extends Cubit<MusicModeState>
    with CloseGuardedEmit<MusicModeState> {
  MusicModeCubit({required MusicModePreferenceService service})
    : _service = service,
      super(const MusicModeState());

  final MusicModePreferenceService _service;

  void load() {
    emit(
      state.copyWith(
        status: MusicModeStatus.ready,
        isEnabled: _service.isMusicModeEnabled,
      ),
    );
  }

  Future<void> setEnabled(bool value) async {
    await _service.setMusicModeEnabled(value);
    // The write crosses an await; leaving the settings screen mid-toggle
    // closes this cubit before it resumes.
    emitIfOpen(state.copyWith(isEnabled: _service.isMusicModeEnabled));
  }
}
