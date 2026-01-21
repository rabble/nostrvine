// ABOUTME: Service for handling NIP-05 username availability checking
// ABOUTME: Manages username availability checking with the backend

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Service for checking NIP-05 username availability.
///
/// Note: Username claiming/registration is handled by ProfileRepository
/// using NIP-98 authentication to divine.video/api/username/claim.
class Nip05Service {
  Nip05Service({http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static const String _baseUrl =
      'https://nostrvine-backend.protestnet.workers.dev';
  final http.Client _httpClient;

  /// Check if a username is available
  Future<bool> checkUsernameAvailability(String username) async {
    if (!_isValidUsername(username)) return false;

    try {
      final response = await _httpClient.get(
        Uri.parse('$_baseUrl/.well-known/nostr.json?name=$username'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final names = data['names'] as Map<String, dynamic>?;

        // Username is available if not in the names map
        final isAvailable = names == null || !names.containsKey(username);

        return isAvailable;
      } else {
        throw Exception('Failed to check username availability');
      }
    } catch (e) {
      return false;
    }
  }

  /// Validate username format
  bool _isValidUsername(String username) {
    final regex = RegExp(r'^[a-z0-9\-_.]+$', caseSensitive: false);
    return regex.hasMatch(username) &&
        username.length >= 3 &&
        username.length <= 20;
  }
}
