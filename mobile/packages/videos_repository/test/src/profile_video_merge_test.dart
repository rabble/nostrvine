// ABOUTME: Unit tests for the profile/author cross-source merge policy (#3384).

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:videos_repository/videos_repository.dart';

VideoEvent _video({
  required String id,
  String pubkey = 'author',
  int createdAt = 0,
  DateTime? timestamp,
  String? title,
  String? videoUrl,
  String? publishedAt,
  String? vineId,
  Map<String, String> rawTags = const {},
  List<String> hashtags = const [],
  List<String> collaboratorPubkeys = const [],
  List<List<String>> nostrEventTags = const [],
  List<String> contentWarningLabels = const [],
  int? originalLikes,
  int? originalComments,
  int? originalReposts,
  int? originalLoops,
  int? nostrLikeCount,
}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    content: '',
    timestamp:
        timestamp ?? DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    title: title,
    videoUrl: videoUrl,
    publishedAt: publishedAt,
    vineId: vineId,
    rawTags: rawTags,
    hashtags: hashtags,
    collaboratorPubkeys: collaboratorPubkeys,
    nostrEventTags: nostrEventTags,
    contentWarningLabels: contentWarningLabels,
    originalLikes: originalLikes,
    originalComments: originalComments,
    originalReposts: originalReposts,
    originalLoops: originalLoops,
    nostrLikeCount: nostrLikeCount,
  );
}

void main() {
  group('canonicalProfileFeedVideoKey', () {
    test('keys on pubkey:stableId, lowercased', () {
      expect(
        canonicalProfileFeedVideoKey(_video(id: 'ABC', pubkey: 'PUB')),
        equals('pub:abc'),
      );
    });

    test('uses vineId as stableId when present', () {
      expect(
        canonicalProfileFeedVideoKey(
          _video(id: 'evt', pubkey: 'pub', vineId: 'vine9'),
        ),
        equals('pub:vine9'),
      );
    });
  });

  group('mergeProfileFeedVideos', () {
    test('takes the max of every engagement counter (#3384)', () {
      final merged = mergeProfileFeedVideos(
        _video(
          id: 'v',
          createdAt: 1000,
          originalLikes: 5,
          originalComments: 9,
          originalReposts: 1,
          originalLoops: 100,
          nostrLikeCount: 2,
        ),
        _video(
          id: 'v',
          createdAt: 2000,
          originalLikes: 10,
          originalComments: 3,
          originalReposts: 4,
          originalLoops: 50,
          nostrLikeCount: 0,
        ),
      );

      expect(merged.originalLikes, equals(10));
      expect(merged.originalComments, equals(9));
      expect(merged.originalReposts, equals(4));
      expect(merged.originalLoops, equals(100));
      expect(merged.nostrLikeCount, equals(2));
    });

    test('raw tags are primary-wins except views, which takes the max', () {
      final merged = mergeProfileFeedVideos(
        _video(
          id: 'v',
          createdAt: 1000,
          rawTags: {'title': 'old', 'views': '100', 'only_old': 'x'},
        ),
        _video(
          id: 'v',
          createdAt: 2000, // newer => primary
          rawTags: {'title': 'new', 'views': '50', 'only_new': 'y'},
        ),
      );

      expect(merged.rawTags['title'], equals('new')); // primary wins
      expect(merged.rawTags['views'], equals('100')); // max wins
      expect(merged.rawTags['only_old'], equals('x')); // secondary-only kept
      expect(merged.rawTags['only_new'], equals('y'));
    });

    test('newer createdAt selects the primary metadata copy', () {
      final merged = mergeProfileFeedVideos(
        _video(id: 'v', createdAt: 1000, title: 'old', publishedAt: '1000'),
        _video(id: 'v', createdAt: 2000, title: 'new', publishedAt: '2000'),
      );

      expect(merged.title, equals('new'));
    });

    test('primary fields fall back to secondary when null', () {
      final merged = mergeProfileFeedVideos(
        _video(id: 'v', createdAt: 1000, videoUrl: 'http://old/v.mp4'),
        _video(id: 'v', createdAt: 2000, publishedAt: '2000'),
      );

      expect(merged.videoUrl, equals('http://old/v.mp4'));
    });

    test('ties on createdAt break toward the smaller id as primary', () {
      final merged = mergeProfileFeedVideos(
        _video(id: 'bbb', createdAt: 1000, title: 'b', publishedAt: '5'),
        _video(id: 'aaa', createdAt: 1000, title: 'a', publishedAt: '5'),
      );

      // incoming id 'aaa' < existing id 'bbb' => incoming is primary.
      expect(merged.title, equals('a'));
    });

    test('preserves the older createdAt when neither has publishedAt', () {
      final merged = mergeProfileFeedVideos(
        _video(id: 'v', createdAt: 1000),
        _video(id: 'v', createdAt: 2000),
      );

      expect(merged.createdAt, equals(1000));
    });

    test('primary wins on non-empty list fields and keeps its timestamp', () {
      final merged = mergeProfileFeedVideos(
        _video(id: 'v', createdAt: 1000, timestamp: DateTime.utc(2030)),
        _video(
          id: 'v',
          createdAt: 2000, // newer => primary
          timestamp: DateTime.utc(2000), // earlier than the secondary's
          hashtags: ['tag'],
          collaboratorPubkeys: ['collab'],
          nostrEventTags: [
            ['e', 'x'],
          ],
          contentWarningLabels: ['nsfw'],
        ),
      );

      expect(merged.hashtags, equals(['tag']));
      expect(merged.collaboratorPubkeys, equals(['collab']));
      expect(
        merged.nostrEventTags,
        equals([
          ['e', 'x'],
        ]),
      );
      expect(merged.contentWarningLabels, equals(['nsfw']));
      // Neither has publishedAt => keep the earlier timestamp (primary's).
      expect(merged.timestamp, equals(DateTime.utc(2000)));
    });
  });

  group('mergeProfileFeedVideoLists', () {
    test('dedups the same addressable video and keeps distinct ones', () {
      final result = mergeProfileFeedVideoLists(
        [_video(id: 'a', createdAt: 1000, originalLikes: 3, publishedAt: '1')],
        [
          _video(id: 'a', createdAt: 1000, originalLikes: 9, publishedAt: '1'),
          _video(id: 'b', createdAt: 2000, publishedAt: '2'),
        ],
      );

      expect(result, hasLength(2));
      final a = result.firstWhere((v) => v.id == 'a');
      expect(a.originalLikes, equals(9)); // max merge applied
    });

    test('sorts newest-first by published time then ascending id', () {
      final result = mergeProfileFeedVideoLists(
        [_video(id: 'old', createdAt: 1000, publishedAt: '1000')],
        [_video(id: 'new', createdAt: 3000, publishedAt: '3000')],
      );

      expect(result.map((v) => v.id).toList(), equals(['new', 'old']));
    });

    test('falls back to createdAt and breaks sort ties by ascending id', () {
      final result = mergeProfileFeedVideoLists(
        [_video(id: 'bbb', createdAt: 1000)], // no publishedAt
        [_video(id: 'aaa', createdAt: 1000)], // no publishedAt, same createdAt
      );

      // createdAt sort key (equal) => tie broken by ascending id.
      expect(result.map((v) => v.id).toList(), equals(['aaa', 'bbb']));
    });
  });
}
