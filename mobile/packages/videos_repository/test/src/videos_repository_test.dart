import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';
import 'package:videos_repository/videos_repository.dart';

class MockNostrClient extends Mock implements NostrClient {}

void main() {
  group('VideosRepository', () {
    late MockNostrClient mockNostrClient;
    late VideosRepository repository;

    const testUserPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const otherUserPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
    });

    setUp(() {
      mockNostrClient = MockNostrClient();
      when(() => mockNostrClient.publicKey).thenReturn(testUserPubkey);
      repository = VideosRepository(nostrClient: mockNostrClient);
    });

    group('constructor', () {
      test('creates repository with nostrClient', () {
        expect(repository, isNotNull);
      });

      test('initial myVideoCountStream emits 0', () async {
        expect(await repository.myVideoCountStream.first, equals(0));
      });
    });

    group('getVideoCount', () {
      test('returns 0 for empty pubkey', () async {
        final count = await repository.getVideoCount('');

        expect(count, equals(0));
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('returns count of video events for pubkey', () async {
        final videoEvents = [
          _createVideoEvent(id: 'video1', pubkey: otherUserPubkey),
          _createVideoEvent(id: 'video2', pubkey: otherUserPubkey),
          _createVideoEvent(id: 'video3', pubkey: otherUserPubkey),
        ];

        when(() => mockNostrClient.queryEvents(any()))
            .thenAnswer((_) async => videoEvents);

        final count = await repository.getVideoCount(otherUserPubkey);

        expect(count, equals(3));
        verify(
          () => mockNostrClient.queryEvents(
            any(
              that: contains(
                isA<Filter>()
                    .having((f) => f.authors, 'authors', [otherUserPubkey])
                    .having((f) => f.kinds, 'kinds', [34236, 34235]),
              ),
            ),
          ),
        ).called(1);
      });

      test('returns 0 when no videos found', () async {
        when(() => mockNostrClient.queryEvents(any()))
            .thenAnswer((_) async => []);

        final count = await repository.getVideoCount(otherUserPubkey);

        expect(count, equals(0));
      });
    });

    group('initialize', () {
      test('does nothing when pubkey is empty', () async {
        // Create a new repository with empty pubkey for this test
        when(() => mockNostrClient.publicKey).thenReturn('');
        final emptyPubkeyRepository = VideosRepository(
          nostrClient: mockNostrClient,
        );

        await emptyPubkeyRepository.initialize();

        verifyNever(() => mockNostrClient.subscribe(any()));
      });

      test('subscribes to video events for current user', () async {
        final streamController = StreamController<Event>();

        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => streamController.stream);

        await repository.initialize();

        verify(
          () => mockNostrClient.subscribe(
            any(
              that: contains(
                isA<Filter>()
                    .having((f) => f.authors, 'authors', [testUserPubkey])
                    .having((f) => f.kinds, 'kinds', [34236, 34235]),
              ),
            ),
            subscriptionId: 'my_videos_count_$testUserPubkey',
          ),
        ).called(1);

        await streamController.close();
      });

      test('updates count when video events arrive', () async {
        final streamController = StreamController<Event>();

        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => streamController.stream);

        await repository.initialize();

        final counts = <int>[];
        final subscription = repository.myVideoCountStream.listen(counts.add);

        // Emit video events
        streamController.add(_createVideoEvent(id: 'video1'));
        await Future<void>.delayed(Duration.zero);

        streamController.add(_createVideoEvent(id: 'video2'));
        await Future<void>.delayed(Duration.zero);

        streamController.add(_createVideoEvent(id: 'video3'));
        await Future<void>.delayed(Duration.zero);

        expect(counts, contains(1));
        expect(counts, contains(2));
        expect(counts, contains(3));

        await subscription.cancel();
        await streamController.close();
      });

      test('deduplicates video events by id', () async {
        final streamController = StreamController<Event>();

        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => streamController.stream);

        await repository.initialize();

        final counts = <int>[];
        final subscription = repository.myVideoCountStream.listen(counts.add);

        // Emit same video event twice
        streamController.add(_createVideoEvent(id: 'video1'));
        await Future<void>.delayed(Duration.zero);

        streamController.add(_createVideoEvent(id: 'video1')); // duplicate
        await Future<void>.delayed(Duration.zero);

        streamController.add(_createVideoEvent(id: 'video2'));
        await Future<void>.delayed(Duration.zero);

        // Should only count unique videos
        expect(counts.last, equals(2));

        await subscription.cancel();
        await streamController.close();
      });

      test('does not re-subscribe if already subscribed', () async {
        final streamController = StreamController<Event>.broadcast();

        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => streamController.stream);

        await repository.initialize();
        await repository.initialize(); // second call

        verify(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).called(1); // only called once

        await streamController.close();
      });
    });

    group('dispose', () {
      test('cancels subscription and unsubscribes', () async {
        final streamController = StreamController<Event>();

        when(
          () => mockNostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
          ),
        ).thenAnswer((_) => streamController.stream);
        when(() => mockNostrClient.unsubscribe(any()))
            .thenAnswer((_) async {});

        await repository.initialize();
        await repository.dispose();

        verify(
          () => mockNostrClient.unsubscribe('my_videos_count_$testUserPubkey'),
        ).called(1);
      });

      test('closes the stream subject', () async {
        await repository.dispose();

        // After dispose, the stream completes immediately (done event)
        final completer = Completer<void>();
        repository.myVideoCountStream.listen(
          (_) {},
          onDone: completer.complete,
        );

        // The stream should complete quickly since it's already closed
        await expectLater(
          completer.future.timeout(const Duration(milliseconds: 100)),
          completes,
        );
      });
    });
  });
}

/// Creates a mock video event for testing.
Event _createVideoEvent({
  required String id,
  String pubkey = 'testpubkey',
  int kind = 34236, // NIP-71 vertical video
}) {
  return Event.fromJson({
    'id': id,
    'pubkey': pubkey,
    'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    'kind': kind,
    'tags': <List<String>>[],
    'content': '',
    'sig':
        '0000000000000000000000000000000000000000000000000000000000000000'
        '0000000000000000000000000000000000000000000000000000000000000000',
  });
}
