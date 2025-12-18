// ABOUTME: Repository for username availability checking and registration
// ABOUTME: Wraps Nip05Service to provide a clean data layer interface

import 'package:openvine/services/nip05_service.dart';

/// Result of checking username availability
enum UsernameAvailability { available, taken, error }

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
  Future<UsernameRegistrationResult> register({
    required String username,
    required String pubkey,
    required List<String> relays,
  }) {
    return _nip05Service.registerUsername(username, pubkey, relays);
  }
}
