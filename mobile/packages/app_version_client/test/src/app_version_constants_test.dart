import 'package:app_version_client/app_version_client.dart';
import 'package:test/test.dart';

void main() {
  group(AppVersionConstants, () {
    group('minimumVersionPattern', () {
      test('matches standard comment', () {
        const body = '<!-- minimum_version: 1.0.6 -->';
        final match = AppVersionConstants.minimumVersionPattern.firstMatch(
          body,
        );
        expect(match?.group(1), equals('1.0.6'));
      });

      test('matches with extra whitespace', () {
        const body = '<!--   minimum_version:   1.2.3   -->';
        final match = AppVersionConstants.minimumVersionPattern.firstMatch(
          body,
        );
        expect(match?.group(1), equals('1.2.3'));
      });

      test('returns null when not present', () {
        const body = '# Just a release\nSome text.';
        final match = AppVersionConstants.minimumVersionPattern.firstMatch(
          body,
        );
        expect(match, isNull);
      });
    });

    group('highlightPattern', () {
      test('extracts bold items from bullet points', () {
        const body =
            '- **Resumable uploads** — survives bad signal\n'
            '- **Double-tap to like** — you know the move\n'
            '- Regular item without bold\n'
            '* **Asterisk bullet** — also works\n';
        final highlights = AppVersionConstants.highlightPattern
            .allMatches(body)
            .map((m) => m.group(1)!.trim())
            .toList();
        expect(
          highlights,
          equals([
            'Resumable uploads',
            'Double-tap to like',
            'Asterisk bullet',
          ]),
        );
      });

      test('returns empty for plain text body', () {
        const body = 'No highlights here, just plain text.';
        final highlights = AppVersionConstants.highlightPattern
            .allMatches(body)
            .toList();
        expect(highlights, isEmpty);
      });
    });
  });
}
