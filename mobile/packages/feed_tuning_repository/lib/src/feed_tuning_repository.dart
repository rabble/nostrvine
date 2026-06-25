import 'package:feed_tuning_repository/src/feed_tuning_direction.dart';
import 'package:feed_tuning_repository/src/feed_tuning_reportable_sites.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

/// Reports an unexpected (invariant-violating) error to Crashlytics.
///
/// Wired in the app layer to `CrashReportingService.instance.recordError`.
/// Expected failures (no signer, relay/network errors) are NOT reported.
typedef FeedTuningErrorReporter =
    void Function(Object error, StackTrace stackTrace, {required String site});

/// Tag names used by the feed-tuning event contract.
@visibleForTesting
abstract class FeedTuningTags {
  /// The `direction` tag name carrying `"more"` or `"less"`.
  static const String direction = 'direction';
}

/// Canonical Divine relay hint used when the source video does not carry one.
@visibleForTesting
const feedTuningDefaultRelayHint = 'wss://relay.divine.video';

/// Publishes Divine feed-tuning signals — "more like this" / "less like this"
/// swipes — as append-only [EventKind.feedTuning] events, and retracts them
/// via NIP-09 deletions.
///
/// The signal is public, latest-wins, and read only by funnelcake/Gorse. It is
/// deliberately separate from the social Like (NIP-25 reaction) and is never a
/// moderation/block signal.
class FeedTuningRepository {
  /// Creates a repository that publishes via [nostrClient]. [errorReporter],
  /// when provided, receives only invariant-violating failures.
  FeedTuningRepository({
    required NostrClient nostrClient,
    FeedTuningErrorReporter? errorReporter,
  }) : _nostrClient = nostrClient,
       _report = errorReporter;

  final NostrClient _nostrClient;
  final FeedTuningErrorReporter? _report;

  /// Publishes a feed-tuning signal for [video] in the given [direction].
  ///
  /// Fire-and-forget: relay failures are swallowed (expected on flaky
  /// networks). Returns the published event id — known synchronously at
  /// construction — or `null` when there is no signer and nothing was
  /// attempted.
  Future<String?> tune({
    required VideoEvent video,
    required FeedTuningDirection direction,
  }) async {
    final event = _build(
      kind: EventKind.feedTuning,
      tags: _tuneTags(video, direction),
      site: FeedTuningReportableSites.tune,
    );
    if (event == null) return null;
    await _publish(event);
    return event.id;
  }

  /// Retracts a previously-published feed-tuning event via a NIP-09 (kind-5)
  /// deletion referencing [feedTuningEventId]. No-op without a signer.
  Future<void> undo(String feedTuningEventId) async {
    final event = _build(
      kind: EventKind.eventDeletion,
      tags: [
        ['e', feedTuningEventId],
        ['k', '${EventKind.feedTuning}'],
      ],
      site: FeedTuningReportableSites.undo,
    );
    if (event == null) return;
    await _publish(event);
  }

  Event? _build({
    required int kind,
    required List<List<String>> tags,
    required String site,
  }) {
    final String pubkey;
    try {
      pubkey = _nostrClient.publicKey;
    } on Object {
      // No signer / no public key yet — expected during cold start or signed
      // out. Nothing to publish, nothing to report.
      return null;
    }
    if (pubkey.isEmpty) return null;

    try {
      return Event(pubkey, kind, tags, '');
    } on Object catch (error, stackTrace) {
      _report?.call(error, stackTrace, site: site);
      return null;
    }
  }

  Future<void> _publish(Event event) async {
    try {
      await _nostrClient.publishEvent(event);
    } on Object {
      // Relay/network publish failures are expected; surfaced via UX, not
      // Crashlytics. The append-only event is latest-wins, so a dropped
      // publish self-heals on the next swipe.
    }
  }

  List<List<String>> _tuneTags(
    VideoEvent video,
    FeedTuningDirection direction,
  ) {
    final kind = video.eventKind ?? EventKind.videoVertical;
    final tags = <List<String>>[
      [FeedTuningTags.direction, direction.tagValue],
      _eTag(video),
    ];

    final aTag = _aTag(video, kind);
    if (aTag != null) tags.add(aTag);

    tags.add(['p', video.pubkey]);
    for (final hashtag in video.hashtags) {
      tags.add(['t', hashtag]);
    }
    tags.add(['k', '$kind']);
    return tags;
  }

  List<String> _eTag(VideoEvent video) {
    return ['e', video.id, _relayHint(video)];
  }

  /// The addressable coordinate, only when the source video carried a real `d`
  /// tag. [VideoEvent.vineId] falls back to the event id when there is no `d`
  /// tag, which would fabricate a coordinate — so gate on the raw tag instead.
  List<String>? _aTag(VideoEvent video, int kind) {
    if (!video.rawTags.containsKey('d')) return null;
    final dTag = video.vineId;
    if (dTag == null || dTag.isEmpty) return null;

    final coordinate = '$kind:${video.pubkey}:$dTag';
    return ['a', coordinate, _relayHint(video)];
  }

  String _relayHint(VideoEvent video) {
    final relay = video.sourceRelay;
    return relay == null || relay.isEmpty ? feedTuningDefaultRelayHint : relay;
  }
}
