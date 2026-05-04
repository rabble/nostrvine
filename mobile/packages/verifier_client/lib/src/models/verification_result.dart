// ABOUTME: VerificationResult model — verifier API response per claim.

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// Result of asking the verifier to re-check a single identity claim.
@immutable
class VerificationResult extends Equatable {
  /// Creates a [VerificationResult] from explicit fields.
  const VerificationResult({
    required this.platform,
    required this.identity,
    required this.verified,
    required this.checkedAt,
    required this.cached,
    this.error,
  });

  /// Parses a [VerificationResult] from the verifier API JSON shape.
  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    return VerificationResult(
      platform: json['platform'] as String,
      identity: json['identity'] as String,
      verified: json['verified'] as bool,
      checkedAt: json['checked_at'] as int,
      cached: json['cached'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  /// Platform identifier the result is for (e.g. `github`).
  final String platform;

  /// Platform-specific identity (handle, account ID).
  final String identity;

  /// Whether the verifier confirmed the claim.
  final bool verified;

  /// Unix epoch seconds when the verifier last checked the claim.
  final int checkedAt;

  /// True when the result was served from the verifier's KV cache.
  final bool cached;

  /// Free-form error string when [verified] is false. Not a stable key.
  final String? error;

  @override
  List<Object?> get props => [
    platform,
    identity,
    verified,
    checkedAt,
    cached,
    error,
  ];
}
