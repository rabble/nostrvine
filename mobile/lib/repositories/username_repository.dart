// ABOUTME: Repository for username availability checking and registration
// ABOUTME: Wraps Nip05Service to provide a clean data layer interface

import 'package:openvine/services/nip05_service.dart';

/// Result of checking username availability.
enum UsernameAvailability {
  /// Username is available for registration.
  available,

  /// Username is already taken by another user.
  taken,

  /// An error occurred while checking availability.
  error,
}

/// Sealed class representing the result of a username claim attempt.
sealed class UsernameClaimResult {
  const UsernameClaimResult();
}

/// Username was successfully claimed.
class UsernameClaimSuccess extends UsernameClaimResult {
  const UsernameClaimSuccess();
}

/// Username is already taken by another user.
class UsernameClaimTaken extends UsernameClaimResult {
  const UsernameClaimTaken();
}

/// Username is reserved and requires contacting support to claim.
class UsernameClaimReserved extends UsernameClaimResult {
  const UsernameClaimReserved();
}

/// An error occurred during username registration.
class UsernameClaimError extends UsernameClaimResult {
  /// Creates an error result with the given [message].
  const UsernameClaimError(this.message);

  /// Description of what went wrong.
  final String message;
}

/// Repository that handles username-related data operations
///
/// This sits between the controller and service layers, providing
/// a clean interface for the presentation layer to use.
class UsernameRepository {
  UsernameRepository(this._nip05Service);

  final Nip05Service _nip05Service;

  /// Check if username is available
  ///
  /// Returns [UsernameAvailability.available] if the username can be registered,
  /// [UsernameAvailability.taken] if already registered, or
  /// [UsernameAvailability.error] if the check failed.
  Future<UsernameAvailability> checkAvailability(String username) async {
    try {
      final isAvailable = await _nip05Service.checkUsernameAvailability(
        username,
      );
      return isAvailable
          ? UsernameAvailability.available
          : UsernameAvailability.taken;
    } catch (e) {
      return UsernameAvailability.error;
    }
  }

  /// Register a username for the given pubkey
  ///
  /// Delegates to [Nip05Service.registerUsername] and returns the result.
  Future<UsernameClaimResult> register({
    required String username,
    required String pubkey,
  }) async {
    try {
      await _nip05Service.registerUsername(username, pubkey);
      return const UsernameClaimSuccess();
    } on UsernameTakenException {
      return const UsernameClaimTaken();
    } on UsernameReservedException {
      return const UsernameClaimReserved();
    } on Nip05ServiceException catch (e) {
      return UsernameClaimError(e.message ?? 'Unknown error');
    }
  }
}
