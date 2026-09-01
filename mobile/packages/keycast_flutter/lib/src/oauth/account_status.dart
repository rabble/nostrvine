// ABOUTME: Parsed GET /api/user/account response from Keycast, including the
// ABOUTME: durable approved-minor flag (verified_minor, keycast#263).

/// Account status returned by Keycast's `GET /api/user/account`.
///
/// [verifiedMinor] is the durable approved-minor (13-15) flag and is always
/// present; [verifiedMinorAt] is set only when the account was flagged.
class KeycastAccountStatus {
  const KeycastAccountStatus({
    required this.email,
    required this.emailVerified,
    required this.publicKey,
    required this.verifiedMinor,
    this.accountStatus,
    this.suspendedReason,
    this.verifiedMinorAt,
  });

  factory KeycastAccountStatus.fromJson(Map<String, dynamic> json) {
    final verifiedMinorAtRaw = json['verified_minor_at'] as String?;
    return KeycastAccountStatus(
      email: json['email'] as String? ?? '',
      emailVerified: json['email_verified'] as bool? ?? false,
      publicKey: json['public_key'] as String? ?? '',
      accountStatus: json['account_status'] as String?,
      suspendedReason: json['suspended_reason'] as String?,
      verifiedMinor: json['verified_minor'] as bool? ?? false,
      verifiedMinorAt: verifiedMinorAtRaw == null
          ? null
          : DateTime.tryParse(verifiedMinorAtRaw),
    );
  }

  final String email;
  final bool emailVerified;
  final String publicKey;

  /// Present only when the account is not active (suspended/banned/etc.).
  final String? accountStatus;

  /// Keycast's stored reason for a non-active status. **Deliberately not
  /// consumed anywhere, and not safe to render to the user.**
  ///
  /// It is neither a sentence nor reviewed copy. Keycast's admin API accepts
  /// arbitrary caller-supplied text (sanitised for control characters and
  /// truncated, but not validated against any set), while Divine's only
  /// production writer constrains it to four internal tags — `moderation`,
  /// `age_review`, `age_review_denied`, `age_review_expired`. So the field is
  /// untrusted by contract and, in practice, an untranslated snake_case token.
  ///
  /// It is also not the enforcement authority: divine-mobile reads account
  /// status from Funnelcake, not from here. Parsed only so this model matches
  /// the whole `GET /api/user/account` payload.
  ///
  /// Whether a user-facing reason should exist at all is open in #8304; if it
  /// lands, it will be a new field with reviewed copy, not this one.
  final String? suspendedReason;

  /// Durable approved-minor (13-15) flag. Independent of [accountStatus] —
  /// an approved minor is active, so this can be true on a normal account.
  final bool verifiedMinor;
  final DateTime? verifiedMinorAt;
}
