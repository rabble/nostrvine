// ABOUTME: VerifierPlatform model — one entry of the verifier's platform list.
// ABOUTME: Mirrors the PlatformInfo shape returned by GET /platforms.

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// A platform the verifier can check identity claims against.
///
/// Mirrors `PlatformInfo` in
/// `divine-identify-verification-service/src/types.ts`, keyed by the
/// platform identifier used in NIP-39 `i` tags.
@immutable
class VerifierPlatform extends Equatable {
  /// Creates a [VerifierPlatform].
  const VerifierPlatform({
    required this.key,
    required this.label,
    required this.supported,
  });

  /// Parses one entry of the `platforms` map returned by `GET /platforms`.
  factory VerifierPlatform.fromJson(String key, Map<String, dynamic> json) {
    return VerifierPlatform(
      key: key,
      label: json['label'] as String? ?? key,
      supported: json['supported'] as bool? ?? false,
    );
  }

  /// Platform identifier as used in the `i` tag (e.g. `github`).
  final String key;

  /// Human-readable name for display (e.g. `Twitter / X`).
  final String label;

  /// Whether the verifier can currently check this platform.
  ///
  /// The service reports `false` when a platform's credentials are missing —
  /// Discord without its bot token, for example — so an unsupported platform
  /// must not be offered even though it appears in the response.
  final bool supported;

  /// Whether this platform can be linked through an OAuth login instead of a
  /// proof post.
  bool get supportsOAuth => oauthPlatforms.contains(key);

  /// Platforms the verifier exposes an OAuth flow for.
  ///
  /// Mirrors the switch in
  /// `divine-identify-verification-service/src/routes/auth.ts` — every other
  /// platform is proof-post only.
  static const oauthPlatforms = <String>{
    'twitter',
    'bluesky',
    'youtube',
    'tiktok',
  };

  @override
  List<Object?> get props => [key, label, supported];
}
