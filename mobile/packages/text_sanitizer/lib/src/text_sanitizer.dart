// ABOUTME: Sanitizes user-generated text for safe display in UI widgets.

/// Replaces unpaired UTF-16 surrogates with U+FFFD, while preserving valid
/// surrogate pairs such as emoji.
///
/// Dart strings can contain unpaired surrogate code units when they originate
/// from escaped JSON or external event data. Flutter text layout assumes valid
/// UTF-16 and may crash while shaping those strings, so display boundaries
/// should normalize them before handing text to widgets.
String sanitizeUtf16(String text) {
  final units = text.codeUnits;
  StringBuffer? result;

  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    final isHighSurrogate = unit >= 0xD800 && unit <= 0xDBFF;
    final isLowSurrogate = unit >= 0xDC00 && unit <= 0xDFFF;

    if (isHighSurrogate &&
        i + 1 < units.length &&
        units[i + 1] >= 0xDC00 &&
        units[i + 1] <= 0xDFFF) {
      if (result != null) {
        result
          ..writeCharCode(unit)
          ..writeCharCode(units[i + 1]);
      }
      i++;
      continue;
    }

    if (isHighSurrogate || isLowSurrogate) {
      result ??= StringBuffer()..write(text.substring(0, i));
      result.writeCharCode(0xFFFD);
      continue;
    }

    result?.writeCharCode(unit);
  }

  return result?.toString() ?? text;
}

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
  final sanitizedText = sanitizeUtf16(text);
  final result = StringBuffer();
  final runes = sanitizedText.runes.toList();
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

bool _isCombining(int cp) =>
    (cp >= 0x0300 && cp <= 0x036F) ||
    cp == 0x0489 ||
    (cp >= 0x1AB0 && cp <= 0x1AFF) ||
    (cp >= 0x1DC0 && cp <= 0x1DFF) ||
    (cp >= 0x20D0 && cp <= 0x20FF) ||
    (cp >= 0xFE20 && cp <= 0xFE2F);
