// ABOUTME: State class for reserved username request form
// ABOUTME: Tracks form fields and submission status for claiming reserved names

import 'package:equatable/equatable.dart';

/// Status of reserved username request submission
enum ReservedUsernameRequestStatus {
  /// Form is ready for input
  idle,

  /// Request is being submitted to backend
  submitting,

  /// Request was submitted successfully
  success,

  /// Request submission failed
  error,
}

/// Immutable state for reserved username request form
class ReservedUsernameRequestState extends Equatable {
  const ReservedUsernameRequestState({
    this.email = '',
    this.justification = '',
    this.status = ReservedUsernameRequestStatus.idle,
    this.errorMessage,
  });

  /// User's contact email for support to respond
  final String email;

  /// Reason why user believes they should have this username
  final String justification;

  /// Current status of the request submission
  final ReservedUsernameRequestStatus status;

  /// Error message if status is error
  final String? errorMessage;

  /// Whether the form is currently submitting
  bool get isSubmitting => status == ReservedUsernameRequestStatus.submitting;

  /// Whether the request was submitted successfully
  bool get isSuccess => status == ReservedUsernameRequestStatus.success;

  /// Whether there was an error submitting
  bool get hasError => status == ReservedUsernameRequestStatus.error;

  /// Create a copy with updated fields
  ReservedUsernameRequestState copyWith({
    String? email,
    String? justification,
    ReservedUsernameRequestStatus? status,
    String? errorMessage,
  }) => ReservedUsernameRequestState(
    email: email ?? this.email,
    justification: justification ?? this.justification,
    status: status ?? this.status,
    errorMessage: errorMessage,
  );

  @override
  List<Object?> get props => [email, justification, status, errorMessage];
}
