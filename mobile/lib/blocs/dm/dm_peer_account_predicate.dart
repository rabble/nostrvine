// ABOUTME: The injected "is this peer one of ours" predicate shared by the DM
// ABOUTME: blocs. Pure and Flutter-free, so a cubit can take the policy without
// ABOUTME: importing another bloc to get at the type.

/// Answers whether [pubkeyHex] belongs to a particular class of account —
/// today the Divine moderation identities, current or retired.
///
/// Injected rather than imported so the DM layer never learns Divine's own
/// pubkeys: `official_accounts.dart` is app config, and the blocs that consume
/// this are reusable without it. Same reasoning as `DmSendPolicy` in
/// `dm_repository`, one layer up.
typedef DmPeerAccountPredicate = bool Function(String pubkeyHex);

/// The permissive default: no peer is special.
///
/// Every consumer defaults to this so a caller that has no policy to inject —
/// notably a test fixture — behaves exactly as it did before the policy
/// existed, rather than silently gaining a restriction.
bool neverDmPeerAccount(String _) => false;
