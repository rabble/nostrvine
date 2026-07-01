// ABOUTME: Non-blocking protected-minor (13-15) state derived from Keycast's
// ABOUTME: verified_minor flag. Distinct from the blocking minor-review gate.

import 'package:keycast_flutter/keycast_flutter.dart';

enum ProtectedMinorStatusKind {
  unknown,
  notProtected,
  protected,
}

/// Client-side "protected minor" state for an approved 13-15 account.
///
/// This is deliberately separate from [AccountRestrictionStatus] /
/// `MinorAccountReviewStatus`, which drive the *blocking* under-review gate.
/// A protected minor may use the app; the content-lock and DM-restriction
/// protections (#175/#176) consume this state.
class ProtectedMinorStatus {
  const ProtectedMinorStatus({
    required this.kind,
    this.verifiedMinorAt,
  });

  factory ProtectedMinorStatus.unknown() =>
      const ProtectedMinorStatus(kind: ProtectedMinorStatusKind.unknown);

  factory ProtectedMinorStatus.notProtected() =>
      const ProtectedMinorStatus(kind: ProtectedMinorStatusKind.notProtected);

  factory ProtectedMinorStatus.protected({DateTime? verifiedMinorAt}) =>
      ProtectedMinorStatus(
        kind: ProtectedMinorStatusKind.protected,
        verifiedMinorAt: verifiedMinorAt,
      );

  /// Maps a Keycast account status to protected-minor state. A null status
  /// (fetch failed / unavailable) is preserved as unknown so enforcement
  /// layers can choose their own fail-safe behavior; `verified_minor == false`
  /// is the only confirmed not-protected response.
  factory ProtectedMinorStatus.fromKeycast(KeycastAccountStatus? status) {
    if (status == null) {
      return ProtectedMinorStatus.unknown();
    }
    if (!status.verifiedMinor) {
      return ProtectedMinorStatus.notProtected();
    }
    return ProtectedMinorStatus.protected(
      verifiedMinorAt: status.verifiedMinorAt,
    );
  }

  final ProtectedMinorStatusKind kind;
  final DateTime? verifiedMinorAt;

  bool get isProtectedMinor => kind == ProtectedMinorStatusKind.protected;
  bool get isKnown => kind != ProtectedMinorStatusKind.unknown;
}
