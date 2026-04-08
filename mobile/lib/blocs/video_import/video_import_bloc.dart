import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:openvine/models/c2pa_import_result.dart';
import 'package:openvine/services/c2pa_import_validation_service.dart';
import 'package:openvine/services/video_import_service.dart';

part 'video_import_event.dart';
part 'video_import_state.dart';

class VideoImportBloc extends Bloc<VideoImportEvent, VideoImportState> {
  VideoImportBloc({
    required C2paImportValidationService validationService,
    required VideoImportService importService,
  }) : _validationService = validationService,
       _importService = importService,
       super(const VideoImportState()) {
    on<VideoImportReceived>(_onReceived, transformer: droppable());
    on<VideoImportConfirmed>(_onConfirmed, transformer: droppable());
    on<VideoImportDismissed>(_onDismissed);
  }

  final C2paImportValidationService _validationService;
  final VideoImportService _importService;

  Future<void> _onReceived(
    VideoImportReceived event,
    Emitter<VideoImportState> emit,
  ) async {
    emit(
      state.copyWith(
        status: VideoImportStatus.validating,
        filePath: event.filePath,
      ),
    );

    final result = await _validationService.validateFile(event.filePath);

    if (result.isAccepted) {
      emit(
        state.copyWith(
          status: VideoImportStatus.verified,
          validationResult: result,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: VideoImportStatus.rejected,
          validationResult: result,
        ),
      );
    }
  }

  Future<void> _onConfirmed(
    VideoImportConfirmed event,
    Emitter<VideoImportState> emit,
  ) async {
    if (state.status != VideoImportStatus.verified ||
        state.filePath == null ||
        state.validationResult == null) {
      return;
    }

    emit(state.copyWith(status: VideoImportStatus.importing));

    try {
      final draftId = await _importService.importVerifiedVideo(
        filePath: state.filePath!,
        validationResult: state.validationResult!,
      );

      emit(
        state.copyWith(
          status: VideoImportStatus.imported,
          draftId: draftId,
        ),
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(status: VideoImportStatus.error));
    }
  }

  void _onDismissed(
    VideoImportDismissed event,
    Emitter<VideoImportState> emit,
  ) {
    emit(const VideoImportState());
  }
}
