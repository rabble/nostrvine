import 'package:feed_tuning_repository/feed_tuning_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

class _MockNostrClient extends Mock implements NostrClient {}

final String _userPubkey = 'a' * 64;

VideoEvent _video({
  String id = 'video-event-id-0001',
  String pubkey = 'creator-pubkey-hex',
  Map<String, String> rawTags = const {},
  String? vineId,
  List<String> hashtags = const [],
  String? sourceRelay,
  int? eventKind,
}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: 0,
    content: '',
    timestamp: DateTime(2020),
    rawTags: rawTags,
    vineId: vineId,
    hashtags: hashtags,
    sourceRelay: sourceRelay,
    eventKind: eventKind,
  );
}

List<String>? _tag(Event event, String name) {
  for (final tag in event.tags) {
    if (tag.isNotEmpty && tag.first == name) return tag;
  }
  return null;
}

void main() {
  setUpAll(() {
    registerFallbackValue(Event(_userPubkey, EventKind.textNote, const [], ''));
  });

  group(FeedTuningRepository, () {
    late _MockNostrClient nostrClient;
    late List<({Object error, String site})> reported;
    late FeedTuningRepository repository;

    setUp(() {
      nostrClient = _MockNostrClient();
      reported = [];
      when(() => nostrClient.publicKey).thenReturn(_userPubkey);
      when(() => nostrClient.publishEvent(any())).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );
      repository = FeedTuningRepository(
        nostrClient: nostrClient,
        errorReporter: (error, stackTrace, {required site}) =>
            reported.add((error: error, site: site)),
      );
    });

    Event capturedEvent() =>
        verify(() => nostrClient.publishEvent(captureAny())).captured.single
            as Event;

    group('tune', () {
      test('publishes a feedTuning event signed by the current user', () async {
        await repository.tune(
          video: _video(),
          direction: FeedTuningDirection.more,
        );

        final event = capturedEvent();
        expect(event.kind, equals(EventKind.feedTuning));
        expect(event.pubkey, equals(_userPubkey));
        expect(event.content, isEmpty);
      });

      test('encodes "more" in the direction tag', () async {
        await repository.tune(
          video: _video(),
          direction: FeedTuningDirection.more,
        );
        expect(
          _tag(capturedEvent(), 'direction'),
          equals(['direction', 'more']),
        );
      });

      test('encodes "less" in the direction tag', () async {
        await repository.tune(
          video: _video(),
          direction: FeedTuningDirection.less,
        );
        expect(
          _tag(capturedEvent(), 'direction'),
          equals(['direction', 'less']),
        );
      });

      test('tags the video event id, creator, and target kind', () async {
        await repository.tune(
          video: _video(id: 'vid-123', pubkey: 'creator-99', eventKind: 34236),
          direction: FeedTuningDirection.more,
        );

        final event = capturedEvent();
        expect(
          _tag(event, 'e'),
          equals(['e', 'vid-123', feedTuningDefaultRelayHint]),
        );
        expect(_tag(event, 'p'), equals(['p', 'creator-99']));
        expect(_tag(event, 'k'), equals(['k', '34236']));
      });

      test('omits the a tag when the video has no real d tag', () async {
        await repository.tune(
          video: _video(vineId: 'falls-back-to-event-id'),
          direction: FeedTuningDirection.more,
        );
        expect(_tag(capturedEvent(), 'a'), isNull);
      });

      test('includes the a coordinate when a real d tag is present', () async {
        await repository.tune(
          video: _video(
            pubkey: 'creator-99',
            rawTags: const {'d': 'real-d-tag'},
            vineId: 'real-d-tag',
            eventKind: 34236,
          ),
          direction: FeedTuningDirection.more,
        );
        expect(
          _tag(capturedEvent(), 'a'),
          equals([
            'a',
            '34236:creator-99:real-d-tag',
            feedTuningDefaultRelayHint,
          ]),
        );
      });

      test('builds the a coordinate from the actual video kind', () async {
        await repository.tune(
          video: _video(
            pubkey: 'creator-99',
            rawTags: const {'d': 'real-d-tag'},
            vineId: 'real-d-tag',
            eventKind: 34235,
          ),
          direction: FeedTuningDirection.more,
        );
        expect(
          _tag(capturedEvent(), 'a'),
          equals([
            'a',
            '34235:creator-99:real-d-tag',
            feedTuningDefaultRelayHint,
          ]),
        );
      });

      test('emits one t tag per hashtag', () async {
        await repository.tune(
          video: _video(hashtags: const ['fitness', 'cats']),
          direction: FeedTuningDirection.more,
        );

        final tTags = capturedEvent().tags.where(
          (t) => t.isNotEmpty && t.first == 't',
        );
        expect(
          tTags,
          equals([
            ['t', 'fitness'],
            ['t', 'cats'],
          ]),
        );
      });

      test(
        'adds a relay hint to e and a tags when sourceRelay is set',
        () async {
          await repository.tune(
            video: _video(
              pubkey: 'creator-99',
              rawTags: const {'d': 'real-d-tag'},
              vineId: 'real-d-tag',
              sourceRelay: 'wss://relay.divine.video',
            ),
            direction: FeedTuningDirection.more,
          );

          final event = capturedEvent();
          expect(_tag(event, 'e')!.last, equals('wss://relay.divine.video'));
          expect(_tag(event, 'a')!.last, equals('wss://relay.divine.video'));
        },
      );

      test('returns the published event id', () async {
        final id = await repository.tune(
          video: _video(),
          direction: FeedTuningDirection.more,
        );
        expect(id, equals(capturedEvent().id));
      });

      test(
        'returns null and does not publish when there is no public key',
        () async {
          when(() => nostrClient.publicKey).thenReturn('');

          final id = await repository.tune(
            video: _video(),
            direction: FeedTuningDirection.more,
          );

          expect(id, isNull);
          verifyNever(() => nostrClient.publishEvent(any()));
        },
      );

      test('returns null when the signer is unavailable (throws)', () async {
        when(() => nostrClient.publicKey).thenThrow(StateError('no key'));

        final id = await repository.tune(
          video: _video(),
          direction: FeedTuningDirection.more,
        );

        expect(id, isNull);
        verifyNever(() => nostrClient.publishEvent(any()));
        expect(reported, isEmpty);
      });

      test(
        'still returns the id and does not report on relay failure',
        () async {
          when(
            () => nostrClient.publishEvent(any()),
          ).thenThrow(Exception('relay down'));

          final id = await repository.tune(
            video: _video(),
            direction: FeedTuningDirection.more,
          );

          expect(id, isNotNull);
          expect(reported, isEmpty);
        },
      );

      test(
        'reports an invariant violation when the user key is invalid',
        () async {
          when(() => nostrClient.publicKey).thenReturn('not-a-valid-hex-key');

          final id = await repository.tune(
            video: _video(),
            direction: FeedTuningDirection.more,
          );

          expect(id, isNull);
          expect(reported.single.site, equals(FeedTuningReportableSites.tune));
        },
      );
    });

    group('undo', () {
      test(
        'publishes a kind-5 deletion referencing the tuning event',
        () async {
          await repository.undo('tuning-event-id-77');

          final event = capturedEvent();
          expect(event.kind, equals(EventKind.eventDeletion));
          expect(_tag(event, 'e'), equals(['e', 'tuning-event-id-77']));
          expect(_tag(event, 'k'), equals(['k', '${EventKind.feedTuning}']));
        },
      );

      test('is a no-op without a signer', () async {
        when(() => nostrClient.publicKey).thenReturn('');
        await repository.undo('tuning-event-id-77');
        verifyNever(() => nostrClient.publishEvent(any()));
      });
    });
  });
}
