// ABOUTME: State for ConversationReactionsCubit.
// ABOUTME: Holds the per-message reaction lists and a per-(message,emoji)
// ABOUTME: publish-status map for optimistic / failed render.

part of 'conversation_reactions_cubit.dart';

/// Top-level lifecycle status of the cubit.
enum ConversationReactionsStatus { initial, loading, loaded, failure }

/// State of an outgoing reaction publish from this client's perspective.
/// Distinct from [DmReactionPublishStatus] which is the on-disk shape.
enum ReactionPublishLocalStatus { sending, failed }

/// Identity for an outgoing publish, used as the key in [pending] and
/// [ConversationReactionsState.optimistic].
@immutable
class ReactionPublishKey extends Equatable {
  /// Construct a publish key.
  const ReactionPublishKey({required this.messageId, required this.emoji});

  /// Rumor id of the message being reacted to.
  final String messageId;

  /// Reaction emoji codepoint.
  final String emoji;

  @override
  List<Object?> get props => [messageId, emoji];
}

/// A synchronous, client-side optimistic overlay applied on top of the
/// persisted reaction rows so the chip paints on the same frame as the tap —
/// before the local Drift round-trip (`insertOwnReactionSuperseding` → watch
/// re-emit, which crosses a background isolate + SQLCipher) settles the row.
/// Mirrors the in-player reel bar's `_optimisticEmoji` (#5389).
///
/// Each entry is reconciled away by [ConversationReactionsCubit] the moment
/// the persisted stream reflects the intent (an `Added` row appears / a
/// `Removed` row disappears).
sealed class OptimisticReactionIntent extends Equatable {
  const OptimisticReactionIntent();
}

/// The current account just added [reaction]; show its chip immediately.
class OptimisticReactionAdded extends OptimisticReactionIntent {
  /// Construct an optimistic-add intent carrying the synthetic chip row.
  const OptimisticReactionAdded(this.reaction);

  /// Synthetic placeholder row (`publishStatus: pending`) rendered until the
  /// persisted row arrives on the next stream tick.
  final DmReaction reaction;

  @override
  List<Object?> get props => [reaction];
}

/// The current account just removed their reaction for this `(message, emoji)`;
/// hide the own chip immediately.
class OptimisticReactionRemoved extends OptimisticReactionIntent {
  /// Construct an optimistic-remove intent.
  const OptimisticReactionRemoved();

  @override
  List<Object?> get props => [];
}

/// Snapshot of the cubit's reactive view.
@immutable
class ConversationReactionsState extends Equatable {
  /// Construct a state.
  const ConversationReactionsState({
    this.status = ConversationReactionsStatus.initial,
    this.reactionsByMessageId = const <String, List<DmReaction>>{},
    this.pending = const <ReactionPublishKey, ReactionPublishLocalStatus>{},
    this.optimistic = const <ReactionPublishKey, OptimisticReactionIntent>{},
  });

  /// Lifecycle status of the cubit.
  final ConversationReactionsStatus status;

  /// Live (non-deleted) reactions grouped by `target_message_id`, exactly as
  /// the DAO stream delivered them (the *persisted* truth). Empty when no
  /// reactions exist for a message. The cubit uses an empty outer map between
  /// initialization and the first stream tick. The render path reads
  /// [reactionsFor], which overlays [optimistic] on top of this.
  final Map<String, List<DmReaction>> reactionsByMessageId;

  /// In-flight publish state per (messageId, emoji). Cleared on the
  /// next stream tick after the publish lands and the DAO row carries
  /// the real status.
  final Map<ReactionPublishKey, ReactionPublishLocalStatus> pending;

  /// Synchronous optimistic overlay per (messageId, emoji), bridging the gap
  /// between a tap and the persisted row arriving on the DAO stream (#5389).
  /// Reconciled away by the cubit once the persisted set reflects the intent.
  final Map<ReactionPublishKey, OptimisticReactionIntent> optimistic;

  /// Live reactions for [messageId] as the chips should render them: the
  /// persisted rows with [optimistic] applied. Returns `const []` if none.
  ///
  /// Fast path: when no optimistic overlay touches [messageId], the persisted
  /// list is returned by reference, preserving identity for `identical`-based
  /// `buildWhen` guards. A merged copy is allocated only while an optimistic
  /// add/remove for this message is in flight.
  List<DmReaction> reactionsFor(String messageId) {
    final persisted = reactionsByMessageId[messageId] ?? const <DmReaction>[];
    if (optimistic.isEmpty) return persisted;
    final overlays = optimistic.entries
        .where((e) => e.key.messageId == messageId)
        .toList(growable: false);
    if (overlays.isEmpty) return persisted;
    final merged = List<DmReaction>.of(persisted);
    for (final entry in overlays) {
      final emoji = entry.key.emoji;
      switch (entry.value) {
        case OptimisticReactionAdded(:final reaction):
          final present = merged.any((r) => r.isOwn && r.emoji == emoji);
          if (!present) merged.add(reaction);
        case OptimisticReactionRemoved():
          merged.removeWhere((r) => r.isOwn && r.emoji == emoji);
      }
    }
    return merged;
  }

  /// Did the current account author a live reaction with [emoji] on
  /// the message [messageId]?
  bool ownReactionMatches({
    required String messageId,
    required String emoji,
    required String ownerPubkey,
  }) {
    final list = reactionsByMessageId[messageId];
    if (list == null) return false;
    for (final r in list) {
      if (r.reactorPubkey == ownerPubkey && r.emoji == emoji) {
        return true;
      }
    }
    return false;
  }

  /// Like [ownReactionMatches] but also honours the synchronous [optimistic]
  /// overlay via [reactionsFor], so a reaction that is added-but-not-yet-
  /// persisted counts as present. The double-tap-to-like guard uses this to
  /// avoid publishing a duplicate ❤️ when the user re-double-taps during the
  /// pre-persist window (the Drift round-trip crosses an isolate + SQLCipher).
  bool ownReactionPendingOrLive({
    required String messageId,
    required String emoji,
    required String ownerPubkey,
  }) {
    for (final r in reactionsFor(messageId)) {
      if (r.reactorPubkey == ownerPubkey && r.emoji == emoji) {
        return true;
      }
    }
    return false;
  }

  /// Copy with overrides. `null` is "no change" semantics; explicit
  /// empties are passed by the caller.
  ConversationReactionsState copyWith({
    ConversationReactionsStatus? status,
    Map<String, List<DmReaction>>? reactionsByMessageId,
    Map<ReactionPublishKey, ReactionPublishLocalStatus>? pending,
    Map<ReactionPublishKey, OptimisticReactionIntent>? optimistic,
  }) {
    return ConversationReactionsState(
      status: status ?? this.status,
      reactionsByMessageId: reactionsByMessageId ?? this.reactionsByMessageId,
      pending: pending ?? this.pending,
      optimistic: optimistic ?? this.optimistic,
    );
  }

  @override
  List<Object?> get props => [
    status,
    reactionsByMessageId,
    pending,
    optimistic,
  ];
}
