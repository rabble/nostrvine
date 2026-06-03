// ABOUTME: Cubit backing the watermark-download progress sheet.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/blocs/watermark_download_progress/watermark_download_progress_state.dart';
import 'package:openvine/services/watermark_download_service.dart';

/// Cubit backing the `showWatermarkDownloadSheet(...)` bottom sheet.
class WatermarkDownloadProgressCubit
    extends Cubit<WatermarkDownloadProgressState> {
  WatermarkDownloadProgressCubit({
    required WatermarkDownloadService service,
    required VideoEvent video,
    required String watermarkText,
  }) : _service = service,
       _video = video,
       _watermarkText = watermarkText,
       super(const WatermarkDownloadProgressState());

  final WatermarkDownloadService _service;
  final VideoEvent _video;
  final String _watermarkText;

  Future<void> start() async {
    final result = await _service.downloadWithWatermark(
      video: _video,
      watermarkText: _watermarkText,
      onProgress: (stage) {
        if (isClosed) return;
        emit(state.copyWith(stage: stage));
      },
    );
    if (isClosed) return;
    emit(state.copyWith(result: result, isProcessing: false));
  }

  /// Retry-after-Settings hook used by the View's lifecycle observer.
  void reset() {
    if (isClosed) return;
    emit(const WatermarkDownloadProgressState());
  }
}
