/// Normalize a Nostr `kind 0` `banner` field value into a canonical
/// `0xRRGGBB` hex string when it represents a color, or `null` when it
/// does not.
///
/// divine-mobile's color picker writes the `banner` field as a hex color
/// (e.g. `0x33ccbf`), while every other Nostr client writes a URL. This
/// function is the single source of truth for deciding whether a given
/// `banner` value is a color and, if so, what its canonical form is.
///
/// Accepts `0xRRGGBB`, `#RRGGBB`, or bare `RRGGBB`. Returns `null` for
/// URLs (anything starting with `http`), empty strings, and malformed
/// input (wrong length, non-hex characters).
///
/// Pure Dart by design: no `dart:ui` import, so it is safe to call from
/// the bloc / repository layers where Flutter SDK dependencies are not
/// allowed.
String? normalizeBannerHex(String? banner) {
  if (banner == null || banner.isEmpty) return null;
  var hex = banner;
  if (hex.startsWith('0x')) {
    hex = hex.substring(2);
  } else if (hex.startsWith('#')) {
    hex = hex.substring(1);
  } else if (hex.startsWith('http')) {
    return null;
  }
  if (hex.length != 6) return null;
  final value = int.tryParse(hex, radix: 16);
  if (value == null) return null;
  return '0x${value.toRadixString(16).padLeft(6, '0')}';
}
