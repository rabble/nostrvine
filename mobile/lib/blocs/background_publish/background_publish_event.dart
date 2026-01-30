part of 'background_publish_bloc.dart';

sealed class BackgroundPublishEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class BackgroundPublishRequested extends BackgroundPublishEvent {
  BackgroundPublishRequested({
    required this.draft,
    required this.publishmentProcess,
  });

  final VineDraft draft;
  final Future<PublishResult> publishmentProcess;

  @override
  List<Object?> get props => [draft, publishmentProcess];
}

class BackgroundPublishProgressChanged extends BackgroundPublishEvent {
  BackgroundPublishProgressChanged({
    required this.draftId,
    required this.progress,
  });

  final String draftId;
  final double progress;

  @override
  List<Object?> get props => [draftId, progress];
}

class BackgroundPublishVanished extends BackgroundPublishEvent {
  BackgroundPublishVanished({required this.draftId});

  final String draftId;

  @override
  List<Object?> get props => [draftId];
}

class BackgroundPublishRetryRequested extends BackgroundPublishEvent {
  BackgroundPublishRetryRequested({required this.draftId});

  final String draftId;

  @override
  List<Object?> get props => [draftId];
}
