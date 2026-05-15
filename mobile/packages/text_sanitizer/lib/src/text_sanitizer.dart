// ABOUTME: Sanitizes user-generated text for safe display in UI widgets.

/// Caps combining diacritical characters per grapheme cluster to prevent Zalgo
/// text from overflowing layout bounds.
///
/// Allows up to [maxCombining] combining chars per base character (default 2),
/// which covers all legitimate accented scripts including Vietnamese
/// (e.g. ổ = o + circumflex + hook = 2 combining chars). Zalgo text typically
/// stacks 10–50 combining chars per base character.
///
/// Safe for both NFC and NFD-encoded text: NFC precomposed characters (e.g.
/// U+00E9 é) contain no combining chars and pass through unchanged.
String stripZalgo(String text, {int maxCombining = 2}) {
  final safeText = _replaceLoneSurrogates(text);
  final result = StringBuffer();
  final runes = safeText.runes.toList();
  var i = 0;
  while (i < runes.length) {
    result.writeCharCode(runes[i]);
    i++;
    var kept = 0;
    while (i < runes.length && _isCombining(runes[i])) {
      if (kept < maxCombining) {
        result.writeCharCode(runes[i]);
        kept++;
      }
      i++;
    }
  }
  return result.toString();
}

String _replaceLoneSurrogates(String text) {
  final result = StringBuffer();
  final codeUnits = text.codeUnits;
  var i = 0;
  while (i < codeUnits.length) {
    final unit = codeUnits[i];
    if (_isHighSurrogate(unit)) {
      final hasPair =
          i + 1 < codeUnits.length && _isLowSurrogate(codeUnits[i + 1]);
      if (hasPair) {
        result.write(String.fromCharCodes([unit, codeUnits[i + 1]]));
        i += 2;
      } else {
        result.writeCharCode(0xFFFD);
        i++;
      }
    } else if (_isLowSurrogate(unit)) {
      result.writeCharCode(0xFFFD);
      i++;
    } else {
      result.writeCharCode(unit);
      i++;
    }
  }
  return result.toString();
}

bool _isHighSurrogate(int codeUnit) => codeUnit >= 0xD800 && codeUnit <= 0xDBFF;

bool _isLowSurrogate(int codeUnit) => codeUnit >= 0xDC00 && codeUnit <= 0xDFFF;

bool _isCombining(int cp) =>
    (cp >= 0x0300 && cp <= 0x036F) ||
    cp == 0x0489 ||
    (cp >= 0x1AB0 && cp <= 0x1AFF) ||
    (cp >= 0x1DC0 && cp <= 0x1DFF) ||
    (cp >= 0x20D0 && cp <= 0x20FF) ||
    (cp >= 0xFE20 && cp <= 0xFE2F);
