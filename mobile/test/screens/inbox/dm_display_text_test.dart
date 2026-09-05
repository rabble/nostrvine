import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/inbox/dm_display_text.dart';

void main() {
  group(sliceDmDisplayText, () {
    test('returns the original text when it is within the budget', () {
      final slice = sliceDmDisplayText('hello', 5);

      expect(slice.text, 'hello');
      expect(slice.hasMore, isFalse);
    });

    test('bounds an oversized message and reports the hidden suffix', () {
      final slice = sliceDmDisplayText('abcdefgh', 4);

      expect(slice.text, 'abcd');
      expect(slice.hasMore, isTrue);
    });

    test('does not split a valid surrogate pair at the boundary', () {
      final slice = sliceDmDisplayText('abc😀tail', 4);

      expect(slice.text, 'abc');
      expect(slice.hasMore, isTrue);
    });

    test('preserves malformed surrogates for the sanitizer to repair', () {
      final malformed = 'abc${String.fromCharCode(0xD83D)}tail';
      final slice = sliceDmDisplayText(malformed, 4);

      expect(slice.text.length, 4);
      expect(slice.text.codeUnitAt(3), 0xD83D);
      expect(slice.hasMore, isTrue);
    });
  });
}
