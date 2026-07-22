// ABOUTME: Screen-local cubit for the captions editor.
// ABOUTME: Runs on-device generation and manages the editable cue list.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/services/video_editor/caption_generation_service.dart';

part 'captions_editor_state.dart';

/// Manages one captions editing session.
///
/// Created per `VideoCaptionsEditorScreen` visit (like `AudioTimingCubit`).
/// A fresh session (no [initialCues]) starts with on-device generation; an
/// existing session starts ready with its cues.
class CaptionsEditorCubit extends Cubit<CaptionsEditorState> {
  /// Creates the cubit. Omitting [generationService] uses the production
  /// on-device recognition pipeline.
  CaptionsEditorCubit({
    required List<DivineVideoClip> clips,
    required Duration totalDuration,
    required CaptionRenderMode mode,
    required String presetId,
    required String languageTag,
    List<CaptionCue>? initialCues,
    CaptionGenerationService? generationService,
  }) : _generationService =
           generationService ?? CaptionGenerationService.production(),
       _clips = clips,
       _totalDuration = totalDuration,
       super(
         CaptionsEditorState(
           mode: mode,
           presetId: presetId,
           languageTag: languageTag,
           status: initialCues != null
               ? CaptionsEditorStatus.ready
               : CaptionsEditorStatus.generating,
           cues: initialCues ?? const [],
         ),
       );

  final CaptionGenerationService _generationService;
  final List<DivineVideoClip> _clips;
  final Duration _totalDuration;

  /// Default length of a manually added cue.
  static const Duration _newCueDuration = Duration(seconds: 2);

  var _nextManualCueId = 0;

  /// Runs on-device generation for a fresh session. No-op when the session
  /// started from existing cues.
  Future<void> initialize() async {
    if (state.status != CaptionsEditorStatus.generating) return;
    final outcome = await _generationService.generateForClips(
      clips: _clips,
      localeIdentifier: state.languageTag,
    );
    if (isClosed) return;
    switch (outcome) {
      case CaptionsGenerated(:final cues):
        emit(state.copyWith(status: CaptionsEditorStatus.ready, cues: cues));
      case CaptionsEmpty():
        emit(state.copyWith(status: CaptionsEditorStatus.empty));
      case CaptionsFailed(:final reason):
        emit(
          state.copyWith(status: CaptionsEditorStatus.failed, failure: reason),
        );
    }
  }

  /// Continues with an empty cue list after [CaptionsEditorStatus.empty] or
  /// [CaptionsEditorStatus.failed].
  void startEmpty() {
    emit(state.copyWith(status: CaptionsEditorStatus.ready, cues: const []));
  }

  /// Replaces the text of the cue with [cueId].
  void updateCueText(String cueId, String text) {
    emit(
      state.copyWith(
        cues: [
          for (final cue in state.cues)
            if (cue.id == cueId) cue.copyWith(text: text) else cue,
        ],
      ),
    );
  }

  /// Removes the cue with [cueId].
  void removeCue(String cueId) {
    emit(
      state.copyWith(
        cues: [
          for (final cue in state.cues)
            if (cue.id != cueId) cue,
        ],
      ),
    );
  }

  /// Appends a new cue after the last one (or at the timeline start),
  /// clamped to the video duration. Fine-tuning happens on the timeline.
  void addCue() {
    final lastEnd = state.cues.isEmpty ? Duration.zero : state.cues.last.end;
    var start = lastEnd;
    var end = start + _newCueDuration;
    if (end > _totalDuration) {
      end = _totalDuration;
      // Prefer a shorter cue in the remaining tail; only when that tail is
      // too small to read, back-shift over the previous cue instead.
      if (end - start < VideoEditorConstants.minCaptionCueDuration) {
        start = end - _newCueDuration;
        if (start < Duration.zero) start = Duration.zero;
      }
    }
    emit(
      state.copyWith(
        status: CaptionsEditorStatus.ready,
        cues: [
          ...state.cues,
          CaptionCue(
            id: 'manual-${_nextManualCueId++}',
            text: '',
            start: start,
            end: end,
          ),
        ],
      ),
    );
  }

  /// Selects the track-wide style preset (burn-in mode).
  void setPreset(String presetId) {
    emit(state.copyWith(presetId: presetId));
  }

  /// Switches between burn-in and CC overlay. Cue text and timing survive;
  /// the commit handler materializes or removes layers accordingly.
  void setMode(CaptionRenderMode mode) {
    emit(state.copyWith(mode: mode));
  }
}
