// ABOUTME: Unit tests for resolveDmVideoTarget and DmVideoTarget.
// ABOUTME: Covers legacy Divine URL and structured NIP-18 q-reference resolution.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/screens/inbox/conversation/dm_video_target.dart';

void main() {
  const author =
      '1122334411223344112233441122334411223344112233441122334411223344';
  const eventId =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';

  group('resolveDmVideoTarget', () {
    test('resolves a canonical Divine URL', () {
      final target = resolveDmVideoTarget(
        content: 'watch https://divine.video/video/skate-loop',
      );

      expect(target, isNotNull);
      expect(target!.stableId, 'skate-loop');
      expect(target.authorPubkey, isNull);
      expect(target.videoKind, isNull);
      expect(target.fallbackRouteIds, isEmpty);
      expect(
        target.canonicalUrl,
        'https://divine.video/video/skate-loop',
      );
    });

    test('resolves a regular-event structured reference', () {
      final target = resolveDmVideoTarget(
        content: 'watch this',
        sharedVideoRef: const DmSharedVideoRef(
          coordinateOrId: eventId,
          videoKind: DmSharedVideoKind.shortVideo,
          authorPubkey: author,
        ),
      );

      expect(target, isNotNull);
      expect(target!.stableId, eventId);
      expect(target.authorPubkey, author);
      expect(target.videoKind, 22);
      expect(target.fallbackRouteIds, ['22:$author:$eventId']);
      expect(
        target.canonicalUrl,
        'https://divine.video/video/$eventId',
      );
    });

    test('resolves an addressable structured reference', () {
      final target = resolveDmVideoTarget(
        content: 'watch this',
        sharedVideoRef: const DmSharedVideoRef(
          coordinateOrId: '34236:$author:skate-loop',
          videoKind: DmSharedVideoKind.addressableShortVideo,
        ),
      );

      expect(target, isNotNull);
      expect(target!.stableId, 'skate-loop');
      expect(target.authorPubkey, author);
      expect(target.videoKind, 34236);
      expect(target.fallbackRouteIds, ['34236:$author:skate-loop']);
      expect(
        target.canonicalUrl,
        'https://divine.video/video/skate-loop',
      );
    });

    test(
      'prefers the URL identity and retains structured routing metadata',
      () {
        final target = resolveDmVideoTarget(
          content: 'https://divine.video/video/url-stable-id',
          sharedVideoRef: const DmSharedVideoRef(
            coordinateOrId: '34236:$author:structured-stable-id',
            videoKind: DmSharedVideoKind.addressableShortVideo,
          ),
        );

        expect(target, isNotNull);
        expect(target!.stableId, 'url-stable-id');
        expect(target.authorPubkey, author);
        expect(target.videoKind, 34236);
        expect(target.fallbackRouteIds, ['34236:$author:url-stable-id']);
      },
    );

    test('rejects a malformed addressable reference without a URL', () {
      final target = resolveDmVideoTarget(
        content: 'watch this',
        sharedVideoRef: const DmSharedVideoRef(
          coordinateOrId: '34236:$author',
          videoKind: DmSharedVideoKind.addressableShortVideo,
        ),
      );

      expect(target, isNull);
    });

    test('falls back to a URL when the structured reference is malformed', () {
      final target = resolveDmVideoTarget(
        content: 'https://divine.video/video/url-stable-id',
        sharedVideoRef: const DmSharedVideoRef(
          coordinateOrId: '34236:$author',
          videoKind: DmSharedVideoKind.addressableShortVideo,
        ),
      );

      expect(target, isNotNull);
      expect(target!.stableId, 'url-stable-id');
      expect(target.authorPubkey, isNull);
      expect(target.videoKind, isNull);
      expect(target.fallbackRouteIds, isEmpty);
    });
  });
}
