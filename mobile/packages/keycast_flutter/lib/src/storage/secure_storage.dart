// ABOUTME: FlutterSecureStorage implementation of KeycastStorage
// ABOUTME: Provides secure credential storage on iOS/Android

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'keycast_storage.dart';

/// KeycastStorage implementation using FlutterSecureStorage
/// Provides secure credential storage on iOS/Android
class SecureKeycastStorage implements KeycastStorage {
  final FlutterSecureStorage _storage;

  SecureKeycastStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}
