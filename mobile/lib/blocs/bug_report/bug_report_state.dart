// ABOUTME: State for BugReportCubit — submission lifecycle with a typed
// ABOUTME: failure key so the View can differentiate upload-failures
// ABOUTME: from generic Zendesk failures without state holding error strings.

import 'package:equatable/equatable.dart';

/// Lifecycle of a bug-report submission.
enum BugReportStatus { idle, submitting, success, failure }

/// Why a bug-report submission failed. Closed set so the View can map to
/// `context.l10n.xxx` without state having to carry error strings.
enum BugReportFailureKey {
  /// `ZendeskAttachmentUploadException` thrown during attachment upload.
  attachmentUpload,

  /// Anything else (network error, server reject, etc.).
  generic,
}

/// State for `BugReportCubit`.
class BugReportState extends Equatable {
  const BugReportState({
    this.status = BugReportStatus.idle,
    this.failureKey,
  });

  final BugReportStatus status;

  /// Set when [status] is [BugReportStatus.failure]; identifies which
  /// localized message the View should show.
  final BugReportFailureKey? failureKey;

  BugReportState copyWith({
    BugReportStatus? status,
    BugReportFailureKey? failureKey,
    bool clearFailureKey = false,
  }) {
    return BugReportState(
      status: status ?? this.status,
      failureKey: clearFailureKey ? null : (failureKey ?? this.failureKey),
    );
  }

  @override
  List<Object?> get props => [status, failureKey];
}
