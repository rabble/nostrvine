// ABOUTME: Resolves the secondary identifier line under a user's display name
// ABOUTME: Prefers a NIP-05 handle, falls back to social proof, else nothing

import 'package:count_formatter/count_formatter.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/services/nip05_verification_service.dart';

/// Separator between social-proof segments, matching the convention used by
/// the sound and video metadata rows.
const _segmentSeparator = ' · ';

/// Returns the line to render under a user's display name, or `null` when
/// nothing worth showing is known.
///
/// A claimed NIP-05 wins whenever it is safe to show. Only
/// [Nip05VerificationStatus.failed] — an actual pubkey mismatch — suppresses
/// it, and only on someone else's profile, since that is the sole status that
/// signals impersonation. Pending and [Nip05VerificationStatus.error] are
/// network conditions, not identity claims, so they must not demote a handle.
///
/// Without a usable handle the line falls back to social proof, which answers
/// the question the identifier is really there for: which of the several
/// accounts sharing this display name is this? A truncated npub never could.
String? resolveUserIdentifierLine({
  required AppLocalizations l10n,
  required String locale,
  String? handle,
  Nip05VerificationStatus? verificationStatus,
  bool isOwnProfile = false,
  FollowRelationship relationship = FollowRelationship.none,
  int? followerCount,
}) {
  final impersonationRisk =
      verificationStatus == Nip05VerificationStatus.failed && !isOwnProfile;
  // Trim before the emptiness test: a kind-0 nip05 of only whitespace is not
  // a usable handle, and sanitizeForDisplay does not strip it.
  final trimmedHandle = handle?.trim();
  if (trimmedHandle != null && trimmedHandle.isNotEmpty && !impersonationRisk) {
    return trimmedHandle;
  }

  final relationshipLabel = switch (relationship) {
    FollowRelationship.mutual => l10n.socialProofMutual,
    FollowRelationship.followsYou => l10n.socialProofFollowsYou,
    FollowRelationship.youFollow => l10n.socialProofYouFollow,
    FollowRelationship.none => null,
  };

  // A zero count is either a genuinely unfollowed account or a stat that has
  // not loaded; neither earns space on the line.
  final countLabel = followerCount != null && followerCount > 0
      ? l10n.socialProofFollowerCount(
          followerCount,
          CountFormatter.formatCompact(followerCount, locale: locale),
        )
      : null;

  final segments = [
    ?relationshipLabel,
    ?countLabel,
  ];

  return segments.isEmpty ? null : segments.join(_segmentSeparator);
}
