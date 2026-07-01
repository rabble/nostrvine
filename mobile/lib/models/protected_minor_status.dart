// ABOUTME: Non-blocking protected-minor (13-15) state derived from Keycast's
// ABOUTME: verified_minor flag. Distinct from the blocking minor-review gate.

import 'package:keycast_flutter/keycast_flutter.dart';

/// Client-side "protected minor" state for an approved 13-15 account.
///
/// This is deliberately separate from [AccountRestrictionStatus] /
/// `MinorAccountReviewStatus`, which drive the *blocking* under-review gate.
/// A protected minor may use the app; the content-lock and DM-restriction
/// protections (#175/#176) consume this state.
class ProtectedMinorStatus {
  const ProtectedMinorStatus({
    required this.isProtectedMinor,
    this.verifiedMinorAt,
  });

  factory ProtectedMinorStatus.notProtected() =>
      const ProtectedMinorStatus(isProtectedMinor: false);

  /// Maps a Keycast account status to protected-minor state. A null status
  /// (fetch failed / unavailable) or `verified_minor == false` is treated as
  /// not protected — #174 is detection-only, so it fails to not-protected.
  factory ProtectedMinorStatus.fromKeycast(KeycastAccountStatus? status) {
    if (status == null || !status.verifiedMinor) {
      return ProtectedMinorStatus.notProtected();
    }
    return ProtectedMinorStatus(
      isProtectedMinor: true,
      verifiedMinorAt: status.verifiedMinorAt,
    );
  }

  final bool isProtectedMinor;
  final DateTime? verifiedMinorAt;
}
