// ABOUTME: OAuthVerificationStatus model — verifier OAuth cache lookup result.
// ABOUTME: Mirrors the GET /auth/:platform/status response shape.

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Whether the verifier still holds an OAuth verification for a claim.
///
/// The verifier stores OAuth results in KV for 24 hours
/// (`divine-identify-verification-service/src/oauth/state.ts`), so a
/// [verified] of false can mean "never linked" or "linked, but the OAuth
/// entry has since expired" — the two are indistinguishable over this API.
@immutable
class OAuthVerificationStatus extends Equatable {
  /// Creates an [OAuthVerificationStatus].
  const OAuthVerificationStatus({
    required this.platform,
    required this.identity,
    required this.verified,
    this.checkedAt,
  });

  /// Parses an [OAuthVerificationStatus] from the verifier API JSON shape.
  factory OAuthVerificationStatus.fromJson(Map<String, dynamic> json) {
    return OAuthVerificationStatus(
      platform: json['platform'] as String,
      identity: json['identity'] as String,
      verified: json['verified'] as bool? ?? false,
      checkedAt: json['checked_at'] as int?,
    );
  }

  /// Platform identifier the status is for.
  final String platform;

  /// Platform-specific identity the status is for.
  final String identity;

  /// Whether the verifier still holds an OAuth verification for the claim.
  final bool verified;

  /// Unix epoch seconds of the OAuth login, when [verified] is true.
  final int? checkedAt;

  @override
  List<Object?> get props => [platform, identity, verified, checkedAt];
}
