// ABOUTME: Service for handling NIP-05 username registration and verification
// ABOUTME: Manages username availability checking and registration with the backend

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class Nip05Service extends ChangeNotifier {
  static const String _baseUrl = 'https://nostrvine-backend.protestnet.workers.dev';
  final http.Client _httpClient;
  
  String? _currentUsername;
  bool _isVerified = false;
  bool _isChecking = false;
  String? _error;
  
  String? get currentUsername => _currentUsername;
  bool get isVerified => _isVerified;
  bool get isChecking => _isChecking;
  String? get error => _error;
  
  Nip05Service({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();
  
  /// Check if a username is available
  Future<bool> checkUsernameAvailability(String username) async {
    if (!_isValidUsername(username)) {
      _error = 'Invalid username format. Only letters, numbers, dash, underscore, and dot allowed.';
      notifyListeners();
      return false;
    }
    
    _isChecking = true;
    _error = null;
    notifyListeners();
    
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
        notifyListeners();
        
        return isAvailable;
      } else {
        throw Exception('Failed to check username availability');
      }
    } catch (e) {
      _error = 'Failed to check username: ${e.toString()}';
      _isChecking = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Register a NIP-05 username
  Future<bool> registerUsername(String username, String pubkey, List<String> relays) async {
    if (!_isValidUsername(username)) {
      _error = 'Invalid username format';
      notifyListeners();
      return false;
    }
    
    if (!_isValidPubkey(pubkey)) {
      _error = 'Invalid public key format';
      notifyListeners();
      return false;
    }
    
    _isChecking = true;
    _error = null;
    notifyListeners();
    
    try {
      final response = await _httpClient.post(
        Uri.parse('$_baseUrl/api/nip05/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'pubkey': pubkey,
          'relays': relays,
        }),
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          _currentUsername = username;
          _isVerified = true;
          _isChecking = false;
          _error = null;
          notifyListeners();
          return true;
        } else {
          throw Exception(data['error'] ?? 'Registration failed');
        }
      } else if (response.statusCode == 409) {
        _error = 'Username already taken';
        _isChecking = false;
        notifyListeners();
        return false;
      } else if (response.statusCode == 403) {
        _error = 'Username is reserved. Contact support if you are the original owner.';
        _isChecking = false;
        notifyListeners();
        return false;
      } else {
        final data = jsonDecode(response.body);
        throw Exception(data['error'] ?? 'Registration failed');
      }
    } catch (e) {
      _error = 'Failed to register username: ${e.toString()}';
      _isChecking = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Verify a NIP-05 identifier
  Future<bool> verifyNip05(String identifier) async {
    // Parse identifier (username@domain)
    final parts = identifier.split('@');
    if (parts.length != 2) {
      _error = 'Invalid NIP-05 identifier format';
      notifyListeners();
      return false;
    }
    
    final username = parts[0];
    final domain = parts[1];
    
    _isChecking = true;
    _error = null;
    notifyListeners();
    
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
          notifyListeners();
          return true;
        }
      }
      
      _isVerified = false;
      _isChecking = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Failed to verify NIP-05: ${e.toString()}';
      _isVerified = false;
      _isChecking = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Load current NIP-05 status for a user
  void loadNip05Status(String? nip05Identifier) {
    if (nip05Identifier == null || nip05Identifier.isEmpty) {
      _currentUsername = null;
      _isVerified = false;
      notifyListeners();
      return;
    }
    
    // Extract username from identifier
    final parts = nip05Identifier.split('@');
    if (parts.length == 2 && parts[1] == 'openvine.co') {
      _currentUsername = parts[0];
      _isVerified = true;
    } else {
      _currentUsername = null;
      _isVerified = false;
    }
    
    notifyListeners();
  }
  
  /// Validate username format
  bool _isValidUsername(String username) {
    final regex = RegExp(r'^[a-z0-9\-_.]+$', caseSensitive: false);
    return regex.hasMatch(username) && username.length >= 3 && username.length <= 20;
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
    notifyListeners();
  }
}