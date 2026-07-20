import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event, EventKind, Filter;
import 'package:openvine/models/content_label.dart';
import 'package:openvine/repositories/community_content_label_repository.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockVideoEvent extends Mock implements VideoEvent {}

// 64-hex pubkeys for distinct authors.
String _hex(String seed) => (seed * 64).substring(0, 64);

const _placeholderPubkey =
    '0000000000000000000000000000000000000000000000000000000000000000';

Event _labelEvent(
  String author,
  List<String> labelValues, {
  required String videoId,
  String namespace = 'content-warning',
}) {
  return Event(
    author,
    EventKind.label,
    [
      ['L', namespace],
      for (final value in labelValues) ['l', value, namespace],
      ['e', videoId],
    ],
    '',
  );
}

void main() {
  group(CommunityContentLabelRepository, () {
    late _MockNostrClient nostrClient;
    late _MockProfileRepository profileRepository;
    late CommunityContentLabelRepository repository;
    late _MockVideoEvent video;

    const videoId =
        'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2';
    const creatorPubkey =
        'c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0c0';
    const addressableId = '34236:$creatorPubkey:vine123';

    final authorA = _hex('a');
    final authorB = _hex('b');
    final authorC = _hex('d');

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(
        Event(_placeholderPubkey, EventKind.label, const [], ''),
      );
    });

    setUp(() {
      nostrClient = _MockNostrClient();
      profileRepository = _MockProfileRepository();
      repository = CommunityContentLabelRepository(
        nostrClient: nostrClient,
        profileRepository: profileRepository,
      );
      video = _MockVideoEvent();
      when(() => video.id).thenReturn(videoId);
      when(() => video.pubkey).thenReturn(creatorPubkey);
      when(() => video.addressableId).thenReturn(addressableId);
      // Default: every author is a Divine identity unless overridden.
      when(
        () => profileRepository.hasDivineIdentity(any()),
      ).thenAnswer((_) async => true);
    });

    void stubQuery(List<Event> events) {
      when(
        () => nostrClient.queryEvents(any()),
      ).thenAnswer((_) async => events);
    }

    group('communityLabelsForVideo', () {
      test(
        'surfaces a label once 3 distinct Divine authors suggest it',
        () async {
          stubQuery([
            _labelEvent(authorA, ['gambling'], videoId: videoId),
            _labelEvent(authorB, ['gambling'], videoId: videoId),
            _labelEvent(authorC, ['gambling'], videoId: videoId),
          ]);

          final result = await repository.communityLabelsForVideo(video);

          expect(result, equals({'gambling'}));
        },
      );

      test('does not surface a label with only 2 distinct authors', () async {
        stubQuery([
          _labelEvent(authorA, ['gambling'], videoId: videoId),
          _labelEvent(authorB, ['gambling'], videoId: videoId),
        ]);

        final result = await repository.communityLabelsForVideo(video);

        expect(result, isEmpty);
      });

      test('counts a repeated author only once', () async {
        stubQuery([
          _labelEvent(authorA, ['gambling'], videoId: videoId),
          _labelEvent(authorA, ['gambling'], videoId: videoId),
          _labelEvent(authorB, ['gambling'], videoId: videoId),
        ]);

        final result = await repository.communityLabelsForVideo(video);

        expect(result, isEmpty);
      });

      test(
        'skips identity lookups for labels below the display threshold',
        () async {
          stubQuery([
            _labelEvent(authorA, ['gambling'], videoId: videoId),
            _labelEvent(authorB, ['gambling'], videoId: videoId),
          ]);

          await repository.communityLabelsForVideo(video);

          verifyNever(() => profileRepository.hasDivineIdentity(any()));
        },
      );

      test(
        'excludes authors without a Divine identity from the count',
        () async {
          when(
            () => profileRepository.hasDivineIdentity(authorC),
          ).thenAnswer((_) async => false);
          stubQuery([
            _labelEvent(authorA, ['gambling'], videoId: videoId),
            _labelEvent(authorB, ['gambling'], videoId: videoId),
            _labelEvent(authorC, ['gambling'], videoId: videoId),
          ]);

          final result = await repository.communityLabelsForVideo(video);

          expect(result, isEmpty);
        },
      );

      test('normalizes label aliases before counting', () async {
        stubQuery([
          _labelEvent(authorA, ['NSFW'], videoId: videoId),
          _labelEvent(authorB, ['nsfw'], videoId: videoId),
          _labelEvent(authorC, ['Nsfw'], videoId: videoId),
        ]);

        final result = await repository.communityLabelsForVideo(video);

        expect(result, equals({'nudity'}));
      });

      test('ignores label values outside the known ContentLabel set', () async {
        stubQuery([
          _labelEvent(authorA, ['banana'], videoId: videoId),
          _labelEvent(authorB, ['banana'], videoId: videoId),
          _labelEvent(authorC, ['banana'], videoId: videoId),
        ]);

        final result = await repository.communityLabelsForVideo(video);

        expect(result, isEmpty);
      });

      test('returns empty set when the query throws', () async {
        when(
          () => nostrClient.queryEvents(any()),
        ).thenThrow(Exception('relay down'));

        final result = await repository.communityLabelsForVideo(video);

        expect(result, isEmpty);
      });

      test(
        'ignores label tags outside the content-warning namespace',
        () async {
          stubQuery([
            _labelEvent(
              authorA,
              ['gambling'],
              videoId: videoId,
              namespace: 'other.namespace',
            ),
            _labelEvent(
              authorB,
              ['gambling'],
              videoId: videoId,
              namespace: 'other.namespace',
            ),
            _labelEvent(
              authorC,
              ['gambling'],
              videoId: videoId,
              namespace: 'other.namespace',
            ),
          ]);

          final result = await repository.communityLabelsForVideo(video);

          expect(result, isEmpty);
        },
      );
    });

    group('suggestLabels', () {
      test(
        'publishes a kind 1985 event with L/l/e/a tags (no p target)',
        () async {
          when(() => nostrClient.publicKey).thenReturn(authorA);
          final captured = <Event>[];
          when(() => nostrClient.publishEvent(captureAny())).thenAnswer((
            invocation,
          ) async {
            captured.add(invocation.positionalArguments.first as Event);
            return PublishSuccess(
              event: Event(_placeholderPubkey, EventKind.label, const [], ''),
            );
          });

          await repository.suggestLabels(
            video: video,
            labels: {ContentLabel.gambling},
          );

          expect(captured, hasLength(1));
          final event = captured.single;
          expect(event.kind, equals(EventKind.label));
          expect(event.tags, contains(equals(['L', 'content-warning'])));
          expect(
            event.tags,
            contains(equals(['l', 'gambling', 'content-warning'])),
          );
          expect(event.tags, contains(equals(['e', videoId])));
          expect(event.tags, contains(equals(['a', addressableId])));
          // No `p` target: a p-scoped 1985 label would flag the creator's
          // account, not the video (NIP-32). Video-scoped e/a only.
          expect(
            event.tags.any((tag) => tag.isNotEmpty && tag[0] == 'p'),
            isFalse,
          );
        },
      );

      test('throws ArgumentError when no labels are provided', () async {
        expect(
          () => repository.suggestLabels(video: video, labels: const {}),
          throwsArgumentError,
        );
      });

      test(
        'throws CommunityLabelPublishException when publish fails',
        () async {
          when(() => nostrClient.publicKey).thenReturn(authorA);
          when(
            () => nostrClient.publishEvent(any()),
          ).thenAnswer((_) async => const PublishNoRelays());

          expect(
            () => repository.suggestLabels(
              video: video,
              labels: {ContentLabel.gambling},
            ),
            throwsA(isA<CommunityLabelPublishException>()),
          );
        },
      );
    });

    group('mySuggestedLabels', () {
      test('returns only the labels the given pubkey suggested', () async {
        stubQuery([
          _labelEvent(authorA, ['gambling'], videoId: videoId),
          _labelEvent(authorB, ['violence'], videoId: videoId),
        ]);

        final result = await repository.mySuggestedLabels(video, authorA);

        expect(result, equals({'gambling'}));
      });

      test(
        'includes a just-published suggestion before the relay echoes it '
        '(read-after-write gap)',
        () async {
          // The relay read model lags writes by a few seconds; the relay
          // query returns nothing yet.
          stubQuery(const []);
          when(() => nostrClient.publicKey).thenReturn(authorA);
          when(() => nostrClient.publishEvent(any())).thenAnswer(
            (_) async => PublishSuccess(
              event: Event(_placeholderPubkey, EventKind.label, const [], ''),
            ),
          );

          await repository.suggestLabels(
            video: video,
            labels: {ContentLabel.gambling},
          );

          final result = await repository.mySuggestedLabels(video, authorA);

          expect(result, equals({'gambling'}));
        },
      );

      test('does not remember a suggestion whose publish failed', () async {
        stubQuery(const []);
        when(() => nostrClient.publicKey).thenReturn(authorA);
        when(
          () => nostrClient.publishEvent(any()),
        ).thenAnswer((_) async => const PublishNoRelays());

        await expectLater(
          repository.suggestLabels(
            video: video,
            labels: {ContentLabel.gambling},
          ),
          throwsA(isA<CommunityLabelPublishException>()),
        );

        final result = await repository.mySuggestedLabels(video, authorA);

        expect(result, isEmpty);
      });
    });
  });
}
