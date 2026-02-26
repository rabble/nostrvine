// ABOUTME: Search utility functions for fuzzy matching and relevance scoring
// ABOUTME: Provides tokenized search matching for user profiles and content

import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19.dart';

/// Priority multiplier for bio/about field matches (lower than name fields).
const double kBioSearchPriorityMultiplier = 0.5;

/// Result of a fuzzy search match with relevance score
class SearchMatch<T> {
  const SearchMatch({
    required this.item,
    required this.score,
    this.matchedField,
  });

  final T item;

  /// Score from 0.0 (no match) to 1.0 (exact match)
  final double score;

  /// Which field matched (for debugging/display)
  final String? matchedField;
}

/// Utility class for fuzzy search matching
class SearchUtils {
  /// Tokenize a string into searchable words.
  static List<String> tokenize(String input) {
    if (input.isEmpty) return [];

    // Split camelCase before lowercasing
    var normalized = input.replaceAllMapped(
      RegExp('([a-z])([A-Z])'),
      (match) => '${match.group(1)} ${match.group(2)}',
    );

    normalized = normalized.toLowerCase().replaceAll('_', ' ');

    return normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
  }

  /// Returns a score from 0.0 to 1.0 based on token matching.
  static double tokenMatch(String query, String target) {
    if (query.isEmpty || target.isEmpty) return 0.0;

    final queryTokens = tokenize(query);
    final targetTokens = tokenize(target);
    final targetLower = target.toLowerCase();

    if (queryTokens.isEmpty || targetTokens.isEmpty) return 0.0;

    if (targetLower == query.toLowerCase()) return 1.0;
    if (targetLower.startsWith(query.toLowerCase())) return 0.95;
    if (targetLower.contains(query.toLowerCase())) return 0.85;

    var matchedTokens = 0;
    for (final queryToken in queryTokens) {
      for (final targetToken in targetTokens) {
        if (targetToken.startsWith(queryToken)) {
          matchedTokens++;
          break;
        }
        if (targetToken.contains(queryToken)) {
          matchedTokens++;
          break;
        }
      }
    }

    if (matchedTokens == 0) return 0.0;

    return (matchedTokens / queryTokens.length) * 0.7;
  }

  /// Match a query against a user profile.
  static SearchMatch<UserProfile>? matchProfile(
    String query,
    UserProfile profile,
  ) {
    if (query.isEmpty) return null;

    final queryLower = query.toLowerCase().trim();
    var bestScore = 0.0;
    String? matchedField;

    if (profile.displayName != null && profile.displayName!.isNotEmpty) {
      final score = tokenMatch(queryLower, profile.displayName!);
      if (score > bestScore) {
        bestScore = score;
        matchedField = 'displayName';
      }
    }

    if (profile.name != null && profile.name!.isNotEmpty) {
      final score = tokenMatch(queryLower, profile.name!);
      if (score > bestScore) {
        bestScore = score;
        matchedField = 'name';
      }
    }

    if (profile.nip05 != null && profile.nip05!.isNotEmpty) {
      final nip05Lower = profile.nip05!.toLowerCase();
      var score = tokenMatch(queryLower, nip05Lower);

      final nip05Parts = profile.nip05!.split('@');
      final nip05Username = nip05Parts.first;
      if (nip05Username != '_') {
        final usernameScore = tokenMatch(queryLower, nip05Username);
        if (usernameScore > score) score = usernameScore;

        if (nip05Parts.length > 1) {
          final domainScore = tokenMatch(queryLower, nip05Parts[1]);
          if (domainScore > score) score = domainScore;
        }

        if (queryLower.contains('@')) {
          final fullMatchScore = tokenMatch(queryLower, nip05Lower);
          if (fullMatchScore > score) score = fullMatchScore;
        }
      }

      if (score > bestScore) {
        bestScore = score * 0.9;
        matchedField = 'nip05';
      }
    }

    // Search bio/about at lower priority than name fields
    if (profile.about != null && profile.about!.isNotEmpty) {
      final score =
          tokenMatch(queryLower, profile.about!) * kBioSearchPriorityMultiplier;
      if (score > bestScore) {
        bestScore = score;
        matchedField = 'about';
      }
    }

    if (queryLower.startsWith('npub')) {
      final npub = Nip19.encodePubKey(profile.pubkey).toLowerCase();
      if (npub.startsWith(queryLower)) {
        final score = queryLower.length / npub.length;
        if (score > bestScore) {
          bestScore = score;
          matchedField = 'npub';
        }
      }
    }

    if (bestScore > 0) {
      return SearchMatch(
        item: profile,
        score: bestScore,
        matchedField: matchedField,
      );
    }

    return null;
  }

  /// Search profiles with fuzzy matching, sorted by relevance.
  static List<UserProfile> searchProfiles(
    String query,
    Iterable<UserProfile> profiles, {
    double minScore = 0.3,
    int? limit,
  }) {
    if (query.trim().isEmpty) return [];

    final matches = <SearchMatch<UserProfile>>[];

    for (final profile in profiles) {
      final match = matchProfile(query, profile);
      if (match != null && match.score >= minScore) {
        matches.add(match);
      }
    }

    matches.sort((a, b) => b.score.compareTo(a.score));

    final results = matches.map((m) => m.item).toList();
    if (limit != null && results.length > limit) {
      return results.sublist(0, limit);
    }

    return results;
  }

  /// Returns a score for how well a video matches the query.
  static double matchVideo({
    required String query,
    String? title,
    String? content,
    List<String>? hashtags,
    String? creatorName,
  }) {
    if (query.isEmpty) return 0.0;

    final queryLower = query.toLowerCase().trim();
    var bestScore = 0.0;

    if (title != null && title.isNotEmpty) {
      final score = tokenMatch(queryLower, title);
      if (score > bestScore) bestScore = score;
    }

    if (hashtags != null) {
      for (final tag in hashtags) {
        final cleanQuery = queryLower.startsWith('#')
            ? queryLower.substring(1)
            : queryLower;
        final cleanTag = tag.toLowerCase();
        if (cleanTag == cleanQuery) {
          bestScore = 0.95;
          break;
        }
        if (cleanTag.startsWith(cleanQuery)) {
          if (0.85 > bestScore) bestScore = 0.85;
        }
        if (cleanTag.contains(cleanQuery)) {
          if (0.7 > bestScore) bestScore = 0.7;
        }
      }
    }

    if (content != null && content.isNotEmpty) {
      final score = tokenMatch(queryLower, content) * 0.8;
      if (score > bestScore) bestScore = score;
    }

    if (creatorName != null && creatorName.isNotEmpty) {
      final score = tokenMatch(queryLower, creatorName) * 0.6;
      if (score > bestScore) bestScore = score;
    }

    return bestScore;
  }
}
