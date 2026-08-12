import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/feed_retry_scheduler.dart';
import 'package:openvine/services/video_event_service.dart';

class _FakeConnectionStatusService extends ConnectionStatusService {
  bool online = true;

  @override
  bool get isOnline => online;

  @override
  bool get isConnected => online;
}

void main() {
  group(FeedRetryScheduler, () {
    late _FakeConnectionStatusService connectionService;
    late List<SubscriptionType> resubscribed;
    late List<SubscriptionType> relayNotReady;
    late Future<void> Function(SubscriptionType) resubscribe;

    FeedRetryScheduler build() => FeedRetryScheduler(
      connectionService: connectionService,
      resubscribe: (type) {
        resubscribed.add(type);
        return resubscribe(type);
      },
      onRelayNotReady: relayNotReady.add,
    );

    setUp(() {
      connectionService = _FakeConnectionStatusService();
      resubscribed = [];
      relayNotReady = [];
      resubscribe = (_) async {};
    });

    tearDown(() => connectionService.dispose());

    group('recordFeedLoadTimeout', () {
      test('allows a retry until the budget is spent', () {
        final scheduler = build();
        addTearDown(scheduler.dispose);

        expect(
          [
            for (var i = 0; i < 5; i++)
              scheduler.recordFeedLoadTimeout(SubscriptionType.discovery),
          ],
          [true, true, true, false, false],
        );
      });

      test('counts each feed type on its own budget', () {
        final scheduler = build();
        addTearDown(scheduler.dispose);

        for (var i = 0; i < 4; i++) {
          scheduler.recordFeedLoadTimeout(SubscriptionType.discovery);
        }

        expect(
          scheduler.recordFeedLoadTimeout(SubscriptionType.hashtag),
          isTrue,
          reason: 'a hashtag feed is not charged for the discovery feed',
        );
      });

      test('a served feed starts over with a full budget', () {
        final scheduler = build();
        addTearDown(scheduler.dispose);

        for (var i = 0; i < 4; i++) {
          scheduler.recordFeedLoadTimeout(SubscriptionType.discovery);
        }
        expect(
          scheduler.recordFeedLoadTimeout(SubscriptionType.discovery),
          isFalse,
        );

        scheduler.recordFeedServed(SubscriptionType.discovery);

        expect(
          [
            for (var i = 0; i < 4; i++)
              scheduler.recordFeedLoadTimeout(SubscriptionType.discovery),
          ],
          [true, true, true, false],
        );
      });
    });

    group('scheduleWhenOnline', () {
      test('re-issues the feed after the retry delay', () {
        fakeAsync((fake) {
          final scheduler = build();
          addTearDown(scheduler.dispose);

          scheduler.scheduleWhenOnline(SubscriptionType.profile);
          expect(resubscribed, isEmpty);

          fake
            ..elapse(const Duration(seconds: 10))
            ..flushMicrotasks();

          expect(resubscribed, [SubscriptionType.profile]);
        });
      });

      test('waits for the network instead of spending attempts offline', () {
        fakeAsync((fake) {
          final scheduler = build();
          addTearDown(scheduler.dispose);

          connectionService.online = false;
          scheduler.scheduleWhenOnline(SubscriptionType.profile);
          fake
            ..elapse(const Duration(minutes: 5))
            ..flushMicrotasks();
          expect(resubscribed, isEmpty);

          connectionService.online = true;
          fake
            ..elapse(const Duration(seconds: 10))
            ..flushMicrotasks();
          expect(resubscribed, [SubscriptionType.profile]);
        });
      });

      test('stops after maxAttempts when every re-issue fails', () {
        fakeAsync((fake) {
          resubscribe = (_) async => throw StateError('no relay');
          final scheduler = build();
          addTearDown(scheduler.dispose);

          scheduler.scheduleWhenOnline(SubscriptionType.profile);
          fake
            ..elapse(const Duration(minutes: 5))
            ..flushMicrotasks();

          expect(resubscribed, hasLength(3));
        });
      });

      test('hands a relay-not-ready failure to the relay-ready retry', () {
        fakeAsync((fake) {
          resubscribe = (_) async =>
              throw const RelayNotReadyException('no relay');
          final scheduler = build();
          addTearDown(scheduler.dispose);

          scheduler.scheduleWhenOnline(SubscriptionType.profile);
          fake
            ..elapse(const Duration(minutes: 5))
            ..flushMicrotasks();

          expect(relayNotReady, [SubscriptionType.profile]);
          expect(
            resubscribed,
            hasLength(1),
            reason: 'the online cycle hands the type over instead of retrying',
          );
        });
      });

      test('dispose stops a cycle already in flight', () {
        fakeAsync((fake) {
          build()
            ..scheduleWhenOnline(SubscriptionType.profile)
            ..dispose();

          fake
            ..elapse(const Duration(minutes: 5))
            ..flushMicrotasks();

          expect(resubscribed, isEmpty);
        });
      });
    });
  });
}
