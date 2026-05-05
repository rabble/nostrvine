import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('NostrHexUtils', () {
    test('accepts valid 32-byte hex strings', () {
      expect(NostrHexUtils.isValidHex32('a' * 64), isTrue);
      expect(NostrHexUtils.isValidEventId('b' * 64), isTrue);
      expect(NostrHexUtils.isValidPubkey('C' * 64), isTrue);
    });

    test('rejects null, short, and non-hex strings', () {
      expect(NostrHexUtils.isValidHex32(null), isFalse);
      expect(NostrHexUtils.isValidHex32('a' * 63), isFalse);
      expect(NostrHexUtils.isValidEventId('bundled_sound_123'), isFalse);
      expect(NostrHexUtils.isValidPubkey('z' * 64), isFalse);
    });
  });
}
