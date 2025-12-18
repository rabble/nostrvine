// ABOUTME: Riverpod notifier for reserved username request submission
// ABOUTME: Handles form state and submission via ReservedUsernameRequestRepository

import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/state/reserved_username_request_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'reserved_username_request_notifier.g.dart';

/// Notifier for managing reserved username request form and submission
///
/// Provides methods for updating form fields and submitting the request
/// to the backend. Handles validation and error states.
@riverpod
class ReservedUsernameRequestNotifier
    extends _$ReservedUsernameRequestNotifier {
  @override
  ReservedUsernameRequestState build() {
    return const ReservedUsernameRequestState();
  }

  /// Set the reserved username being requested
  ///
  /// This is typically pre-filled from the UI when the user tries
  /// to register a reserved username.
  void setUsername(String username) {
    state = state.copyWith(username: username.trim().toLowerCase());
  }

  /// Set the contact email for the request
  ///
  /// The backend will use this email to contact the user about their request.
  void setEmail(String email) {
    state = state.copyWith(email: email.trim());
  }

  /// Set the justification for why the user should get this username
  ///
  /// This should explain why the user believes they are entitled to
  /// the reserved username (e.g., they own the brand, are the public figure).
  void setJustification(String justification) {
    state = state.copyWith(justification: justification.trim());
  }

  /// Submit the request to the backend
  ///
  /// Validates the form, updates state to submitting, calls the repository,
  /// and updates state based on the result (success or error).
  ///
  /// Returns true if submission was successful, false otherwise.
  Future<bool> submitRequest() async {
    if (!state.canSubmit) {
      Log.warning(
        'Attempted to submit invalid reserved username request form',
        name: 'ReservedUsernameRequestNotifier',
        category: LogCategory.api,
      );
      return false;
    }

    // Set submitting state
    state = state.copyWith(
      status: ReservedUsernameRequestStatus.submitting,
      errorMessage: null,
    );

    Log.info(
      'Submitting reserved username request for: ${state.username}',
      name: 'ReservedUsernameRequestNotifier',
      category: LogCategory.api,
    );

    try {
      final repository = ref.read(reservedUsernameRequestRepositoryProvider);
      final result = await repository.submitRequest(
        username: state.username,
        email: state.email,
        justification: state.justification,
      );

      if (result.success) {
        Log.info(
          'Reserved username request submitted successfully for: ${state.username}',
          name: 'ReservedUsernameRequestNotifier',
          category: LogCategory.api,
        );
        state = state.copyWith(
          status: ReservedUsernameRequestStatus.success,
        );
        return true;
      } else {
        Log.error(
          'Failed to submit reserved username request: ${result.error}',
          name: 'ReservedUsernameRequestNotifier',
          category: LogCategory.api,
        );
        state = state.copyWith(
          status: ReservedUsernameRequestStatus.error,
          errorMessage: result.error ?? 'Failed to submit request',
        );
        return false;
      }
    } catch (e, stackTrace) {
      Log.error(
        'Exception while submitting reserved username request: $e',
        name: 'ReservedUsernameRequestNotifier',
        category: LogCategory.api,
        stackTrace: stackTrace,
      );
      state = state.copyWith(
        status: ReservedUsernameRequestStatus.error,
        errorMessage: 'An unexpected error occurred',
      );
      return false;
    }
  }

  /// Reset the form to initial state
  ///
  /// Clears all fields and resets status to idle.
  /// Useful when dismissing the form or starting a new request.
  void reset() {
    state = const ReservedUsernameRequestState();
  }
}
