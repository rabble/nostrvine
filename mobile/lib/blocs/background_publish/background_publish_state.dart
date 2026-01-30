part of 'background_publish_bloc.dart';

class BackgroundUpload extends Equatable {
  const BackgroundUpload({
    required this.draft,
    required this.result,
    required this.progress,
  });

  final VineDraft draft;
  final double progress;
  final PublishResult? result;

  BackgroundUpload copyWith({
    VineDraft? draft,
    double? progress,
    PublishResult? result,
  }) {
    return BackgroundUpload(
      draft: draft ?? this.draft,
      progress: progress ?? this.progress,
      result: result ?? this.result,
    );
  }

  @override
  List<Object?> get props => [draft.id, progress, result];
}

class BackgroundPublishState extends Equatable {
  const BackgroundPublishState({this.uploads = const []});

  final List<BackgroundUpload> uploads;

  BackgroundPublishState copyWith({List<BackgroundUpload>? uploads}) {
    return BackgroundPublishState(uploads: uploads ?? this.uploads);
  }

  @override
  List<Object?> get props => [uploads];
}
