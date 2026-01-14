// ABOUTME: Riverpod notifier for username availability checking and registration
// ABOUTME: Handles debounced availability checks and registration via UsernameRepository

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/repositories/username_repository.dart';
import 'package:openvine/services/nip05_service.dart';
import 'package:openvine/state/username_state.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'username_notifier.g.dart';

/// Minimum length for a valid username
const kMinUsernameLength = 3;

/// Maximum length for a valid username
const kMaxUsernameLength = 20;

/// Notifier for managing username availability checking and registration
///
/// Provides debounced availability checking to avoid excessive API calls
/// and handles the full registration flow including reserved name detection.
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

  /// Check username availability via UsernameRepository
  ///
  /// This is exposed for testing to bypass debounce timer.
  @visibleForTesting
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

  /// Register the username with the backend
  ///
  /// Returns the registration result for the caller to handle.
  /// Updates state based on the result (e.g., reserved, taken).
  Future<UsernameRegistrationResult> registerUsername({
    required String pubkey,
    required List<String> relays,
  }) async {
    if (!state.canRegister) {
      Log.warning(
        'Attempted to register unavailable username: ${state.username}',
        name: 'UsernameNotifier',
        category: LogCategory.api,
      );
      return const UsernameRegistrationResult(
        status: UsernameRegistrationStatus.error,
        errorMessage: 'Username not available for registration',
      );
    }

    final repository = ref.read(usernameRepositoryProvider);

    Log.info(
      'Registering username: ${state.username}',
      name: 'UsernameNotifier',
      category: LogCategory.api,
    );

    final result = await repository.register(
      username: state.username,
      pubkey: pubkey,
      relays: relays,
    );

    // Update state based on result
    if (result.isReserved) {
      Log.info(
        'Username ${state.username} is reserved',
        name: 'UsernameNotifier',
        category: LogCategory.api,
      );
      state = state.copyWith(
        status: UsernameCheckStatus.reserved,
        errorMessage: result.errorMessage,
      );
    } else if (result.isTaken) {
      Log.info(
        'Username ${state.username} is taken',
        name: 'UsernameNotifier',
        category: LogCategory.api,
      );
      state = state.copyWith(
        status: UsernameCheckStatus.taken,
        errorMessage: result.errorMessage,
      );
    } else if (result.isSuccess) {
      Log.info(
        'Username ${state.username} registered successfully',
        name: 'UsernameNotifier',
        category: LogCategory.api,
      );
    }

    return result;
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
