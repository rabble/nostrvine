import 'package:divine_blurhash/src/blurhash_exception.dart';

/// Base83 alphabet from the BlurHash spec.
const String base83Alphabet =
    '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    'abcdefghijklmnopqrstuvwxyz'
    r'#$%*+,-.:;=?@[]^_{|}~';

/// Reverse index of [base83Alphabet] for O(1) character lookup. Decoding
/// runs synchronously per hash, so a linear `indexOf` scan per character
/// would add up.
final Map<String, int> _reverseIndex = {
  for (var i = 0; i < base83Alphabet.length; i++) base83Alphabet[i]: i,
};

/// Decodes the base83 substring `value[from..to)` into an integer.
///
/// Throws [BlurHashDecodeException] on any character outside the base83
/// alphabet.
int decode83(String value, int from, int to) {
  var result = 0;
  for (var i = from; i < to; i++) {
    final digit = _reverseIndex[value[i]];
    if (digit == null) {
      throw BlurHashDecodeException(
        'invalid base83 character "${value[i]}" at index $i',
      );
    }
    result = result * 83 + digit;
  }
  return result;
}

/// Encodes [value] as a base83 string of exactly [length] characters.
String encode83(int value, int length) {
  final buffer = StringBuffer();
  for (var i = 1; i <= length; i++) {
    final digit = (value ~/ _pow83(length - i)) % 83;
    buffer.write(base83Alphabet[digit]);
  }
  return buffer.toString();
}

int _pow83(int exponent) {
  var result = 1;
  for (var i = 0; i < exponent; i++) {
    result *= 83;
  }
  return result;
}
