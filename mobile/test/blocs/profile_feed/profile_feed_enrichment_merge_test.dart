// ABOUTME: Regression tests for app-layer profile feed enrichment merge.
// ABOUTME: Ensures Nostr-only metadata is not dropped when REST copies win.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_enrichment_merge.dart';
import 'package:videos_repository/videos_repository.dart';

VideoEvent _video({
  required String id,
  String pubkey = 'pubkey',
  String? vineId,
  String? textTrackRef,
  List<String> textTrackRefs = const [],
}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: 1704067200,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1704067200 * 1000),
    vineId: vineId,
    textTrackRef: textTrackRef,
    textTrackRefs: textTrackRefs,
  );
}

void main() {
  group('mergeProfileFeedEnrichment', () {
    test('fills plural text-track refs from enriched Nostr copy', () {
      final current = _video(id: 'rest', vineId: 'video-subtitles');
      final enriched = _video(
        id: 'nostr',
        vineId: 'video-subtitles',
        textTrackRef: 'https://media.divine.video/subtitle-vtt',
        textTrackRefs: const [
          'https://media.divine.video/subtitle-vtt',
          '39307:pubkey:subtitles:video-subtitles',
        ],
      );

      final merged = mergeProfileFeedEnrichment(
        current: [current],
        sourceKeys: {canonicalProfileFeedVideoKey(current)},
        incoming: [enriched],
        removeTombstones: (videos) => videos,
      );

      expect(merged, hasLength(1));
      expect(
        merged.single.textTrackRef,
        equals('https://media.divine.video/subtitle-vtt'),
      );
      expect(merged.single.textTrackRefs, [
        'https://media.divine.video/subtitle-vtt',
        '39307:pubkey:subtitles:video-subtitles',
      ]);
    });

    test('does not reintroduce source videos missing from current state', () {
      final staleSource = _video(id: 'old-rest', vineId: 'old-vine');
      final current = _video(id: 'new-rest', vineId: 'new-vine');
      final enriched = _video(
        id: 'old-nostr',
        vineId: 'old-vine',
        textTrackRef: 'https://media.divine.video/stale.vtt',
      );

      final merged = mergeProfileFeedEnrichment(
        current: [current],
        sourceKeys: {canonicalProfileFeedVideoKey(staleSource)},
        incoming: [enriched],
        removeTombstones: (videos) => videos,
      );

      expect(merged, [current]);
    });
  });
}
