import 'package:cache_sync/src/cache_dao.dart';

/// In-memory [CacheDao] for use in tests.
class FakeCacheDao implements CacheDao {
  FakeCacheDao({this.maxSizeBytes});

  /// Maximum total payload size in characters. `null` = unlimited.
  final int? maxSizeBytes;

  final Map<String, _Entry> _store = {};

  @override
  Future<String?> read(String key) async {
    final entry = _store[key];
    if (entry == null) return null;
    if (entry.expiresAt != null &&
        DateTime.now().toUtc().isAfter(entry.expiresAt!)) {
      _store.remove(key);
      return null;
    }
    return entry.payload;
  }

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {
    _store[key] = _Entry(
      payload: payload,
      expiresAt: ttl != null ? DateTime.now().toUtc().add(ttl) : null,
    );
    final limit = maxSizeBytes;
    if (limit != null) {
      final total = await totalPayloadBytes();
      if (total > limit) await evictOldest(total - limit);
    }
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  Future<void> deletePrefix(String prefix) async {
    _store.removeWhere((key, _) => key.startsWith(prefix));
  }

  @override
  Future<int> totalPayloadBytes() async =>
      _store.values.fold<int>(0, (sum, e) => sum + e.payload.length);

  @override
  Future<void> evictOldest(int bytesToFree) async {
    if (bytesToFree <= 0) return;
    var freed = 0;
    final sorted = _store.entries.toList()
      ..sort((a, b) => a.value.cachedAt.compareTo(b.value.cachedAt));
    for (final entry in sorted) {
      if (freed >= bytesToFree) break;
      freed += entry.value.payload.length;
      _store.remove(entry.key);
    }
  }

  /// Number of stored entries (for assertions).
  int get length => _store.length;

  /// Raw payload access without TTL check (for assertions).
  String? rawRead(String key) => _store[key]?.payload;
}

class _Entry {
  _Entry({required this.payload, this.expiresAt})
    : cachedAt = DateTime.now().toUtc();

  final String payload;
  final DateTime? expiresAt;
  final DateTime cachedAt;
}
