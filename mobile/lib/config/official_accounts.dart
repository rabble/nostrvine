// ABOUTME: Pinned set of official Divine accounts a protected minor (13-15) may
// ABOUTME: DM (#176). The pin blocks attacker ADDITION (no key the app didn't ship
// ABOUTME: can join); the NIP-05 leg is the revocation lever (see OfficialAccountsService).

/// One pinned official account. `pubkeyHex` is the shipped identity; `nip05` is
/// the canonical identifier whose live resolution must still map back to
/// `pubkeyHex` for the account to count as reachable (revocation lever).
class OfficialAccount {
  final String pubkeyHex;
  final String nip05;
  final String role;

  /// Whether a protected minor may exchange DMs with this account. A pinned
  /// account that is not `minorContactable` is still official but off-limits to
  /// minors (leaves room for the #178 parent-approved-allowlist shape).
  final bool minorContactable;

  const OfficialAccount({
    required this.pubkeyHex,
    required this.nip05,
    required this.role,
    required this.minorContactable,
  });
}

/// Values [OfficialAccount.role] can take. Named so no caller has to spell the
/// role as a bare string to pick an account out of [kPinnedOfficialAccounts].
abstract class OfficialAccountRole {
  static const String hq = 'hq';
  static const String moderation = 'moderation';
}

/// Divine HQ's pinned identity.
const OfficialAccount kHqAccount = OfficialAccount(
  pubkeyHex: 'c4a39f1291291d452405cd8ddd798c4a29a3858c52cd0d843f1f6852cf17682e',
  nip05: '_@divinehq.divine.video',
  role: OfficialAccountRole.hq,
  minorContactable: true,
);

/// The current Divine moderation pubkey — the report target, the pinned support
/// row's destination, and `ModerationLabelService`'s NIP-05 fallback.
///
/// Single-sourced here rather than re-declared per consumer: the pinned support
/// row and the protected-minor gate must anchor on the SAME key, or the row can
/// point somewhere the gate would not approve.
const String kModerationPubkeyHex =
    '8fd5eb6d8f362163bc00a5ab6b4a3167dbf32d00ec4efdbcf43b3c9514433b7e';

/// Canonical NIP-05 identifier for [kModerationPubkeyHex]. Live resolution must
/// still map back to that pubkey for the account to count as reachable.
const String kModerationNip05 = 'moderation@divine.video';

/// The Divine moderation account's pinned identity.
const OfficialAccount kModerationAccount = OfficialAccount(
  pubkeyHex: kModerationPubkeyHex,
  nip05: kModerationNip05,
  role: OfficialAccountRole.moderation,
  minorContactable: true,
);

/// The pinned child-contactable set (verified live 2026-07-07). Additions are
/// release-gated by design — this is a child-contact list, and requiring an app
/// release to add a key is the accepted friction that makes the pin an
/// attacker-addition barrier. Each entry pins its OWN canonical identifier form
/// (HQ uses a subdomain origin, moderation the classic form).
const List<OfficialAccount> kPinnedOfficialAccounts = [
  kHqAccount,
  kModerationAccount,
];

/// Moderation pubkeys the account has rotated away from.
///
/// A DM thread opened before a rotation stays keyed on the old pubkey. Those
/// threads are deliberately NOT folded into the pinned support row: the row
/// routes on its own participants all the way to `sendMessage`, so adopting one
/// would address replies to a key nobody reads. They stay where they are and
/// render as ordinary rows, keeping their enforcement history reachable until
/// #6416 gives it an archived read-only presentation.
///
/// Never a send target — messages always go to the current pin above. Used for
/// recognising the account ([isModerationAccount], which drives the bundled
/// avatar) and for the `ModerationLabelService` subscription migration.
///
/// `121b915b…` was retired in #2321 (2026-03-20); `ModerationLabelService`
/// carries the matching one-time migration for labeler subscriptions.
const List<String> kLegacyModerationPubkeys = [
  '121b915baba659cbe59626a8afaf83b01dc42354dfecaad9d465d51bb5715d72',
];

/// Whether [pubkeyHex] is the Divine moderation account, current or retired.
///
/// Retired keys count: a thread opened before a rotation stays keyed on the
/// old pubkey, and it is the same team on the other end of it. Callers that
/// need a *send target* must use [kModerationPubkeyHex] instead — this answers
/// "is this the moderation team", not "where do replies go".
bool isModerationAccount(String pubkeyHex) =>
    pubkeyHex == kModerationPubkeyHex ||
    kLegacyModerationPubkeys.contains(pubkeyHex);
