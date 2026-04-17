import 'package:flutter_test/flutter_test.dart';
import 'package:hls_auth_web_player/src/hls_auth_source_policy.dart';

void main() {
  group('sourceKindFor', () {
    test('returns hls for .m3u8 URLs', () {
      expect(
        sourceKindFor('https://media.divine.video/abc/hls/master.m3u8'),
        equals(HlsAuthWebSourceKind.hls),
      );
    });

    test('returns hls when the path ends in .m3u8 and has a query string', () {
      expect(
        sourceKindFor('https://media.divine.video/abc/hls/master.m3u8?token=x'),
        equals(HlsAuthWebSourceKind.hls),
      );
    });

    test('returns mp4 for direct .mp4 URLs', () {
      expect(
        sourceKindFor('https://media.divine.video/abc.mp4'),
        equals(HlsAuthWebSourceKind.mp4),
      );
    });

    test('returns mp4 for URLs with no extension', () {
      expect(
        sourceKindFor('https://media.divine.video/abc'),
        equals(HlsAuthWebSourceKind.mp4),
      );
    });

    test('is case-insensitive on the extension', () {
      expect(
        sourceKindFor('https://media.divine.video/abc/master.M3U8'),
        equals(HlsAuthWebSourceKind.hls),
      );
    });
  });
}
