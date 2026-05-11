import 'package:flutter/foundation.dart';

/// A single value emitted by the cache system.
///
/// Use [isLive] to distinguish a stale cache hit from a fresh network result.
sealed class CacheResult<T> {
  /// Creates a result that was served from the local cache.
  const factory CacheResult.cached(T data) = _CachedResult<T>;

  /// Creates a result that was fetched live from the network.
  const factory CacheResult.live(T data) = _LiveResult<T>;

  const CacheResult._(this.data);

  /// The unwrapped value.
  final T data;

  /// `true` when the value came from the network (the authoritative source).
  /// `false` when the value was served from the local cache.
  bool get isLive;

  /// `true` when the value was served from the local cache and a live fetch
  /// is still in progress. Convenience inverse of [isLive].
  bool get isStale => !isLive;
}

@immutable
final class _CachedResult<T> extends CacheResult<T> {
  const _CachedResult(super.data) : super._();
  @override
  bool get isLive => false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _CachedResult<T> && other.data == data);

  @override
  int get hashCode => Object.hash(false, data);
}

@immutable
final class _LiveResult<T> extends CacheResult<T> {
  const _LiveResult(super.data) : super._();

  @override
  bool get isLive => true;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is _LiveResult<T> && other.data == data);

  @override
  int get hashCode => Object.hash(true, data);
}
