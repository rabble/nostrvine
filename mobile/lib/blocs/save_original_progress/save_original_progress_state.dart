// ABOUTME: State for SaveOriginalProgressCubit — stage + result + processing.

import 'package:equatable/equatable.dart';
import 'package:openvine/services/watermark_download_service.dart';

/// State for `SaveOriginalProgressCubit`.
///
/// While [isProcessing] is true, the View renders the spinner + stage
/// labels. Once it flips to false, [result] is non-null and the View
/// switches to the success/permission/failure branch.
class SaveOriginalProgressState extends Equatable {
  const SaveOriginalProgressState({
    this.stage = OriginalSaveStage.downloading,
    this.result,
    this.isProcessing = true,
  });

  final OriginalSaveStage stage;
  final WatermarkDownloadResult? result;
  final bool isProcessing;

  SaveOriginalProgressState copyWith({
    OriginalSaveStage? stage,
    WatermarkDownloadResult? result,
    bool? isProcessing,
  }) {
    return SaveOriginalProgressState(
      stage: stage ?? this.stage,
      result: result ?? this.result,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }

  @override
  List<Object?> get props => [stage, result, isProcessing];
}
