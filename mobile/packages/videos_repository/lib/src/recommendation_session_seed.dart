// ABOUTME: Session seed generation for backend recommendation ordering.
// ABOUTME: Produces opaque, non-sensitive values for per-session freshness.

import 'dart:math';

final Random _recommendationSessionSeedRandom = Random();
int _recommendationSessionSeedSequence = 0;

/// Generates an opaque seed for a recommendation session.
///
/// The seed is not security-sensitive; it only lets Funnelcake vary For You
/// ordering between sessions while keeping cursor pagination stable within a
/// session.
String generateRecommendationSessionSeed() {
  final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
  final sequence = (_recommendationSessionSeedSequence++).toRadixString(16);
  final random = _recommendationSessionSeedRandom
      .nextInt(0x100000000)
      .toRadixString(16)
      .padLeft(8, '0');
  return '$timestamp-$sequence-$random';
}
