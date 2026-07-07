// ABOUTME: Tests for durable product analytics retry queue.
// ABOUTME: Verifies enqueue, flush, transient retry, and dead-letter behavior.

import 'package:db_client/db_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/analytics_ingest_client.dart';
import 'package:openvine/services/product_event_queue.dart';

class _MockPendingProductEventsDao extends Mock
    implements PendingProductEventsDao {}

class _MockAnalyticsIngestClient extends Mock
    implements AnalyticsIngestClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(_pendingProductEventFallback());
  });

  group(ProductEventQueue, () {
    late _MockPendingProductEventsDao dao;
    late _MockAnalyticsIngestClient client;
    late ProductEventQueue queue;

    setUp(() {
      dao = _MockPendingProductEventsDao();
      client = _MockAnalyticsIngestClient();
      queue = ProductEventQueue(
        dao: dao,
        ingestClient: client,
        retryConfig: const ProductEventRetryConfig(
          maxAttempts: 3,
          initialDelay: Duration(seconds: 1),
        ),
        now: () => DateTime.utc(2026, 7, 7, 12),
      );
    });

    test(
      'enqueue persists complete payload and does not call network',
      () async {
        when(() => dao.enqueue(any())).thenAnswer((_) async {});
        final event = _event('event-a');

        await queue.enqueue(event);

        final captured =
            verify(() => dao.enqueue(captureAny())).captured.single
                as PendingProductEvent;
        expect(captured.id, 'event-a');
        expect(captured.eventName, 'screen_time');
        expect(captured.payloadJson, contains('"event_id":"event-a"'));
        expect(captured.status, PendingProductEventStatus.pending);
        verifyNever(() => client.publishBatch(any()));
      },
    );

    test('flush deletes rows accepted by ingest', () async {
      when(
        () => dao.getRetryable(
          now: any(named: 'now'),
          maxAttempts: any(named: 'maxAttempts'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [_row('event-a')]);
      when(() => dao.markPublishing('event-a')).thenAnswer((_) async => true);
      when(
        () => client.publishBatch(any()),
      ).thenAnswer((_) async => const AnalyticsIngestAccepted());
      when(() => dao.deleteById('event-a')).thenAnswer((_) async => 1);

      await queue.flush();

      verify(() => client.publishBatch(any(that: hasLength(1)))).called(1);
      verify(() => dao.deleteById('event-a')).called(1);
    });

    test(
      'recoverPublishingAndFlush resets orphaned publishing rows first',
      () async {
        when(() => dao.resetPublishingToPending()).thenAnswer((_) async => 1);
        when(
          () => dao.getRetryable(
            now: any(named: 'now'),
            maxAttempts: any(named: 'maxAttempts'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => [_row('event-a')]);
        when(() => dao.markPublishing('event-a')).thenAnswer((_) async => true);
        when(
          () => client.publishBatch(any()),
        ).thenAnswer((_) async => const AnalyticsIngestAccepted());
        when(() => dao.deleteById('event-a')).thenAnswer((_) async => 1);

        await queue.recoverPublishingAndFlush();

        verifyInOrder([
          () => dao.resetPublishingToPending(),
          () => dao.getRetryable(
            now: any(named: 'now'),
            maxAttempts: any(named: 'maxAttempts'),
            limit: any(named: 'limit'),
          ),
          () => dao.markPublishing('event-a'),
          () => client.publishBatch(any(that: hasLength(1))),
          () => dao.deleteById('event-a'),
        ]);
      },
    );

    test('flush schedules retry after transient failure', () async {
      when(
        () => dao.getRetryable(
          now: any(named: 'now'),
          maxAttempts: any(named: 'maxAttempts'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [_row('event-a')]);
      when(() => dao.markPublishing('event-a')).thenAnswer((_) async => true);
      when(() => client.publishBatch(any())).thenAnswer(
        (_) async => const AnalyticsIngestTransientFailure('timeout'),
      );
      when(
        () => dao.markFailed(
          'event-a',
          'timeout',
          nextAttemptAt: any(named: 'nextAttemptAt'),
        ),
      ).thenAnswer((_) async => true);

      await queue.flush();

      final captured =
          verify(
                () => dao.markFailed(
                  'event-a',
                  'timeout',
                  nextAttemptAt: captureAny(named: 'nextAttemptAt'),
                ),
              ).captured.single
              as DateTime;
      expect(captured, DateTime.utc(2026, 7, 7, 12, 0, 1));
    });

    test('flush dead-letters non-retryable rejected rows', () async {
      when(
        () => dao.getRetryable(
          now: any(named: 'now'),
          maxAttempts: any(named: 'maxAttempts'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [_row('event-a')]);
      when(() => dao.markPublishing('event-a')).thenAnswer((_) async => true);
      when(() => client.publishBatch(any())).thenAnswer(
        (_) async => const AnalyticsIngestRejected(
          statusCode: 422,
          reason: 'schema rejected',
        ),
      );
      when(
        () => dao.markDeadLetter('event-a', 'schema rejected'),
      ).thenAnswer((_) async => true);

      await queue.flush();

      verify(() => dao.markDeadLetter('event-a', 'schema rejected')).called(1);
    });
  });
}

ProductAnalyticsEvent _event(String id) {
  return ProductAnalyticsEvent(
    eventId: id,
    eventName: 'screen_time',
    occurredAt: DateTime.utc(2026, 7, 7, 12),
    userPubkey:
        '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd',
    anonymousId: '018ff7d7-2ef5-7000-8000-000000000001',
    sessionId: '018ff7d7-2ef5-7000-8000-000000000002',
    platform: 'ios',
    appVersion: '1.2.3',
    buildNumber: '123',
    surface: AnalyticsSurface.feed,
  );
}

PendingProductEvent _row(String id) {
  return PendingProductEvent(
    id: id,
    eventName: 'screen_time',
    payloadJson: _event(id).toPayloadJson(),
    status: PendingProductEventStatus.pending,
    createdAt: DateTime.utc(2026, 7, 7, 12),
  );
}

PendingProductEvent _pendingProductEventFallback() {
  return _row('fallback');
}
