// ABOUTME: Response model for the Funnelcake bulk profiles endpoint.
// ABOUTME: Uses UserProfileResult to carry profile-vs-no-profile state with
// ABOUTME: proper typing instead of a Map<String, dynamic> sentinel.

import 'package:meta/meta.dart';
import 'package:models/src/user_profile_result.dart';

/// Response from the bulk profiles endpoint (`/api/users/bulk`).
///
/// [profiles] is keyed by pubkey (hex). Values are [UserProfileFound] for
/// users who have published a Kind 0 event, or [UserProfileNotPublished] for
/// users who exist in Funnelcake but have never published one.
@immutable
class BulkProfilesResponse {
  /// Creates a new [BulkProfilesResponse].
  const BulkProfilesResponse({required this.profiles});

  /// Profile results keyed by pubkey (hex format).
  final Map<String, UserProfileResult> profiles;
}
