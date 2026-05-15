// ABOUTME: Stable identifiers for the swallow sites in DmRepository.
// ABOUTME: Used as the `site:` annotation on DmRepositoryErrorReporter calls.

/// Stable site identifiers for the DAO-bookkeeping swallow points in
/// `DmRepository`. The wiring layer forwards each call to Crashlytics
/// with `reason: 'DmRepository.<site>'` so the dashboard aggregates per
/// site.
abstract class DmRepositoryReportableSites {
  /// `recoverSelfWrap`: `Event.fromJson(row.rumorEventJson)` threw.
  /// Programming-invariant violation — the repository wrote that JSON.
  static const String recoverSelfWrapRumorJsonParse =
      'recoverSelfWrap.rumorJsonParse';

  /// `recoverSelfWrap`: the salvage `markSelfWrapStatus(failed)` after
  /// a JSON parse failure also threw. Silent inner swallow today.
  static const String recoverSelfWrapMarkFailedAfterJsonParse =
      'recoverSelfWrap.markFailedAfterJsonParse';

  /// `recoverSelfWrap`: publish landed; `deleteById` threw. The
  /// fallback `markSelfWrapStatus(sent)` is attempted next.
  static const String recoverSelfWrapDeleteAfterPublish =
      'recoverSelfWrap.deleteAfterPublish';

  /// `recoverSelfWrap`: publish landed; both `deleteById` and the
  /// fallback `markSelfWrapStatus(sent)` threw. The doubly-degraded
  /// path — primary target of #4127.
  static const String recoverSelfWrapBookkeepingDoubleFailure =
      'recoverSelfWrap.bookkeepingDoubleFailure';

  /// `recoverSelfWrap`: publish failed; the salvage
  /// `markSelfWrapStatus(failed)` threw.
  static const String recoverSelfWrapMarkFailedAfterPublishFailure =
      'recoverSelfWrap.markFailedAfterPublishFailure';

  /// `_finalizeAfterRecipientFailure`: marking the queue row failed
  /// threw. Caller already has the publish-failure result.
  static const String finalizeAfterRecipientFailure =
      'finalizeAfterRecipientFailure';

  /// `sendMessage` outer transaction catch: persisting the local
  /// message row or running `_finalizeAfterRecipientSuccess` threw
  /// after the recipient publish landed.
  static const String sendMessageOuterTransaction =
      'sendMessage.outerTransaction';
}
