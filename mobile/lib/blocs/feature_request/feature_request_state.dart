// ABOUTME: State for FeatureRequestCubit — submission lifecycle.

import 'package:equatable/equatable.dart';

/// Lifecycle of a feature-request submission.
enum FeatureRequestStatus { idle, submitting, success, failure }

/// State for `FeatureRequestCubit`.
///
/// The four text fields stay in the View (controllers are UI plumbing).
/// The Cubit only owns the submission lifecycle so the View can render the
/// in-dialog success/failure banner and disable the form during submission.
class FeatureRequestState extends Equatable {
  const FeatureRequestState({this.status = FeatureRequestStatus.idle});

  final FeatureRequestStatus status;

  FeatureRequestState copyWith({FeatureRequestStatus? status}) {
    return FeatureRequestState(status: status ?? this.status);
  }

  @override
  List<Object?> get props => [status];
}
