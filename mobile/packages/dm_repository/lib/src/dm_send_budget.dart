// ABOUTME: Time budget for a single NIP-17 message send, as linked constants.
// ABOUTME: The publish backstop is derived from these, never hand-computed.

/// The time budget for one NIP-17 1:1 message send, expressed as its parts.
///
/// ## Why this exists
///
/// The send-level backstop used to be a hand-computed number written into a
/// doc comment. #6046 derived it from a Keycast per-RPC bound of 12s; #6075
/// raised that bound to 30s without re-deriving the backstop, and the comment
/// kept asserting the 12s arithmetic long after it was false (#6586). The cap
/// ended up *smaller* than the work it bounds, so it fired on sends that had
/// already been delivered.
///
/// Every sub-bound now lives here and the totals are computed from the same
/// private seconds constants, so the derivation cannot silently go stale
/// again. A guard test in the app layer (which can see both this package and
/// `keycast_flutter`) pins the relationship against the real transport bound.
///
/// The totals are built from `int` seconds rather than by adding [Duration]s
/// because `Duration.operator+` is not `const` — summing durations would force
/// these off `const` and let a hand-typed total creep back in.
///
/// ## The shape being bounded
///
/// A 1:1 send has two remote-signer shapes, and these bounds must cover the
/// slower one:
///
/// * **Four round trips** — `nip44Encrypt` (seal content) + `signEvent` (seal),
///   once for the recipient wrap and again for the self wrap, which is built
///   lazily after the recipient publish confirms. Measured against the real
///   send path (#6586).
/// * **One round trip** — keycast's `nip17_wrap_batch` builds both seals and
///   both wraps server-side from one shared rumor (#7090). The self wrap comes
///   back with the recipient wrap, so [selfWrapBuild] is not spent at all.
///
/// The kind-1059 gift wrap itself is signed with a freshly generated ephemeral
/// key (NIP-59), so it never reaches the signer. Local-key signers build both
/// wraps in one isolate hop and spend no round trips at all — these bounds sit
/// far above that path and never bind it.
///
/// **Re-derived against the batch chain.** The four-trip shape is still
/// reachable — Amber, NIP-46, a keycast without the verb, a kind-7/5 rumor the
/// verb refuses, or a per-recipient slot failure all take it — so it remains
/// part of the bound. The batch attempt is serial with that fallback, though:
/// if `nip17_wrap_batch` stalls to its transport timeout and then the old
/// per-wrap path runs, both have to fit inside [recipientWrapBuild].
abstract final class DmSendBudget {
  /// The two seal round trips a wrap build spends, at the transport's own
  /// per-op bound (`KeycastRpc.defaultRequestTimeout`, 20s).
  ///
  /// Restated here because `dm_repository` cannot import `keycast_flutter`.
  /// The app-layer guard test asserts the real relationship, so this going
  /// stale fails CI rather than silently under-sizing the bound — which is the
  /// #6586 failure mode itself.
  static const int _twoTransportBoundsSeconds = 40;

  /// One server-side wrap-batch transport bound
  /// (`KeycastRpc.defaultBatchRequestTimeout`, 30s).
  ///
  /// Restated here for the same reason as [_twoTransportBoundsSeconds]. The
  /// app-layer guard test asserts this against the real Keycast constant.
  static const int _serverWrapBatchBoundSeconds = 30;

  /// Margin inside a wrap-build bound for the local work that runs alongside
  /// the two remote round trips: seal construction, the ephemeral keypair,
  /// the NIP-44 ECDH + ChaCha20 encryption of the seal, and the wrap's
  /// secp256k1 signature (`GiftWrapUtil.getGiftWrapEvent`).
  ///
  /// Without it the bound would sit at *exactly* two transport bounds, so two
  /// ops that each returned just under 20s would still blow it — failing a
  /// build the transport itself had completed. That is the same
  /// "sized at the worst case with no margin" shape #6586 was about, one step
  /// earlier in the chain.
  static const int _wrapBuildLocalCryptoSeconds = 5;

  /// What a wrap build costs against a signer that bounds its own operations,
  /// i.e. Keycast: two transport bounds plus the local crypto between them.
  ///
  /// This is the **floor** under [_recipientWrapBuildSeconds], not its value.
  /// Sizing the build bound below it would fail requests the transport itself
  /// would have allowed — the #6046 mistake #6075 had to revert — and the
  /// app-layer guard test pins that it stays a floor.
  static const int _boundedSignerFloorSeconds =
      _twoTransportBoundsSeconds + _wrapBuildLocalCryptoSeconds;

  /// Minimum per-wrap build budget for signers that bound their own
  /// operations. Exposed so the app layer can pin it to Keycast's real bound.
  static const Duration boundedSignerFloor = Duration(
    seconds: _boundedSignerFloorSeconds,
  );

  /// Seconds allowed for building the recipient gift wrap. See
  /// [recipientWrapBuild].
  static const int _recipientWrapBuildSeconds =
      _serverWrapBatchBoundSeconds + _boundedSignerFloorSeconds;

  /// Seconds allowed for the recipient OK confirmation. See
  /// [recipientOkConfirm].
  static const int _recipientOkConfirmSeconds = 10;

  /// Seconds allowed for building the self-addressed gift wrap. See
  /// [selfWrapBuild].
  static const int _selfWrapBuildSeconds = 20;

  /// Seconds allowed for publishing the self-addressed gift wrap. See
  /// [selfWrapPublish].
  static const int _selfWrapPublishSeconds = 10;

  /// Slack between [chainWorstCase] and [messagePublishTimeout].
  ///
  /// Absorbs event-loop scheduling, isolate hops, and the DAO work interleaved
  /// with the publish. The backstop must sit strictly above the capped worst
  /// case or it fires mid-send and misclassifies it — the #6586 defect.
  ///
  /// Kept as explicit slack, so `OutgoingDmRetryService.interruptedMinAge`
  /// follows this derived timeout instead of restating its own number.
  static const int _headroomSeconds = 15;

  /// Hard bound on building the recipient gift wrap.
  ///
  /// Sized as one Keycast server-side wrap-batch attempt at the transport's own
  /// 30s bound (`KeycastRpc.defaultBatchRequestTimeout`) **plus** the fallback
  /// build: two Keycast single-op round trips at the transport's own 20s bound
  /// (`KeycastRpc.defaultRequestTimeout`) **plus**
  /// [_wrapBuildLocalCryptoSeconds] for the local crypto that runs between and
  /// after them.
  ///
  /// The batch fast path does not consume all of this when it succeeds. The
  /// additive case is when it times out or throws transiently, then the caller
  /// falls through to the per-wrap path inside the same [recipientWrapBuild]
  /// timeout. Sizing only either alternative would let a slow-but-recoverable
  /// send be misclassified as timed out before any publish.
  ///
  /// [_boundedSignerFloorSeconds] is the fallback floor. Tightening below it is
  /// the specific mistake #6046 made and #6075 reverted. The batch attempt is
  /// serial with that fallback, so [recipientWrapBuild] must cover their sum.
  ///
  /// It bounds the *chain*, not the transport, and the chain's slowest signer
  /// sets its size. On the Amber NIP-55 intent path the `nip44Encrypt` and
  /// `signEvent` approval waits are
  /// human-gated and unbounded; timing out here leaves the recipient publish
  /// unsent, so durable callers classify the row as retryable-pending rather
  /// than red-failed.
  static const Duration recipientWrapBuild = Duration(
    seconds: _recipientWrapBuildSeconds,
  );

  /// OK-confirmation window for the recipient wrap.
  ///
  /// Read by `NIP17MessageService._recipientOkConfirmTimeout`.
  static const Duration recipientOkConfirm = Duration(
    seconds: _recipientOkConfirmSeconds,
  );

  /// Hard bound on building the self-addressed gift wrap.
  ///
  /// Deliberately tighter than [recipientWrapBuild]. By the time this runs the
  /// recipient already has the message, and a missing self-wrap is an
  /// explicitly supported outcome: the send returns success with
  /// `selfWrapPublished: false`, the durable row survives, and the retry
  /// sweep's `recoverSelfWrap` arm finishes it out of band (#4124). Spending
  /// the recipient-sized budget here to avoid a *recovery step* would be the
  /// wrong trade — it would push the send past the backstop and misclassify a
  /// delivered message as unconfirmed, which is the #6586 failure itself.
  ///
  /// Applies only when the caller has an outer cap. Uncapped callers use
  /// [selfWrapUncappedBuild], which is sized differently for the reason
  /// documented there.
  static const Duration selfWrapBuild = Duration(
    seconds: _selfWrapBuildSeconds,
  );

  /// Hard bound on building the self-addressed gift wrap when the caller has no
  /// outer cap.
  ///
  /// Sized like [recipientWrapBuild], not like [selfWrapBuild]. The tightness
  /// of [selfWrapBuild] buys headroom inside [messagePublishTimeout]; uncapped
  /// callers have no outer budget to protect, so there a tight bound can only
  /// fail a build the transport itself would have completed.
  ///
  /// This covers out-of-band recovery (`NIP17MessageService.publishSelfWrap`,
  /// driven by `DmRepository.recoverSelfWrap`) and
  /// `NIP17MessageService.publishSelfApplicationMarker`. The build is the same
  /// two round trips, so at [selfWrapBuild] it could never finish against a
  /// signer running near its own 20s-per-op bound.
  ///
  /// It deliberately does **not** cover `sendPrivateMessage`, which builds its
  /// self wrap uncapped. A bound only makes sense where a timed-out build can
  /// still be finished later; that caller owns no `outgoing_dms` row, which
  /// `DmRepository.recoverSelfWrap` requires, so for it even this wide bound
  /// would drop the sender's cross-device copy permanently.
  ///
  /// Deliberately NOT part of [chainWorstCase]: callers that use this bound do
  /// not use the send-level [messagePublishTimeout] chain budget.
  static const Duration selfWrapUncappedBuild = Duration(
    seconds: _recipientWrapBuildSeconds,
  );

  /// Hard bound on publishing the self-addressed gift wrap.
  ///
  /// Read by `NIP17MessageService._selfWrapPublishTimeout`.
  static const Duration selfWrapPublish = Duration(
    seconds: _selfWrapPublishSeconds,
  );

  /// Serial worst case for the bounded portion of a send.
  ///
  /// Every step above runs in sequence on the remote-signer path, so the worst
  /// case is their sum.
  static const Duration chainWorstCase = Duration(
    seconds:
        _recipientWrapBuildSeconds +
        _recipientOkConfirmSeconds +
        _selfWrapBuildSeconds +
        _selfWrapPublishSeconds,
  );

  /// Hard backstop on a single NIP-17 message publish.
  ///
  /// Derived, never hand-written. Callers that need to outlive an in-flight
  /// send must key off this rather than restating a number — see
  /// `OutgoingDmRetryService.interruptedMinAge`.
  static const Duration messagePublishTimeout = Duration(
    seconds:
        _recipientWrapBuildSeconds +
        _recipientOkConfirmSeconds +
        _selfWrapBuildSeconds +
        _selfWrapPublishSeconds +
        _headroomSeconds,
  );
}
