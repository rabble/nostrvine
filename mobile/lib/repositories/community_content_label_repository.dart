// ABOUTME: Aggregates and publishes community NIP-32 content-warning labels.
// ABOUTME: Counts distinct Divine-identity authors per label for #4771.

import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event, EventKind, Filter;
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/community_content_warning_constants.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// Thrown when publishing a community content-warning suggestion fails.
class CommunityLabelPublishException implements Exception {
  /// Creates the exception with an optional [message].
  const CommunityLabelPublishException([this.message]);

  /// Human-readable context for logs (never surfaced directly to the UI).
  final String? message;

  @override
  String toString() =>
      'CommunityLabelPublishException: ${message ?? 'publish failed'}';
}

/// Thrown when the community-label aggregation could not complete because of a
/// transient failure (the relay query failed, or an undetermined identity
/// lookup could have changed the outcome).
///
/// Distinct from a genuine empty result: callers use it to avoid caching a
/// degraded "no warnings" answer, so the next attempt retries.
class CommunityLabelUnavailableException implements Exception {
  /// Creates the exception with an optional [message].
  const CommunityLabelUnavailableException([this.message]);

  /// Human-readable context for logs (never surfaced directly to the UI).
  final String? message;

  @override
  String toString() =>
      'CommunityLabelUnavailableException: ${message ?? 'aggregation degraded'}';
}

/// Repository for viewer-suggested (community) content-warning labels.
///
/// Reads all-author NIP-32 (kind 1985) labels targeting a video, counts the
/// distinct **Divine-identity** authors per label, and surfaces labels that
/// cross [CommunityContentWarningConstants.displayThreshold]. Also publishes a
/// viewer's own suggestion.
///
/// This is a client-side, advisory signal only. Authoritative aggregation and
/// auto-application are separate backend work under epic #5177.
class CommunityContentLabelRepository {
  /// Creates the repository.
  CommunityContentLabelRepository({
    required NostrClient nostrClient,
    required ProfileRepository profileRepository,
  }) : _nostrClient = nostrClient,
       _profileRepository = profileRepository;

  final NostrClient _nostrClient;
  final ProfileRepository _profileRepository;

  /// Labels this session successfully published, keyed by video event id.
  /// The relay's read model lags writes by a few seconds, so a reopened
  /// sheet would otherwise not see a suggestion the user just made (and
  /// could double-submit it). Session-scoped; the relay is authoritative
  /// across restarts.
  final Map<String, Set<String>> _ownSuggestionsThisSession = {};

  /// Content-warning labels the community has surfaced for [video].
  ///
  /// Returns the set of normalized label values suggested by at least
  /// [CommunityContentWarningConstants.displayThreshold] distinct authors that
  /// each resolve to a Divine identity.
  ///
  /// Throws [CommunityLabelUnavailableException] when the result could not be
  /// determined — the relay query failed, or an undetermined identity lookup
  /// could have tipped an otherwise-empty result over the threshold. Callers
  /// use that to avoid caching a degraded "no warnings" answer. A genuine
  /// empty (successful query, nothing crossed) returns an empty set.
  Future<Set<String>> communityLabelsForVideo(VideoEvent video) async {
    final events = await _queryLabelEvents(video);
    if (events == null) {
      throw const CommunityLabelUnavailableException('relay query failed');
    }
    if (events.isEmpty) return {};

    final authorsByLabel = <String, Set<String>>{};
    for (final event in events) {
      for (final value in _contentWarningValues(event)) {
        (authorsByLabel[value] ??= <String>{}).add(event.pubkey);
      }
    }

    const threshold = CommunityContentWarningConstants.displayThreshold;

    // A label below the threshold on raw author count can never cross it
    // after Divine-identity filtering, so skip those authors' name-server
    // lookups entirely.
    final candidateLabels = <String, Set<String>>{
      for (final entry in authorsByLabel.entries)
        if (entry.value.length >= threshold) entry.key: entry.value,
    };
    if (candidateLabels.isEmpty) return {};

    final divineByAuthor = await _resolveDivineAuthors(
      candidateLabels.values.expand((authors) => authors).toSet(),
    );

    final surfaced = <String>{};
    var couldHaveCrossed = false;
    for (final entry in candidateLabels.entries) {
      final confirmed = entry.value
          .where((author) => divineByAuthor[author] == true)
          .length;
      if (confirmed >= threshold) {
        surfaced.add(entry.key);
        continue;
      }
      final undetermined = entry.value
          .where((author) => divineByAuthor[author] == null)
          .length;
      // The undetermined authors could be Divine and tip this label over.
      if (confirmed + undetermined >= threshold) couldHaveCrossed = true;
    }

    // Only signal degradation when the uncertainty actually matters: nothing
    // surfaced, but a label might have crossed had the failed lookups
    // resolved. A non-empty result already blurs the video, so caching it is
    // correct even if a secondary label stayed uncertain.
    if (surfaced.isEmpty && couldHaveCrossed) {
      throw const CommunityLabelUnavailableException('identity lookup failed');
    }
    return surfaced;
  }

  /// Publishes a kind 1985 content-warning suggestion for [video].
  ///
  /// Throws [ArgumentError] if [labels] is empty and
  /// [CommunityLabelPublishException] if the relay publish does not succeed.
  Future<void> suggestLabels({
    required VideoEvent video,
    required Set<ContentLabel> labels,
  }) async {
    if (labels.isEmpty) {
      throw ArgumentError.value(labels, 'labels', 'must not be empty');
    }

    // Targets are the VIDEO (`e` + `a`) only. We deliberately do NOT add a
    // `p` target: per NIP-32 a `p` label targets the *pubkey*, which would
    // publish a signed, account-level content-warning claim about the creator
    // derived from a single video (a reputation-affecting assertion other
    // labelers ingest). The video-scoped targets carry all the intent needed.
    final addressableId = video.addressableId;
    final tags = <List<String>>[
      ['L', CommunityContentWarningConstants.namespace],
      for (final label in labels)
        ['l', label.value, CommunityContentWarningConstants.namespace],
      ['e', video.id],
      if (addressableId != null && addressableId.isNotEmpty)
        ['a', addressableId],
    ];

    final event = Event(
      _nostrClient.publicKey,
      EventKind.label,
      tags,
      '',
    );
    final result = await _nostrClient.publishEvent(event);
    if (result is! PublishSuccess) {
      throw CommunityLabelPublishException(result.runtimeType.toString());
    }
    (_ownSuggestionsThisSession[video.id] ??= <String>{}).addAll(
      labels.map((label) => label.value),
    );
  }

  /// Content-warning labels [myPubkey] has already suggested for [video].
  ///
  /// Used to show an "already suggested" state. Returns an empty set on query
  /// failure.
  Future<Set<String>> mySuggestedLabels(
    VideoEvent video,
    String myPubkey,
  ) async {
    // A relay failure here degrades to the session-remembered suggestions
    // only, rather than throwing — the "already suggested" hint is advisory.
    final events = await _queryLabelEvents(video) ?? const <Event>[];
    final labels = <String>{...?_ownSuggestionsThisSession[video.id]};
    for (final event in events.where((event) => event.pubkey == myPubkey)) {
      labels.addAll(_contentWarningValues(event));
    }
    return labels;
  }

  /// Queries the video's kind 1985 label events, deduped by id. Returns `null`
  /// when the relay query fails (distinct from a successful empty result).
  Future<List<Event>?> _queryLabelEvents(VideoEvent video) async {
    try {
      final addressableId = video.addressableId;
      final filters = <Filter>[
        Filter(kinds: [EventKind.label], e: [video.id]),
        if (addressableId != null && addressableId.isNotEmpty)
          Filter(kinds: [EventKind.label], a: [addressableId]),
      ];
      final events = await _nostrClient.queryEvents(filters);
      final seen = <String>{};
      return events.where((event) => seen.add(event.id)).toList();
    } on Exception catch (e) {
      Log.warning(
        'community label query failed: $e',
        name: 'CommunityContentLabelRepository',
        category: LogCategory.api,
      );
      return null;
    }
  }

  /// Resolves each author to `true` (Divine), `false` (not), or `null`
  /// (undetermined — a transient lookup failure). The `null` verdicts let the
  /// caller decide whether the uncertainty changes the outcome.
  Future<Map<String, bool?>> _resolveDivineAuthors(Set<String> authors) async {
    final entries = await Future.wait(
      authors.map(
        (author) async => MapEntry(
          author,
          await _profileRepository.resolveDivineIdentity(author),
        ),
      ),
    );
    return Map.fromEntries(entries);
  }

  Iterable<String> _contentWarningValues(Event event) sync* {
    for (final tag in event.tags) {
      if (tag.length >= 3 &&
          tag[0] == 'l' &&
          tag[2] == CommunityContentWarningConstants.namespace) {
        // Constrain community-surfaced warnings to the known ContentLabel set.
        // The suggest UI only offers those, and this stops a few authors from
        // surfacing an arbitrary free-text string as a "community" warning.
        final label = ContentLabel.fromValue(tag[1]);
        if (label != null) yield label.value;
      }
    }
  }
}
