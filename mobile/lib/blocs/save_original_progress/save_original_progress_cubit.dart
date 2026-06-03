// ABOUTME: Cubit backing the save-original progress sheet — drives the
// ABOUTME: watermark download service through downloading -> saving and
// ABOUTME: exposes the result for the View to switch on.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/blocs/save_original_progress/save_original_progress_state.dart';
import 'package:openvine/services/watermark_download_service.dart';

/// Cubit backing the `showSaveOriginalSheet(...)` bottom sheet.
///
/// Owns the durable progress state (`stage` / `result` / `isProcessing`).
/// The `RetryAfterSettingsOnResume` mixin stays in the View because it
/// observes Flutter `WidgetsBinding` — the View calls [reset] from its
/// retry-after-settings callback to restart the flow.
class SaveOriginalProgressCubit extends Cubit<SaveOriginalProgressState> {
  SaveOriginalProgressCubit({
    required WatermarkDownloadService service,
    required VideoEvent video,
  }) : _service = service,
       _video = video,
       super(const SaveOriginalProgressState());

  final WatermarkDownloadService _service;
  final VideoEvent _video;

  /// Run the save-original flow. Safe to call again after [reset] for the
  /// retry-after-settings flow.
  Future<void> start() async {
    final result = await _service.downloadOriginal(
      video: _video,
      onProgress: (stage) {
        if (isClosed) return;
        emit(state.copyWith(stage: stage));
      },
    );
    if (isClosed) return;
    emit(state.copyWith(result: result, isProcessing: false));
  }

  /// Reset state to the initial downloading-spinner view. The View calls
  /// this on resume-after-Settings to retry the save flow.
  void reset() {
    if (isClosed) return;
    emit(const SaveOriginalProgressState());
  }
}
