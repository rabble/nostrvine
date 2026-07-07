// ABOUTME: Durable retry queue for first-party product analytics events.
// ABOUTME: Persists payloads locally and flushes them to the analytics ingest API.

import 'package:db_client/db_client.dart';
import 'package:openvine/services/analytics_ingest_client.dart';

class ProductEventRetryConfig {
  const ProductEventRetryConfig({
    this.maxAttempts = 5,
    this.batchSize = 25,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
  });

  final int maxAttempts;
  final int batchSize;
  final Duration initialDelay;
  final Duration maxDelay;
  final double backoffMultiplier;

  Duration backoffFor(int attemptCount) {
    if (attemptCount <= 0) return initialDelay;
    var ms = initialDelay.inMilliseconds.toDouble();
    for (var i = 1; i < attemptCount; i++) {
      ms *= backoffMultiplier;
      if (ms >= maxDelay.inMilliseconds) return maxDelay;
    }
    return Duration(milliseconds: ms.round());
  }
}

class ProductEventQueue {
  ProductEventQueue({
    required PendingProductEventsDao dao,
    required AnalyticsIngestClient ingestClient,
    ProductEventRetryConfig retryConfig = const ProductEventRetryConfig(),
    DateTime Function() now = DateTime.now,
  }) : _dao = dao,
       _ingestClient = ingestClient,
       _retryConfig = retryConfig,
       _now = now;

  final PendingProductEventsDao _dao;
  final AnalyticsIngestClient _ingestClient;
  final ProductEventRetryConfig _retryConfig;
  final DateTime Function() _now;

  bool _isFlushing = false;

  Future<void> enqueue(ProductAnalyticsEvent event) async {
    await _dao.enqueue(
      PendingProductEvent(
        id: event.eventId,
        eventName: event.eventName,
        payloadJson: event.toPayloadJson(),
        status: PendingProductEventStatus.pending,
        createdAt: event.occurredAt,
      ),
    );
  }

  Future<void> flush() async {
    if (_isFlushing) return;
    _isFlushing = true;
    try {
      await _flushUnlocked();
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> recoverPublishingAndFlush() async {
    if (_isFlushing) return;
    _isFlushing = true;
    try {
      await _dao.resetPublishingToPending();
      await _flushUnlocked();
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> _flushUnlocked() async {
    final rows = await _dao.getRetryable(
      now: _now(),
      maxAttempts: _retryConfig.maxAttempts,
      limit: _retryConfig.batchSize,
    );
    if (rows.isEmpty) return;

    final claimed = <PendingProductEvent>[];
    for (final row in rows) {
      final marked = await _dao.markPublishing(row.id);
      if (marked) claimed.add(row);
    }
    if (claimed.isEmpty) return;

    final events = claimed
        .map((row) => ProductAnalyticsEvent.fromPayloadJson(row.payloadJson))
        .toList();
    final result = await _ingestClient.publishBatch(events);

    switch (result) {
      case AnalyticsIngestAccepted():
        for (final row in claimed) {
          await _dao.deleteById(row.id);
        }
      case AnalyticsIngestRejected(:final reason):
        for (final row in claimed) {
          await _dao.markDeadLetter(row.id, reason);
        }
      case AnalyticsIngestTransientFailure(:final reason):
        for (final row in claimed) {
          if (row.attemptCount + 1 >= _retryConfig.maxAttempts) {
            await _dao.markDeadLetter(row.id, reason);
            continue;
          }
          await _dao.markFailed(
            row.id,
            reason,
            nextAttemptAt: _now().add(
              _retryConfig.backoffFor(row.attemptCount + 1),
            ),
          );
        }
    }
  }
}
