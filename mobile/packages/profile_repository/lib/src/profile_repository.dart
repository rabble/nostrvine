// ABOUTME: Repository for fetching and publishing user profiles (Kind 0).
// ABOUTME: Delegates to NostrClient for relay operations.
// ABOUTME: Throws ProfilePublishFailedException on publish failure.

import 'dart:convert';

import 'package:http/http.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:profile_repository/profile_repository.dart';

/// API endpoint for claiming usernames via NIP-98 auth.
const _usernameClaimUrl = 'https://names.divine.video/api/username/claim';

/// Repository for fetching and publishing user profiles (Kind 0 metadata).
class ProfileRepository {
  /// Creates a new profile repository.
  const ProfileRepository({
    required NostrClient nostrClient,
    required Client httpClient,
  }) : _nostrClient = nostrClient,
       _httpClient = httpClient;

  final NostrClient _nostrClient;
  final Client _httpClient;

  /// Fetches a user profile by pubkey.
  ///
  /// Returns `null` if no profile exists for the given pubkey.
  Future<UserProfile?> getProfile({required String pubkey}) async {
    final profileEvent = await _nostrClient.fetchProfile(pubkey);
    if (profileEvent == null) return null;
    return UserProfile.fromNostrEvent(profileEvent);
  }

  /// Publishes profile metadata to Nostr relays
  ///
  /// Throws `ProfilePublishFailedException` if the operation fails.
  Future<UserProfile> saveProfileEvent({
    required String displayName,
    String? about,
    String? nip05,
    String? picture,
    UserProfile? currentProfile,
  }) async {
    final profileContent = {
      if (currentProfile != null) ...currentProfile.rawData,
      'display_name': displayName,
      'about': ?about,
      'nip05': ?nip05,
      'picture': ?picture,
    };

    final profileEvent = await _nostrClient.sendProfile(
      profileContent: profileContent,
    );

    if (profileEvent == null) {
      throw const ProfilePublishFailedException(
        'Failed to publish profile. Please try again.',
      );
    }

    return UserProfile.fromNostrEvent(profileEvent);
  }

  /// Claims a username via NIP-98 authenticated request.
  ///
  /// Makes a POST request to `names.divine.video/api/username/claim` with the
  /// username. The pubkey is extracted from the NIP-98 auth header by the
  /// server.
  ///
  /// Returns a [UsernameClaimResult] indicating success or the type of failure.
  Future<UsernameClaimResult> claimUsername({
    required String username,
  }) async {
    final payload = jsonEncode({
      'name': username,
    });
    final authHeader = await _nostrClient.createNip98AuthHeader(
      url: _usernameClaimUrl,
      method: 'POST',
      payload: payload,
    );

    if (authHeader == null) {
      return const UsernameClaimError('Nip98 authorization failed');
    }

    final Response response;
    try {
      response = await _httpClient.post(
        Uri.parse(_usernameClaimUrl),
        headers: {
          'Authorization': authHeader,
          'Content-Type': 'application/json',
        },
        body: payload,
      );

      return switch (response.statusCode) {
        200 || 201 => const UsernameClaimSuccess(),
        403 => const UsernameClaimReserved(),
        409 => const UsernameClaimTaken(),
        _ => UsernameClaimError('Unexpected response: ${response.statusCode}'),
      };
    } on Exception catch (e) {
      return UsernameClaimError('Network error: $e');
    }
  }
}
