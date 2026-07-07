// ABOUTME: Bounded TTL cache for avatar URLs known to have failed loading
// ABOUTME: Prevents repeated fetch/log loops for broken profile images

import 'package:flutter/foundation.dart';

typedef AvatarFailureClock = DateTime Function();

enum AvatarFailureKind { deterministic, transient, cancelled }

class AvatarFailureCache {
  AvatarFailureCache._({
    required AvatarFailureClock clock,
    required int maxEntries,
  }) : _clock = clock,
       _maxEntries = maxEntries;

  static final AvatarFailureCache instance = AvatarFailureCache._(
    clock: DateTime.now,
    maxEntries: maxEntries,
  );

  @visibleForTesting
  factory AvatarFailureCache.testing({
    required AvatarFailureClock clock,
    int maxEntries = AvatarFailureCache.maxEntries,
  }) {
    return AvatarFailureCache._(clock: clock, maxEntries: maxEntries);
  }

  static const int maxEntries = 128;
  static const Duration deterministicFailureTtl = Duration(hours: 1);
  static const Duration transientFailureTtl = Duration(seconds: 30);

  final int _maxEntries;
  AvatarFailureClock _clock;
  final _failedUrls = <String, DateTime>{};

  bool isFailed(String url) {
    final expiresAt = _failedUrls.remove(url);
    if (expiresAt == null) return false;

    if (!_clock().isBefore(expiresAt)) {
      return false;
    }

    _failedUrls[url] = expiresAt;
    return true;
  }

  void recordFailure(String url, {required Duration ttl}) {
    if (url.isEmpty || ttl <= Duration.zero) return;

    _failedUrls.remove(url);
    _failedUrls[url] = _clock().add(ttl);

    while (_failedUrls.length > _maxEntries) {
      _failedUrls.remove(_failedUrls.keys.first);
    }
  }

  AvatarFailureKind recordFailureForError(String url, Object error) {
    final kind = classifyFailure(error);
    switch (kind) {
      case AvatarFailureKind.deterministic:
        recordFailure(url, ttl: deterministicFailureTtl);
      case AvatarFailureKind.transient:
        recordFailure(url, ttl: transientFailureTtl);
      case AvatarFailureKind.cancelled:
        break;
    }
    return kind;
  }

  @visibleForTesting
  static AvatarFailureKind classifyFailure(Object error) {
    final message = error.toString().toLowerCase();
    if (message.contains('load cancelled')) {
      return AvatarFailureKind.cancelled;
    }
    if (message.contains('invalid image data') ||
        message.contains('image codec failed')) {
      return AvatarFailureKind.deterministic;
    }
    return AvatarFailureKind.transient;
  }

  @visibleForTesting
  void clear() {
    _failedUrls.clear();
  }

  @visibleForTesting
  void resetClockForTesting() {
    _clock = DateTime.now;
  }
}
