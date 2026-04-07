// ABOUTME: Lightweight profile snapshot for display in notifications.
// ABOUTME: Contains pubkey, display name, and optional avatar URL.

import 'package:equatable/equatable.dart';

/// Lightweight profile snapshot for display in notifications.
class ActorInfo extends Equatable {
  const ActorInfo({
    required this.pubkey,
    required this.displayName,
    this.pictureUrl,
  });

  /// The actor's public key (hex, 64 chars).
  final String pubkey;

  /// Display name resolved from the actor's kind-0 profile.
  final String displayName;

  /// Avatar URL from the actor's kind-0 profile, if available.
  final String? pictureUrl;

  @override
  List<Object?> get props => [pubkey, displayName, pictureUrl];
}
