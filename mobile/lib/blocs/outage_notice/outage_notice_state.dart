part of 'outage_notice_cubit.dart';

/// What the failure view should say.
enum OutageNoticeStatus {
  /// Diagnosis has not finished; keep the generic failure copy.
  checking,

  /// The status page corroborates an outage on our side.
  divineOutage,

  /// The device cannot reach anything, including a host on another CDN.
  noConnection,

  /// Nothing explains the failure; stay generic.
  indeterminate,
}

final class OutageNoticeState extends Equatable {
  const OutageNoticeState({
    this.status = OutageNoticeStatus.checking,
    this.operatorMessage,
  });

  final OutageNoticeStatus status;

  /// The on-call operator's own words, when the status page carried any.
  final String? operatorMessage;

  @override
  List<Object?> get props => [status, operatorMessage];
}
