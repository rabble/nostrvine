// ABOUTME: Repository for fetching user profile information from Nostr.
// ABOUTME: Uses NostrClient to fetch Kind 0 (metadata) events.

import 'package:nostr_client/nostr_client.dart';
import 'package:users_repository/src/exceptions.dart';
import 'package:users_repository/src/models/models.dart';

/// Repository for fetching user profile information from Nostr.
///
/// Uses [NostrClient] to fetch Kind 0 (metadata) events and converts
/// them to [User] models for use in the application.
class UsersRepository {
  /// Creates a new [UsersRepository] instance.
  const UsersRepository({required NostrClient nostrClient})
    : _nostrClient = nostrClient;

  final NostrClient _nostrClient;

  /// Fetches a user's profile information by pubkey.
  ///
  /// Returns a [User] with the profile information.
  ///
  /// Throws [UserNotFoundException] if the profile doesn't exist.
  Future<User> getUser(String pubkey) async {
    final event = await _nostrClient.fetchProfile(pubkey);
    if (event == null) throw UserNotFoundException(pubkey);
    return User.fromNostrEvent(event);
  }
}
