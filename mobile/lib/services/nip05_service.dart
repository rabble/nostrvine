// ABOUTME: Service for handling NIP-05 username registration and verification
// ABOUTME: Manages username availability checking and registration with the backend

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:nostr_client/nostr_client.dart';

/// Base exception for NIP-05 service operations.
///
/// Thrown when a general error occurs during username registration
/// or verification, such as network failures or unexpected responses.
class Nip05ServiceException implements Exception {
  /// Creates a NIP-05 service exception with an optional [message].
  const Nip05ServiceException([this.message]);

  /// Optional message describing the exception.
  final String? message;

  @override
  String toString() => 'Nip05ServiceException: $message';
}

/// Thrown when attempting to register a reserved username.
///
/// Reserved usernames are held for specific users (e.g., brand names,
/// notable accounts). Users should contact support to claim these.
class UsernameReservedException extends Nip05ServiceException {
  /// Creates a reserved username exception with a [message].
  const UsernameReservedException(super.message);

  @override
  String toString() => 'UsernameReservedException: $message';
}

/// Thrown when attempting to register a username that is already taken.
///
/// The user should choose a different username.
class UsernameTakenException extends Nip05ServiceException {
  /// Creates a taken username exception with a [message].
  const UsernameTakenException(super.message);

  @override
  String toString() => 'UsernameTakenException: $message';
}

/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class Nip05Service {
  Nip05Service({http.Client? httpClient, required NostrClient nostrClient})
    : _httpClient = httpClient ?? http.Client(),
      _nostrClient = nostrClient;
  static const String _baseUrl =
      'https://nostrvine-backend.protestnet.workers.dev';
  final http.Client _httpClient;
  final NostrClient _nostrClient;

  String? _currentUsername;
  bool _isVerified = false;
  bool _isChecking = false;
  String? _error;

  String? get currentUsername => _currentUsername;
  bool get isVerified => _isVerified;
  bool get isChecking => _isChecking;
  String? get error => _error;

  /// Check if a username is available
  Future<bool> checkUsernameAvailability(String username) async {
    if (!_isValidUsername(username)) {
      _error =
          'Invalid username format. Only letters, numbers, dash, underscore, and dot allowed.';

      return false;
    }

    _isChecking = true;
    _error = null;

    try {
      final response = await _httpClient.get(
        Uri.parse('$_baseUrl/.well-known/nostr.json?name=$username'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final names = data['names'] as Map<String, dynamic>?;

        // Username is available if not in the names map
        final isAvailable = names == null || !names.containsKey(username);

        _isChecking = false;

        return isAvailable;
      } else {
        throw Exception('Failed to check username availability');
      }
    } catch (e) {
      _error = 'Failed to check username: $e';
      _isChecking = false;

      return false;
    }
  }

  /// Register a NIP-05 username
  Future<void> registerUsername(String username, String pubkey) async {
    final relays = _nostrClient.connectedRelays;
    if (!_isValidUsername(username)) {
      throw ArgumentError('Invalid username format: $username');
    }

    if (!_isValidPubkey(pubkey)) {
      throw ArgumentError('Invalid public key format: $pubkey');
    }

    final http.Response response;

    try {
      response = await _httpClient.post(
        Uri.parse('$_baseUrl/api/nip05/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'pubkey': pubkey,
          'relays': relays,
        }),
      );
    } catch (e) {
      throw Nip05ServiceException('Failed to register username: $e');
    }

    switch (response.statusCode) {
      case (200 || 201):
        return;
      case 403:
        throw UsernameReservedException(
          'Username is reserved. Contact support if you are the original owner.',
        );
      case 409:
        throw UsernameTakenException('Username already taken');
      default:
        throw Nip05ServiceException(
          'Unexpected response: ${response.statusCode}',
        );
    }
  }

  /// Verify a NIP-05 identifier
  Future<bool> verifyNip05(String identifier) async {
    // Parse identifier (username@domain)
    final parts = identifier.split('@');
    if (parts.length != 2) {
      _error = 'Invalid NIP-05 identifier format';

      return false;
    }

    final username = parts[0];
    final domain = parts[1];

    _isChecking = true;
    _error = null;

    try {
      final response = await _httpClient.get(
        Uri.parse('https://$domain/.well-known/nostr.json?name=$username'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final names = data['names'] as Map<String, dynamic>?;

        if (names != null && names.containsKey(username)) {
          _currentUsername = username;
          _isVerified = true;
          _isChecking = false;

          return true;
        }
      }

      _isVerified = false;
      _isChecking = false;

      return false;
    } catch (e) {
      _error = 'Failed to verify NIP-05: $e';
      _isVerified = false;
      _isChecking = false;

      return false;
    }
  }

  /// Load current NIP-05 status for a user
  void loadNip05Status(String? nip05Identifier) {
    if (nip05Identifier == null || nip05Identifier.isEmpty) {
      _currentUsername = null;
      _isVerified = false;

      return;
    }

    // Extract username from identifier (support both domains)
    final parts = nip05Identifier.split('@');
    if (parts.length == 2 &&
        (parts[1] == 'divine.video' || parts[1] == 'openvine.co')) {
      _currentUsername = parts[0];
      _isVerified = true;
    } else {
      _currentUsername = null;
      _isVerified = false;
    }
  }

  /// Validate username format
  bool _isValidUsername(String username) {
    final regex = RegExp(r'^[a-z0-9\-_.]+$', caseSensitive: false);
    return regex.hasMatch(username) &&
        username.length >= 3 &&
        username.length <= 20;
  }

  /// Validate pubkey format (64 char hex)
  bool _isValidPubkey(String pubkey) {
    final regex = RegExp(r'^[a-f0-9]{64}$', caseSensitive: false);
    return regex.hasMatch(pubkey);
  }

  /// Clear current state
  void clear() {
    _currentUsername = null;
    _isVerified = false;
    _isChecking = false;
    _error = null;
  }
}
