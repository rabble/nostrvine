import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('parseImetaTag', () {
    Map<String, List<String>> parse(List<String> tag) {
      final values = <String, List<String>>{};
      parseImetaTag(tag, (key, value) {
        values.putIfAbsent(key, () => []).add(value);
      });
      return values;
    }

    test('parses space-separated fields', () {
      expect(
        parse([
          'imeta',
          'url https://media.divine.video/video.mp4',
          'm video/mp4',
          'dim 720x1280',
        ]),
        equals({
          'url': ['https://media.divine.video/video.mp4'],
          'm': ['video/mp4'],
          'dim': ['720x1280'],
        }),
      );
    });

    test('parses positional key-value fields', () {
      expect(
        parse([
          'imeta',
          'url',
          'https://media.divine.video/video.mp4',
          'm',
          'video/mp4',
          'dim',
          '720x1280',
        ]),
        equals({
          'url': ['https://media.divine.video/video.mp4'],
          'm': ['video/mp4'],
          'dim': ['720x1280'],
        }),
      );
    });

    test('ignores empty and one-element tags', () {
      expect(parse([]), isEmpty);
      expect(parse(['imeta']), isEmpty);
    });

    test('ignores odd trailing positional key without value', () {
      expect(
        parse(['imeta', 'url', 'https://media.divine.video/video.mp4', 'dim']),
        equals({
          'url': ['https://media.divine.video/video.mp4'],
        }),
      );
    });

    test('preserves values containing spaces', () {
      expect(
        parse([
          'imeta',
          'url https://media.divine.video/video.mp4',
          'alt A caption with spaces',
          'summary A longer summary with spaces',
        ]),
        equals({
          'url': ['https://media.divine.video/video.mp4'],
          'alt': ['A caption with spaces'],
          'summary': ['A longer summary with spaces'],
        }),
      );
    });
  });
}
