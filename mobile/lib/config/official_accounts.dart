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

/// The pinned child-contactable set (verified live 2026-07-07). Additions are
/// release-gated by design — this is a child-contact list, and requiring an app
/// release to add a key is the accepted friction that makes the pin an
/// attacker-addition barrier. Each entry pins its OWN canonical identifier form
/// (HQ uses a subdomain origin, moderation the classic form).
const List<OfficialAccount> kPinnedOfficialAccounts = [
  OfficialAccount(
    pubkeyHex:
        'c4a39f1291291d452405cd8ddd798c4a29a3858c52cd0d843f1f6852cf17682e',
    nip05: '_@divinehq.divine.video',
    role: 'hq',
    minorContactable: true,
  ),
  OfficialAccount(
    pubkeyHex:
        '8fd5eb6d8f362163bc00a5ab6b4a3167dbf32d00ec4efdbcf43b3c9514433b7e',
    nip05: 'moderation@divine.video',
    role: 'moderation',
    minorContactable: true,
  ),
];
