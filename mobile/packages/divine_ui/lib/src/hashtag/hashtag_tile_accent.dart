// ABOUTME: Stable accent backgrounds for hashtag surfaces (trending strip,
// menu # tile).

import 'dart:ui' show Color;

import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:hashtag_repository/hashtag_repository.dart';

/// Round-robin palette — same order as the original profile/trending chip treatment.
const List<Color> kHashtagTilePalette = <Color>[
  VineTheme.accentYellow,
  VineTheme.accentLime,
  VineTheme.accentPink,
  VineTheme.accentOrange,
  VineTheme.accentViolet,
  VineTheme.accentPurple,
  VineTheme.accentBlue,
];

int _intHashFromCodeUnits(Iterable<int> codeUnits) {
  var h = 0;
  for (final c in codeUnits) {
    h = 0x1fffffff & (h * 31 + c);
  }
  return h;
}

/// Stable pick for surfaces without list order (e.g. hashtag more-menu # tile).
Color hashtagTileBackgroundForLabel(String hashtag) {
  final n = kHashtagTilePalette.length;
  if (n == 0) return VineTheme.accentPurple;
  final key = normalizeHashtagLabel(hashtag);
  if (key.isEmpty) {
    return kHashtagTilePalette[0];
  }
  final h = _intHashFromCodeUnits(key.codeUnits);
  return kHashtagTilePalette[h % n];
}
