// ABOUTME: State for WatermarkDownloadProgressCubit.

import 'package:equatable/equatable.dart';
import 'package:openvine/services/watermark_download_service.dart';

class WatermarkDownloadProgressState extends Equatable {
  const WatermarkDownloadProgressState({
    this.stage = WatermarkDownloadStage.downloading,
    this.result,
    this.isProcessing = true,
  });

  final WatermarkDownloadStage stage;
  final WatermarkDownloadResult? result;
  final bool isProcessing;

  WatermarkDownloadProgressState copyWith({
    WatermarkDownloadStage? stage,
    WatermarkDownloadResult? result,
    bool? isProcessing,
  }) {
    return WatermarkDownloadProgressState(
      stage: stage ?? this.stage,
      result: result ?? this.result,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }

  @override
  List<Object?> get props => [stage, result, isProcessing];
}
