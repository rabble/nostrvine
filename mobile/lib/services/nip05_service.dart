// ABOUTME: Service for handling NIP-05 username availability checking
// ABOUTME: Manages username availability checking with the backend

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:openvine/utils/unified_logger.dart';

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

  /// Check if a username subdomain is available (new format: _@username.divine.video)
  ///
  /// This checks `username.divine.video/.well-known/nostr.json?name=_` to see
  /// if the subdomain has already been claimed.
  Future<bool> checkSubdomainAvailability(String username) async {
    if (!_isValidUsername(username)) return false;

    try {
      final response = await _httpClient.get(
        Uri.parse(
          'https://$username.divine.video/.well-known/nostr.json?name=_',
        ),
      );

      // 404 means subdomain doesn't exist yet = available
      if (response.statusCode == 404) return true;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final names = data['names'] as Map<String, dynamic>?;
        // Available if no '_' entry exists
        return names == null || !names.containsKey('_');
      }
      return false;
    } catch (e) {
      Log.debug(
        'Subdomain check failed, falling back to legacy: $e',
        name: 'Nip05Service',
      );
      // Network error - fall back to legacy check
      return checkUsernameAvailability(username);
    }
  }

  /// Check if a username is available (legacy format: username@divine.video)
  ///
  /// This is the fallback method that checks the centralized nostr.json.
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
