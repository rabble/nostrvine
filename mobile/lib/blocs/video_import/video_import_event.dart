part of 'video_import_bloc.dart';

sealed class VideoImportEvent extends Equatable {
  const VideoImportEvent();

  @override
  List<Object?> get props => [];
}

final class VideoImportReceived extends VideoImportEvent {
  const VideoImportReceived({required this.filePath});
  final String filePath;

  @override
  List<Object?> get props => [filePath];
}

final class VideoImportConfirmed extends VideoImportEvent {
  const VideoImportConfirmed();
}

final class VideoImportDismissed extends VideoImportEvent {
  const VideoImportDismissed();
}
