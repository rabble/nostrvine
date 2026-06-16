// ABOUTME: Round-trip tests for VideoEvent.fromJson (inverse of toJson).
// ABOUTME: Guarantees a cached feed snapshot rehydrates with the same
// ABOUTME: persisted field values it was serialized from.

import 'dart:convert';

import 'package:models/models.dart';
import 'package:test/test.dart';

final String _id = 'a' * 64;
final String _pubkey = 'b' * 64;
final String _reposterId = '1' * 64;
final String _reposterPubkey = 'c' * 64;
final String _otherCollab = 'd' * 64;
final String _audioEventId = 'e' * 64;
final String _sha256 = 'f' * 64;

VideoEvent _fullVideo() => VideoEvent(
  id: _id,
  pubkey: _pubkey,
  createdAt: 1704067200,
  content: 'hello vine',
  timestamp: DateTime.fromMillisecondsSinceEpoch(
    1704067200 * 1000,
    isUtc: true,
  ),
  title: 'A short loop',
  videoUrl: 'https://cdn.divine.video/video.mp4',
  thumbnailUrl: 'https://cdn.divine.video/thumb.jpg',
  duration: 6,
  dimensions: '720x1280',
  mimeType: 'video/mp4',
  sha256: _sha256,
  fileSize: 4096,
  hashtags: const ['vine', 'test'],
  categories: const ['music'],
  publishedAt: '1704067200',
  rawTags: const {'platform': 'vine', 'views': '42'},
  vineId: 'abc123def',
  group: 'community',
  altText: 'A person waves at the camera',
  blurhash: 'LKO2?U%2Tw=w',
  isRepost: true,
  reposterId: _reposterId,
  reposterPubkey: _reposterPubkey,
  reposterPubkeys: [_reposterPubkey],
  repostedAt: DateTime.fromMillisecondsSinceEpoch(
    1704067260 * 1000,
    isUtc: true,
  ),
  isFlaggedContent: true,
  moderationStatus: 'approved',
  originalLoops: 13565,
  originalLikes: 732,
  originalComments: 24,
  originalReposts: 9,
  expirationTimestamp: 4102444800,
  audioEventId: _audioEventId,
  audioEventRelay: 'wss://relay.divine.video',
  nostrLikeCount: 12,
  nostrCommentCount: 3,
  nostrRepostCount: 2,
  authorName: 'Test Author',
  authorAvatar: 'https://cdn.divine.video/avatar.jpg',
  collaboratorPubkeys: [_otherCollab],
  inspiredByVideo: const InspiredByInfo(
    addressableId: '34236:abc123:my-video',
    relayUrl: 'wss://relay.divine.video',
  ),
  inspiredByNpub: 'npub1examplenpubvalue',
  textTrackRef: 'https://cdn.divine.video/captions.vtt',
  textTrackContent: 'WEBVTT\n\n00:00.000 --> 00:06.000\nHello',
  contentWarningLabels: const ['nudity'],
  moderationLabels: const ['violence'],
  proofSummary: ProofVerificationSummary(
    status: 'present',
    level: 'basic_proof',
    checkedAt: DateTime.fromMillisecondsSinceEpoch(
      1779494400 * 1000,
      isUtc: true,
    ),
    version: 1,
    checks: const {'proofmode_present': true},
  ),
);

void main() {
  group('VideoEvent.fromJson', () {
    test('restores every persisted scalar field from toJson', () {
      final original = _fullVideo();
      final restored = VideoEvent.fromJson(original.toJson());

      expect(restored.id, equals(original.id));
      expect(restored.pubkey, equals(original.pubkey));
      expect(restored.createdAt, equals(original.createdAt));
      expect(restored.content, equals(original.content));
      expect(restored.timestamp, equals(original.timestamp));
      expect(restored.title, equals(original.title));
      expect(restored.videoUrl, equals(original.videoUrl));
      expect(restored.thumbnailUrl, equals(original.thumbnailUrl));
      expect(restored.duration, equals(original.duration));
      expect(restored.dimensions, equals(original.dimensions));
      expect(restored.mimeType, equals(original.mimeType));
      expect(restored.sha256, equals(original.sha256));
      expect(restored.fileSize, equals(original.fileSize));
      expect(restored.publishedAt, equals(original.publishedAt));
      expect(restored.vineId, equals(original.vineId));
      expect(restored.group, equals(original.group));
      expect(restored.altText, equals(original.altText));
      expect(restored.blurhash, equals(original.blurhash));
      expect(restored.isRepost, equals(original.isRepost));
      expect(restored.reposterId, equals(original.reposterId));
      expect(restored.reposterPubkey, equals(original.reposterPubkey));
      expect(restored.repostedAt, equals(original.repostedAt));
      expect(restored.isFlaggedContent, equals(original.isFlaggedContent));
      expect(restored.moderationStatus, equals(original.moderationStatus));
      expect(restored.originalLoops, equals(original.originalLoops));
      expect(restored.originalLikes, equals(original.originalLikes));
      expect(restored.originalComments, equals(original.originalComments));
      expect(restored.originalReposts, equals(original.originalReposts));
      expect(
        restored.expirationTimestamp,
        equals(original.expirationTimestamp),
      );
      expect(restored.audioEventId, equals(original.audioEventId));
      expect(restored.audioEventRelay, equals(original.audioEventRelay));
      expect(restored.nostrLikeCount, equals(original.nostrLikeCount));
      expect(restored.nostrCommentCount, equals(original.nostrCommentCount));
      expect(restored.nostrRepostCount, equals(original.nostrRepostCount));
      expect(restored.authorName, equals(original.authorName));
      expect(restored.authorAvatar, equals(original.authorAvatar));
      expect(restored.inspiredByNpub, equals(original.inspiredByNpub));
      expect(restored.textTrackRef, equals(original.textTrackRef));
      expect(restored.textTrackContent, equals(original.textTrackContent));
    });

    test('restores list and map fields', () {
      final restored = VideoEvent.fromJson(_fullVideo().toJson());

      expect(restored.hashtags, equals(['vine', 'test']));
      expect(restored.categories, equals(['music']));
      expect(restored.reposterPubkeys, equals([_reposterPubkey]));
      expect(restored.collaboratorPubkeys, equals([_otherCollab]));
      expect(restored.contentWarningLabels, equals(['nudity']));
      expect(restored.moderationLabels, equals(['violence']));
      expect(restored.rawTags, equals({'platform': 'vine', 'views': '42'}));
    });

    test('restores nested inspiredByVideo and proofSummary', () {
      final restored = VideoEvent.fromJson(_fullVideo().toJson());

      expect(restored.inspiredByVideo, isNotNull);
      expect(
        restored.inspiredByVideo!.addressableId,
        equals('34236:abc123:my-video'),
      );
      expect(
        restored.inspiredByVideo!.relayUrl,
        equals('wss://relay.divine.video'),
      );

      expect(restored.proofSummary, isNotNull);
      expect(restored.proofSummary!.status, equals('present'));
      expect(restored.proofSummary!.level, equals('basic_proof'));
      expect(restored.proofSummary!.version, equals(1));
      expect(restored.proofSummary!.checks['proofmode_present'], isTrue);
    });

    test('survives a jsonEncode/jsonDecode round-trip', () {
      final original = _fullVideo();
      final encoded = jsonEncode(original.toJson());
      final restored = VideoEvent.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(restored.id, equals(original.id));
      expect(restored.videoUrl, equals(original.videoUrl));
      expect(restored.timestamp, equals(original.timestamp));
      expect(restored.originalLoops, equals(original.originalLoops));
    });

    test('restores a minimal video with null optionals', () {
      final minimal = VideoEvent(
        id: _id,
        pubkey: _pubkey,
        createdAt: 1704067200,
        content: '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          1704067200 * 1000,
          isUtc: true,
        ),
      );
      final restored = VideoEvent.fromJson(minimal.toJson());

      expect(restored.id, equals(_id));
      expect(restored.videoUrl, isNull);
      expect(restored.inspiredByVideo, isNull);
      expect(restored.proofSummary, isNull);
      expect(restored.reposterPubkeys, isNull);
      expect(restored.hashtags, isEmpty);
      expect(restored.moderationLabels, isEmpty);
      expect(restored.rawTags, isEmpty);
      expect(restored.isRepost, isFalse);
    });
  });
}
