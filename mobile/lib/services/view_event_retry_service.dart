// ABOUTME: Service that auto-sweeps durable pending view events.
// ABOUTME: Publishes queued kind 22236 views until relay delivery succeeds.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/services/view_event_publisher.dart';

/// Backoff configuration for [ViewEventRetryService].
class ViewEventRetryConfig {
  const ViewEventRetryConfig({
    this.maxRetries = 5,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
  });

  final int maxRetries;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;

  Duration backoffFor(int retryCount) {
    if (retryCount <= 0) return Duration.zero;
    var ms = initialDelay.inMilliseconds.toDouble();
    for (var i = 0; i < retryCount; i++) {
      ms *= backoffMultiplier;
      if (ms >= maxDelay.inMilliseconds) return maxDelay;
    }
    return Duration(milliseconds: ms.round());
  }
}

/// Sweeps the durable `pending_view_events` queue for relay publish retries.
class ViewEventRetryService {
  ViewEventRetryService({
    required ViewEventPublisher viewEventPublisher,
    required PendingViewEventsDao pendingViewEventsDao,
    required String userPubkey,
    required Stream<bool> appForegroundStream,
    ViewEventRetryConfig retryConfig = const ViewEventRetryConfig(),
    DateTime Function() now = DateTime.now,
  }) : _viewEventPublisher = viewEventPublisher,
       _dao = pendingViewEventsDao,
       _userPubkey = userPubkey,
       _appForegroundStream = appForegroundStream,
       _retryConfig = retryConfig,
       _now = now;

  final ViewEventPublisher _viewEventPublisher;
  final PendingViewEventsDao _dao;
  final String _userPubkey;
  final Stream<bool> _appForegroundStream;
  final ViewEventRetryConfig _retryConfig;
  final DateTime Function() _now;

  StreamSubscription<bool>? _foregroundSubscription;
  bool _isInitialized = false;
  bool _isSweeping = false;

  bool get isInitialized => _isInitialized;

  @visibleForTesting
  bool get isSweeping => _isSweeping;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _dao.resetPublishingToPending(_userPubkey);
    _foregroundSubscription = _appForegroundStream.listen((foreground) {
      if (foreground) {
        unawaited(sweep());
      }
    });
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
    _isInitialized = false;
  }

  Future<void> sweep() async {
    if (_isSweeping) return;
    _isSweeping = true;

    try {
      final retryable = await _dao.getRetryableForUser(
        userPubkey: _userPubkey,
        maxRetries: _retryConfig.maxRetries,
      );

      for (final row in retryable) {
        if (_isTerminal(row)) {
          await _dao.deleteById(row.id);
          continue;
        }

        final lastAttempt = row.lastAttemptAt;
        if (lastAttempt != null) {
          final gap = _now().difference(lastAttempt);
          if (gap < _retryConfig.backoffFor(row.retryCount)) continue;
        }

        final marked = await _dao.markPublishing(row.id);
        if (!marked) continue;

        try {
          final success = await _viewEventPublisher.publishViewEvent(
            video: _toVideoEvent(row),
            startSeconds: 0,
            endSeconds: row.watchDurationMs ~/ 1000,
            source: _trafficSourceFrom(row.trafficSource),
            sourceDetail: row.sourceDetail,
            loopCount: row.loopCount,
          );
          if (success) {
            await _dao.deleteById(row.id);
          } else {
            await _dao.markFailed(row.id, 'publish returned false');
          }
        } on Object catch (e) {
          await _dao.markFailed(row.id, e.toString());
        }
      }
    } finally {
      _isSweeping = false;
    }
  }

  bool _isTerminal(PendingViewEvent row) {
    return row.videoPubkey == _userPubkey || row.watchDurationMs < 1000;
  }

  VideoEvent _toVideoEvent(PendingViewEvent row) {
    return VideoEvent(
      id: row.videoId,
      pubkey: row.videoPubkey,
      createdAt: row.createdAt.millisecondsSinceEpoch ~/ 1000,
      content: '',
      timestamp: row.createdAt,
      vineId: row.videoVineId,
    );
  }

  ViewTrafficSource _trafficSourceFrom(String raw) {
    return switch (raw) {
      'home' => ViewTrafficSource.home,
      'profile' => ViewTrafficSource.profile,
      'search' => ViewTrafficSource.search,
      'share' => ViewTrafficSource.share,
      'discovery:new' || 'discovery_new' => ViewTrafficSource.discoveryNew,
      'discovery:popular' ||
      'discovery_popular' => ViewTrafficSource.discoveryPopular,
      'discovery:classic' ||
      'discovery_classic' => ViewTrafficSource.discoveryClassic,
      'discovery:foryou' ||
      'discovery_for_you' => ViewTrafficSource.discoveryForYou,
      _ => ViewTrafficSource.unknown,
    };
  }
}
