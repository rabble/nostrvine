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

  final DivineVideoDraft draft;
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

/// Marks a draft as a failed upload without starting a publish process.
///
/// Used to surface interrupted uploads (e.g. from a previous session) in
/// the failure sheet so the user can decide whether to retry or discard.
class BackgroundPublishFailed extends BackgroundPublishEvent {
  BackgroundPublishFailed({required this.draft, required this.userMessage});

  final DivineVideoDraft draft;
  final String userMessage;

  @override
  List<Object?> get props => [draft, userMessage];
}
