// ABOUTME: Regression tests pinning the VideoEvent.toJson contract.
// ABOUTME: Guarantees the JSON shape stays an explicit allow-list of declared
// ABOUTME: persisted fields — no computed getters, no hashCode, no time-
// ABOUTME: dependent values — so a future getter cannot silently leak into
// ABOUTME: caches or relay payloads. Issue: divinevideo/divine-mobile#3365.

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
  expirationTimestamp: 4102444800, // year 2100
  audioEventId: _audioEventId,
  audioEventRelay: 'wss://relay.divine.video',
  nostrLikeCount: 12,
  authorName: 'Test Author',
  authorAvatar: 'https://cdn.divine.video/avatar.jpg',
  collaboratorPubkeys: [_otherCollab],
  inspiredByVideo: const InspiredByInfo(
    addressableId: '34236:abc123:my-video',
    relayUrl: 'wss://relay.divine.video',
  ),
  inspiredByNpub: 'npub1examplenpubvalue',
  nostrEventTags: const [
    ['d', 'abc123def'],
    ['title', 'A short loop'],
  ],
  textTrackRef: 'https://cdn.divine.video/captions.vtt',
  textTrackContent: 'WEBVTT\n\n00:00.000 --> 00:06.000\nHello',
  contentWarningLabels: const ['nudity'],
  moderationLabels: const ['ml-noisy-label'],
  warnLabels: const ['nudity'],
);

const _expectedKeys = <String>{
  'id',
  'pubkey',
  'createdAt',
  'content',
  'title',
  'videoUrl',
  'thumbnailUrl',
  'duration',
  'dimensions',
  'mimeType',
  'sha256',
  'fileSize',
  'hashtags',
  'categories',
  'timestamp',
  'publishedAt',
  'rawTags',
  'vineId',
  'group',
  'altText',
  'blurhash',
  'isRepost',
  'reposterId',
  'reposterPubkey',
  'reposterPubkeys',
  'repostedAt',
  'isFlaggedContent',
  'moderationStatus',
  'originalLoops',
  'originalLikes',
  'originalComments',
  'originalReposts',
  'expirationTimestamp',
  'audioEventId',
  'audioEventRelay',
  'nostrLikeCount',
  'authorName',
  'authorAvatar',
  'collaboratorPubkeys',
  'inspiredByVideo',
  'inspiredByNpub',
  'textTrackRef',
  'textTrackContent',
  'contentWarningLabels',
};

const _excludedDerivedGetters = <String>{
  'hashCode',
  'isExpired',
  'stableId',
  'addressableId',
  'effectiveThumbnailUrl',
  'displayPubkey',
  'displayContent',
  'displayTitle',
  'allHashtags',
  'hasContentWarning',
  'shouldShowWarning',
  'hasSubtitles',
  'hasCollaborators',
  'hasInspiredBy',
  'inspiredByCreatorPubkey',
  'totalLikes',
  'totalLoops',
  'hasLoopMetadata',
  'hasAudioReference',
  'proofModeVerificationLevel',
  'proofModeManifest',
  'proofModeDeviceAttestation',
  'proofModePgpFingerprint',
  'proofModeC2paManifestId',
  'hasCreatorIdentityBinding',
  'identityVerifier',
  'hasPortableIdentity',
  'hasProofMode',
  'isVerifiedMobile',
  'isVerifiedWeb',
  'hasBasicProof',
  'isOriginalVine',
  'isVintageRecoveredVine',
  'isOriginalContent',
  'width',
  'height',
  'isPortrait',
  'fileSizeMB',
  'formattedDuration',
  'hasVideo',
  'isGif',
  'isMp4',
  'isWebM',
};

const _excludedInternalFields = <String>{
  'nostrEventTags',
  'moderationLabels',
  'warnLabels',
};

/// Adding a new persisted field to [VideoEvent] requires THREE coordinated
/// edits — default-deny is intentional, but the cost is on the contributor:
///   1. Add the `final` field + constructor parameter on [VideoEvent].
///   2. Add the field to [VideoEvent.toJson]'s map literal.
///   3. Add the field name to [_expectedKeys] below + populate it in
///      [_fullVideo].
///
/// Miss only #2 → the "contains exactly the persisted field set" test fails
/// loudly. Miss only #3 → the new field silently leaks through this guard.
void main() {
  group('VideoEvent.toJson', () {
    test('contains exactly the persisted field set', () {
      expect(_fullVideo().toJson().keys.toSet(), equals(_expectedKeys));
    });

    test('omits hashCode and time-dependent isExpired', () {
      final json = _fullVideo().toJson();
      expect(
        json.containsKey('hashCode'),
        isFalse,
        reason: 'hashCode is VM-specific and must never be serialized',
      );
      expect(
        json.containsKey('isExpired'),
        isFalse,
        reason: 'isExpired depends on DateTime.now() and is unstable',
      );
    });

    test('omits all derived getters', () {
      final json = _fullVideo().toJson();
      for (final getter in _excludedDerivedGetters) {
        expect(
          json.containsKey(getter),
          isFalse,
          reason: '$getter is a derived getter and must not be persisted',
        );
      }
    });

    test('omits internal fields kept only for republishing or UI state', () {
      final json = _fullVideo().toJson();
      for (final field in _excludedInternalFields) {
        expect(
          json.containsKey(field),
          isFalse,
          reason: '$field is internal model state, not part of the JSON shape',
        );
      }
    });

    test('produces identical output across calls', () {
      final video = _fullVideo();
      expect(video.toJson(), equals(video.toJson()));
    });

    test('serializes inspiredByVideo as a nested map, not a raw object', () {
      final json = _fullVideo().toJson();
      expect(json['inspiredByVideo'], isA<Map<String, dynamic>>());
      final nested = json['inspiredByVideo']! as Map<String, dynamic>;
      expect(nested['addressableId'], equals('34236:abc123:my-video'));
      expect(nested['relayUrl'], equals('wss://relay.divine.video'));
    });

    test('serializes timestamp and repostedAt as ISO 8601 strings', () {
      final json = _fullVideo().toJson();
      expect(json['timestamp'], isA<String>());
      expect(json['timestamp'], equals('2024-01-01T00:00:00.000Z'));
      expect(json['repostedAt'], isA<String>());
      expect(json['repostedAt'], equals('2024-01-01T00:01:00.000Z'));
    });

    test('survives jsonEncode round-trip', () {
      expect(() => jsonEncode(_fullVideo().toJson()), returnsNormally);
    });

    test(
      'serializes a null inspiredByVideo as a null value (key always present)',
      () {
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
        expect(_fullVideo().toJson().containsKey('inspiredByVideo'), isTrue);
        expect(minimal.toJson().containsKey('inspiredByVideo'), isTrue);
        expect(minimal.toJson()['inspiredByVideo'], isNull);
      },
    );
  });
}
