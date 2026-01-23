// ABOUTME: Service for handling NIP-05 username registration
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
  /// Creates a reserved username exception.
  const UsernameReservedException();

  @override
  String toString() => 'UsernameReservedException';
}

/// Thrown when attempting to register a username that is already taken.
///
/// The user should choose a different username.
class UsernameTakenException extends Nip05ServiceException {
  /// Creates a taken username exception.
  const UsernameTakenException();

  @override
  String toString() => 'UsernameTakenException';
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
        throw const UsernameReservedException();
      case 409:
        throw const UsernameTakenException();
      default:
        throw Nip05ServiceException(
          'Unexpected response: ${response.statusCode}',
        );
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
}
