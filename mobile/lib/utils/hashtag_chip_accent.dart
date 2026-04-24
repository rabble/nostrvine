// ABOUTME: Accent background tints for hashtag UI (Popular Trending strip, tag menu # tile).

import 'dart:ui' show Color;

import 'package:divine_ui/divine_ui.dart';
import 'package:hashtag_repository/hashtag_repository.dart';

/// Round-robin list — same order as the former `_HashtagChip` in [TrendingHashtagsSection].
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

/// Stable pick for surfaces without a list order (e.g. hashtag more menu # tile).
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
