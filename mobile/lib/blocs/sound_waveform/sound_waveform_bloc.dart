// ABOUTME: BLoC for extracting audio waveform data from sounds.
// ABOUTME: Uses ProVideoEditor to extract amplitude samples for visualization.

import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

part 'sound_waveform_event.dart';
part 'sound_waveform_state.dart';

/// BLoC for managing sound waveform extraction.
///
/// Handles:
/// - Extracting waveform data from audio URLs
/// - Providing both left and right channel data for stereo visualization
/// - Caching results until cleared
class SoundWaveformBloc extends Bloc<SoundWaveformEvent, SoundWaveformState> {
  SoundWaveformBloc() : super(const SoundWaveformInitial()) {
    on<SoundWaveformExtract>(_onExtract);
    on<SoundWaveformClear>(_onClear);
  }

  Future<void> _onExtract(
    SoundWaveformExtract event,
    Emitter<SoundWaveformState> emit,
  ) async {
    emit(const SoundWaveformLoading());

    try {
      final video = event.isAsset
          ? EditorVideo.asset(event.path)
          : EditorVideo.network(event.path);

      final configs = WaveformConfigs(
        video: video,
      );

      final waveformData = await ProVideoEditor.instance.getWaveform(configs);

      Log.debug(
        'Waveform extracted: ${waveformData.leftChannel.length} samples',
        name: 'SoundWaveformBloc',
        category: LogCategory.video,
      );

      emit(
        SoundWaveformLoaded(
          leftChannel: waveformData.leftChannel,
          rightChannel: waveformData.rightChannel,
          duration: waveformData.duration,
        ),
      );
    } catch (e, s) {
      Log.error(
        'Failed to extract waveform: $e',
        name: 'SoundWaveformBloc',
        category: LogCategory.video,
        error: e,
        stackTrace: s,
      );
      addError(e, s);
      emit(SoundWaveformError(e.toString()));
    }
  }

  void _onClear(SoundWaveformClear event, Emitter<SoundWaveformState> emit) {
    emit(const SoundWaveformInitial());
  }
}
