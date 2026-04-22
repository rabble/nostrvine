/// Immutable snapshot of all state the policy engine needs to evaluate.
///
/// Rebuilt by ContentBlocklistService whenever the underlying source
/// data changes. The engine never mutates it; it is replaced wholesale.
class ContentPolicyState {
  /// Creates a [ContentPolicyState] from the four source sets plus the
  /// currently authenticated user's pubkey (null when not authenticated).
  const ContentPolicyState({
    required this.currentUserPubkey,
    required this.mutedPubkeys,
    required this.blockedPubkeys,
    required this.pubkeysBlockingUs,
    required this.pubkeysMutingUs,
  });

  /// Empty state — used pre-hydration or when no user is authenticated.
  ///
  /// With an empty state, every rule short-circuits to Allow. This is
  /// the documented startup window; the bootstrap sequence is responsible
  /// for hydrating before any parse-gate call fires.
  factory ContentPolicyState.empty() => const ContentPolicyState(
    currentUserPubkey: null,
    mutedPubkeys: {},
    blockedPubkeys: {},
    pubkeysBlockingUs: {},
    pubkeysMutingUs: {},
  );

  /// The hex pubkey of the currently authenticated user, or null.
  final String? currentUserPubkey;

  /// Authors the user muted via their own kind 10000 event.
  final Set<String> mutedPubkeys;

  /// Authors the user blocked via their own kind 30000 d=block event.
  final Set<String> blockedPubkeys;

  /// Authors whose kind 30000 d=block event names the current user.
  final Set<String> pubkeysBlockingUs;

  /// Authors whose kind 10000 event names the current user.
  final Set<String> pubkeysMutingUs;

  /// True when content from [pubkey] must be filtered from feeds.
  bool isAuthorFiltered(String pubkey) =>
      mutedPubkeys.contains(pubkey) ||
      blockedPubkeys.contains(pubkey) ||
      pubkeysBlockingUs.contains(pubkey) ||
      pubkeysMutingUs.contains(pubkey);

  /// True when [pubkey] has a mute/block entry naming the current user.
  ///
  /// This is the query ContentPolicyEngine.canTarget uses — it answers
  /// "does the recipient want to hear from us?" without leaking the
  /// reason. Callers MUST NOT surface the return value as copy.
  bool isBlockedBy(String pubkey) =>
      pubkeysBlockingUs.contains(pubkey) || pubkeysMutingUs.contains(pubkey);
}
