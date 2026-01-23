// ABOUTME: Riverpod notifier for username availability checking
// ABOUTME: Handles debounced availability checks via UsernameRepository

import 'dart:async';

import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/repositories/username_repository.dart';
import 'package:openvine/state/username_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'username_notifier.g.dart';

/// Minimum length for a valid username
const kMinUsernameLength = 3;

/// Maximum length for a valid username
const kMaxUsernameLength = 20;

/// Notifier for managing username availability checking
///
/// Provides debounced availability checking to avoid excessive API calls
/// while the user types in the username field.
@riverpod
class UsernameNotifier extends _$UsernameNotifier {
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 500);

  @override
  UsernameState build() {
    // Clean up timer when provider is disposed
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return const UsernameState();
  }

  /// Called when username text changes - debounces availability check
  ///
  /// Validates format locally first, then triggers a debounced API call
  /// to check availability with the backend.
  void onUsernameChanged(String value) {
    _debounceTimer?.cancel();

    final trimmed = value.trim().toLowerCase();

    // Reset if empty or too short
    if (trimmed.isEmpty || trimmed.length < kMinUsernameLength) {
      state = UsernameState(
        username: trimmed,
        status: UsernameCheckStatus.idle,
      );
      return;
    }

    // Validate format locally first
    if (!_isValidFormat(trimmed)) {
      state = UsernameState(
        username: trimmed,
        status: UsernameCheckStatus.error,
        errorMessage: 'Invalid format',
      );
      return;
    }

    // Set checking state immediately for responsive UI
    state = UsernameState(
      username: trimmed,
      status: UsernameCheckStatus.checking,
    );

    // Debounce the actual API call
    _debounceTimer = Timer(_debounceDuration, () => checkAvailability(trimmed));
  }

  /// Check username availability via UsernameRepository.
  ///
  /// Bypasses debounce timer for immediate checks (e.g., after save failure).
  Future<void> checkAvailability(String username) async {
    final repository = ref.read(usernameRepositoryProvider);

    Log.debug(
      'Checking availability for username: $username',
      name: 'UsernameNotifier',
      category: LogCategory.api,
    );

    final result = await repository.checkAvailability(username);

    // Only update if username hasn't changed during the check
    if (state.username == username) {
      switch (result) {
        case UsernameAvailability.available:
          state = state.copyWith(status: UsernameCheckStatus.available);
          Log.debug(
            'Username $username is available',
            name: 'UsernameNotifier',
            category: LogCategory.api,
          );
        case UsernameAvailability.taken:
          state = state.copyWith(status: UsernameCheckStatus.taken);
          Log.debug(
            'Username $username is taken',
            name: 'UsernameNotifier',
            category: LogCategory.api,
          );
        case UsernameAvailability.error:
          state = state.copyWith(
            status: UsernameCheckStatus.error,
            errorMessage: 'Failed to check availability',
          );
          Log.error(
            'Failed to check username availability',
            name: 'UsernameNotifier',
            category: LogCategory.api,
          );
      }
    }
  }

  /// Clear state (e.g., when leaving screen or resetting form)
  void clear() {
    _debounceTimer?.cancel();
    state = const UsernameState();
  }

  /// Validate username format locally
  bool _isValidFormat(String username) {
    final regex = RegExp(r'^[a-z0-9\-_.]+$', caseSensitive: false);
    return regex.hasMatch(username) && username.length <= kMaxUsernameLength;
  }
}
