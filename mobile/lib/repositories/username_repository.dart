// ABOUTME: Repository for username availability checking
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

/// Repository that handles username availability checking.
///
/// This sits between the controller and service layers, providing
/// a clean interface for the presentation layer to use.
///
/// Note: Username claiming/registration is handled by ProfileRepository.
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
}
