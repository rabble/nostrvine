import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/extensions/video_event_extensions.dart';

VideoEvent _videoWithUrl(String? url) {
  return VideoEvent(
    id: 'test-id',
    pubkey: 'test-pubkey',
    createdAt: 0,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    videoUrl: url,
  );
}

void main() {
  group('inlinePlayerVideoUrl', () {
    // A valid 64-char Divine video hash.
    const hash =
        'cfb5cf3415ec4ad3f45eff478570d898ff9a660ecea63d0c058892b22468a90d';

    test('passes a progressive Divine URL through unchanged', () {
      const url = 'https://media.divine.video/$hash/720p.mp4';
      expect(_videoWithUrl(url).inlinePlayerVideoUrl, url);
    });

    test('resolves a Divine raw blob to a progressive URL', () {
      expect(
        _videoWithUrl('https://media.divine.video/$hash').inlinePlayerVideoUrl,
        'https://media.divine.video/$hash/720p.mp4',
      );
    });

    test('passes a non-Divine progressive URL through unchanged', () {
      const url = 'https://example.com/clip.mp4';
      expect(_videoWithUrl(url).inlinePlayerVideoUrl, url);
    });

    test('resolves a Divine HLS manifest to a progressive URL', () {
      final resolved = _videoWithUrl(
        'https://media.divine.video/$hash/hls/master.m3u8',
      ).inlinePlayerVideoUrl;

      // The `<video>` element can't play HLS on older Chrome/Firefox, so the
      // HLS manifest must be resolved to a non-HLS Divine URL.
      expect(resolved, isNotNull);
      expect(resolved, isNot(contains('.m3u8')));
      expect(resolved, contains(hash));
    });

    test('returns null when there is no video URL', () {
      expect(_videoWithUrl(null).inlinePlayerVideoUrl, isNull);
    });
  });
}
