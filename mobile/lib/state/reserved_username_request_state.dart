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
    this.username = '',
    this.email = '',
    this.justification = '',
    this.status = ReservedUsernameRequestStatus.idle,
    this.errorMessage,
  });

  /// The reserved username being requested
  final String username;

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

  /// Whether the form can be submitted (has required fields and not submitting)
  bool get canSubmit =>
      username.isNotEmpty &&
      email.isNotEmpty &&
      _isValidEmail(email) &&
      justification.isNotEmpty &&
      !isSubmitting;

  /// Validates email format
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');
    return emailRegex.hasMatch(email);
  }

  /// Whether the email format is valid (for showing validation errors)
  bool get isEmailValid => email.isEmpty || _isValidEmail(email);

  /// Create a copy with updated fields
  ReservedUsernameRequestState copyWith({
    String? username,
    String? email,
    String? justification,
    ReservedUsernameRequestStatus? status,
    String? errorMessage,
  }) => ReservedUsernameRequestState(
    username: username ?? this.username,
    email: email ?? this.email,
    justification: justification ?? this.justification,
    status: status ?? this.status,
    errorMessage: errorMessage,
  );

  @override
  List<Object?> get props => [
    username,
    email,
    justification,
    status,
    errorMessage,
  ];
}
