// ABOUTME: Events for ConversationReactionsCubit.

part of 'conversation_reactions_cubit.dart';

/// Base class for events handled by the reactions cubit. Despite the
/// class name carrying `Cubit`, we use Bloc-style event dispatch so the
/// optimistic-publish flow can use Bloc's event transformers (sequential
/// to prevent duplicate-publish races on rapid taps).
sealed class ConversationReactionsEvent extends Equatable {
  const ConversationReactionsEvent();

  @override
  List<Object?> get props => [];
}

/// Start watching reactions for [conversationId]. Idempotent — calling
/// again with the same id is a no-op.
class ConversationReactionsStarted extends ConversationReactionsEvent {
  /// Construct a started event.
  const ConversationReactionsStarted({required this.conversationId});

  /// Deterministic conversation id (matches `DmMessage.conversationId`).
  final String conversationId;

  @override
  List<Object?> get props => [conversationId];
}

/// Toggle a reaction on a message. If the current account already has a
/// matching live reaction, this dispatch removes it; otherwise publishes
/// a new one. Cap-at-one supersede is enforced by the repository.
class ConversationReactionToggled extends ConversationReactionsEvent {
  /// Construct a toggle event.
  const ConversationReactionToggled({
    required this.conversationId,
    required this.messageId,
    required this.messageAuthorPubkey,
    required this.emoji,
  });

  /// Conversation context for the optimistic insert.
  final String conversationId;

  /// Rumor id of the message being reacted to.
  final String messageId;

  /// Author of the target message — receiver of the reaction wrap.
  final String messageAuthorPubkey;

  /// Reaction emoji codepoint (or NIP-30 shortcode).
  final String emoji;

  @override
  List<Object?> get props => [
    conversationId,
    messageId,
    messageAuthorPubkey,
    emoji,
  ];
}

/// Set a reaction on a message (set-not-toggle semantics).
///
/// Unlike [ConversationReactionToggled], re-selecting the active emoji is a
/// **no-op** (it does NOT remove the reaction); selecting a different emoji
/// supersedes the prior one (cap-at-one, enforced by the repository). Used by
/// the in-player quick-reaction bar where tapping the active emoji should keep
/// it rather than clear it.
class ConversationReactionSet extends ConversationReactionsEvent {
  /// Construct a set event.
  const ConversationReactionSet({
    required this.conversationId,
    required this.messageId,
    required this.messageAuthorPubkey,
    required this.emoji,
  });

  /// Conversation context for the optimistic insert.
  final String conversationId;

  /// Rumor id of the message being reacted to.
  final String messageId;

  /// Author of the target message — receiver of the reaction wrap.
  final String messageAuthorPubkey;

  /// Reaction emoji codepoint (or NIP-30 shortcode).
  final String emoji;

  @override
  List<Object?> get props => [
    conversationId,
    messageId,
    messageAuthorPubkey,
    emoji,
  ];
}

/// Retry a previously-failed reaction publish.
class ConversationReactionRetryRequested extends ConversationReactionsEvent {
  /// Construct a retry event.
  const ConversationReactionRetryRequested({
    required this.rumorId,
    required this.messageId,
    required this.messageAuthorPubkey,
    required this.emoji,
  });

  /// Reaction rumor id (placeholder collapsed to real id at insert time).
  final String rumorId;

  /// Target message id (used to key the pending map).
  final String messageId;

  /// Target message author (recipient of the wrap).
  final String messageAuthorPubkey;

  /// Reaction emoji (used to key the pending map).
  final String emoji;

  @override
  List<Object?> get props => [
    rumorId,
    messageId,
    messageAuthorPubkey,
    emoji,
  ];
}

/// Internal — projected from the DAO stream subscription.
class _ConversationReactionsSubscriptionTicked
    extends ConversationReactionsEvent {
  const _ConversationReactionsSubscriptionTicked(this.reactions);

  final List<DmReaction> reactions;

  @override
  List<Object?> get props => [reactions];
}
