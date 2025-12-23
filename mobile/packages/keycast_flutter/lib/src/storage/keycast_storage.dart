// ABOUTME: Abstract storage interface for Keycast credentials
// ABOUTME: Async interface compatible with FlutterSecureStorage

/// Abstract storage interface for persisting Keycast credentials
/// Async interface compatible with FlutterSecureStorage
abstract class KeycastStorage {
  /// Read a value from storage
  Future<String?> read(String key);

  /// Write a value to storage
  Future<void> write(String key, String value);

  /// Delete a value from storage
  Future<void> delete(String key);
}

/// In-memory storage implementation for testing or temporary use
class MemoryKeycastStorage implements KeycastStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async {
    return _data[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }
}
