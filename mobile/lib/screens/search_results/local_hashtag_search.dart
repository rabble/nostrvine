// TODO(oscar): Move fallback logic into HashtagRepository
// https://github.com/divinevideo/divine-mobile/issues/2535

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/top_hashtags_service.dart';

/// Searches local hashtag sources as a fallback when the remote API is
/// unavailable.
///
/// This function is a temporary bridge: it uses Riverpod [ref] to access
/// the legacy [hashtagServiceProvider] and [TopHashtagsService]. It will be
/// replaced by repository-level fallback logic in #2535.
Future<List<String>> searchLocalHashtags(
  WidgetRef ref,
  String query, {
  int limit = 20,
}) async {
  final normalizedQuery = query.trim().replaceFirst('#', '').toLowerCase();
  if (normalizedQuery.isEmpty) return const [];

  final results = <String>[];
  final seen = <String>{};

  void addResults(Iterable<String> hashtags) {
    for (final hashtag in hashtags) {
      final normalizedTag = hashtag.replaceFirst('#', '').trim();
      final key = normalizedTag.toLowerCase();
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      results.add(normalizedTag);
      if (results.length >= limit) return;
    }
  }

  try {
    addResults(
      ref.read(hashtagServiceProvider).searchHashtags(normalizedQuery),
    );
  } catch (_) {
    // Ignore local feed lookup failures and continue with static hashtags.
  }

  if (results.length >= limit) return results;

  try {
    await TopHashtagsService.instance.loadTopHashtags();
    addResults(
      TopHashtagsService.instance.searchHashtags(
        normalizedQuery,
        limit: limit,
      ),
    );
  } catch (_) {
    // Ignore asset lookup failures — remote results have already failed.
  }

  return results;
}
