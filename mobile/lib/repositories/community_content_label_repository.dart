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
  /// each resolve to a Divine identity. Returns an empty set when the relay
  /// query fails (graceful degradation — the video simply shows without the
  /// community warning; authoritative creator / trusted-labeler warnings are
  /// unaffected).
  Future<Set<String>> communityLabelsForVideo(VideoEvent video) async {
    final events = await _queryLabelEvents(video);
    if (events.isEmpty) return {};

    final authorsByLabel = <String, Set<String>>{};
    for (final event in events) {
      for (final value in _contentWarningValues(event)) {
        (authorsByLabel[value] ??= <String>{}).add(event.pubkey);
      }
    }
    if (authorsByLabel.isEmpty) return {};

    final divineByAuthor = await _resolveDivineAuthors(
      authorsByLabel.values.expand((authors) => authors).toSet(),
    );

    final surfaced = <String>{};
    for (final entry in authorsByLabel.entries) {
      final divineCount = entry.value
          .where((author) => divineByAuthor[author] == true)
          .length;
      if (divineCount >= CommunityContentWarningConstants.displayThreshold) {
        surfaced.add(entry.key);
      }
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
    final events = await _queryLabelEvents(video);
    final labels = <String>{...?_ownSuggestionsThisSession[video.id]};
    for (final event in events.where((event) => event.pubkey == myPubkey)) {
      labels.addAll(_contentWarningValues(event));
    }
    return labels;
  }

  Future<List<Event>> _queryLabelEvents(VideoEvent video) async {
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
      return [];
    }
  }

  Future<Map<String, bool>> _resolveDivineAuthors(Set<String> authors) async {
    final entries = await Future.wait(
      authors.map(
        (author) async => MapEntry(
          author,
          await _profileRepository.hasDivineIdentity(author),
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
