part of 'profile_header_widget.dart';

class _ProfileNameAndBio extends StatelessWidget {
  const _ProfileNameAndBio({
    required this.profile,
    required this.userIdHex,
    required this.nip05,
    required this.about,
    required this.isOwnProfile,
    this.displayNameHint,
    this.accentColor,
  });

  final UserProfile? profile;
  final String userIdHex;
  final String? nip05;
  final String? about;
  final bool isOwnProfile;
  final String? displayNameHint;

  /// Optional accent color (from profile color) for links/buttons.
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    // Every child except the badge row carries the horizontal inset. The
    // badge block spans the full width so its row can scroll edge-to-edge.
    const inset = EdgeInsets.symmetric(
      horizontal: _profileIdentityHorizontalInset,
    );
    return Column(
      children: [
        Padding(
          padding: inset,
          child: Column(
            children: [
              if (profile != null)
                UserName.fromUserProfile(
                  profile!,
                  style: VineTheme.titleLargeFont(),
                )
              else
                UserName.fromPubKey(
                  userIdHex,
                  style: VineTheme.titleLargeFont(),
                  anonymousName: displayNameHint,
                ),
              Skeleton.keep(
                child: _UniqueIdentifier(
                  userIdHex: userIdHex,
                  nip05: nip05,
                  isOwnProfile: isOwnProfile,
                  accentColor: accentColor,
                ),
              ),
            ],
          ),
        ),
        Skeleton.keep(child: _ProfileBadgesBlock(userIdHex: userIdHex)),
        Padding(
          padding: inset,
          child: Column(
            children: [
              if (about != null && about!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Skeleton.keep(child: _AboutText(about: about!)),
              ],
              if (profile?.website?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Skeleton.keep(child: ProfileWebsiteRow(url: profile!.website!)),
              ],
              _VerifiedAccountsBlock(isOwnProfile: isOwnProfile),
            ],
          ),
        ),
      ],
    );
  }
}

/// Horizontal inset applied to the name/bio identity block. Shared so the
/// badge row can break out of it and scroll edge-to-edge.
const double _profileIdentityHorizontalInset = 16;

class _ProfileBadgesBlock extends ConsumerWidget {
  const _ProfileBadgesBlock({required this.userIdHex});

  final String userIdHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final badges = ref.watch(profileAcceptedBadgesProvider(userIdHex));
    return badges.when(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The block spans the full width (its siblings carry the
              // horizontal inset instead), so the row scrolls edge-to-edge.
              // A resting lead keeps chips aligned with the text above while
              // letting them peek past the screen edge once they overflow.
              const inset = _profileIdentityHorizontalInset;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: inset),
                // Centered when the badges fit; scrollable once they overflow.
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth - inset * 2,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 8,
                    children: [
                      for (final item in items) _ProfileBadgeChip(badge: item),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      error: (_, _) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
    );
  }
}

class _ProfileBadgeChip extends StatelessWidget {
  const _ProfileBadgeChip({required this.badge});

  final ProfileBadgeViewData badge;

  @override
  Widget build(BuildContext context) {
    final imageUrl = badge.imageUrl;
    final l10n = context.l10n;
    const radius = 16.0;
    return Semantics(
      button: true,
      label: l10n.profileBadgeSemanticLabel(badge.displayName),
      child: Material(
        color: VineTheme.surfaceBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: VineTheme.neutral10),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: () => _showProfileBadgeSheet(context, badge),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ProfileBadgeImage(
                    imageUrl: imageUrl,
                    semanticLabel: badge.displayName,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      badge.displayName,
                      style: VineTheme.labelMediumFont(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileBadgeImage extends StatelessWidget {
  const _ProfileBadgeImage({
    required this.imageUrl,
    this.size = 20,
    this.semanticLabel,
  });

  final String? imageUrl;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final label =
        semanticLabel ?? context.l10n.profileBadgeFallbackSemanticLabel;
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: VineTheme.vineGreen,
      ),
      child: Center(
        child: ExcludeSemantics(
          child: Text(
            'B',
            style: VineTheme.labelSmallFont(color: VineTheme.primaryDarkGreen),
          ),
        ),
      ),
    );

    return Semantics(
      image: true,
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: size,
          height: size,
          child: imageUrl == null || imageUrl!.isEmpty
              ? fallback
              : ClipOval(
                  child: VineCachedImage(
                    imageUrl: imageUrl!,
                    width: size,
                    height: size,
                    errorWidget: (_, _, _) => fallback,
                  ),
                ),
        ),
      ),
    );
  }
}

void _showProfileBadgeSheet(BuildContext context, ProfileBadgeViewData badge) {
  VineBottomSheet.show<void>(
    context: context,
    showHeaderDivider: false,
    body: _ProfileBadgeDetailsSheet(badge: badge),
  );
}

class _ProfileBadgeDetailsSheet extends StatelessWidget {
  const _ProfileBadgeDetailsSheet({required this.badge});

  static const _maxVisibleRecipients = 12;

  final ProfileBadgeViewData badge;

  @override
  Widget build(BuildContext context) {
    final issuerPubkey = badge.issuerPubkey;
    final recipients = badge.uniqueRecipientPubkeys;
    final visibleRecipients = recipients.take(_maxVisibleRecipients).toList();
    final hiddenRecipientCount = recipients.length - visibleRecipients.length;
    final description = badge.description?.trim();
    final l10n = context.l10n;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ProfileBadgeImage(
                    imageUrl: badge.imageUrl,
                    size: 56,
                    semanticLabel: badge.displayName,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          badge.displayName,
                          style: VineTheme.titleMediumFont(
                            color: VineTheme.onSurface,
                          ),
                        ),
                        if (description != null && description.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            description,
                            style: VineTheme.bodyMediumFont(
                              color: VineTheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (issuerPubkey != null && issuerPubkey.isNotEmpty) ...[
                const SizedBox(height: 24),
                _ProfileBadgeSheetSectionTitle(l10n.profileBadgeAwardedBy),
                UserProfileTile(
                  pubkey: issuerPubkey,
                  showFollowButton: false,
                  onTap: () =>
                      _openProfileFromBadgeSheet(context, issuerPubkey),
                ),
              ],
              if (recipients.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ProfileBadgeSheetSectionTitle(l10n.profileBadgeRecipients),
                for (final recipientPubkey in visibleRecipients)
                  UserProfileTile(
                    pubkey: recipientPubkey,
                    showFollowButton: false,
                    onTap: () =>
                        _openProfileFromBadgeSheet(context, recipientPubkey),
                  ),
                if (hiddenRecipientCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text(
                      l10n.profileBadgeMoreRecipients(hiddenRecipientCount),
                      style: VineTheme.bodySmallFont(
                        color: VineTheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileBadgeSheetSectionTitle extends StatelessWidget {
  const _ProfileBadgeSheetSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 2),
      child: Text(
        text,
        style: VineTheme.labelMediumFont(color: VineTheme.onSurfaceVariant),
      ),
    );
  }
}

void _openProfileFromBadgeSheet(BuildContext context, String pubkey) {
  final path = OtherProfileScreen.pathForNpub(
    NostrKeyUtils.encodePubKey(pubkey),
  );
  final router = GoRouter.of(context);
  Navigator.of(context).pop();
  router.push(path);
}

class _VerifiedAccountsBlock extends StatelessWidget {
  const _VerifiedAccountsBlock({required this.isOwnProfile});

  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    final claims = isOwnProfile
        ? _readMyClaims(context)
        : _readOtherClaims(context);
    if (claims.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: VerifiedAccountsRow(claims: claims),
    );
  }

  static List<IdentityClaim> _readMyClaims(BuildContext context) {
    try {
      return context.select<MyProfileBloc, List<IdentityClaim>>((bloc) {
        final state = bloc.state;
        if (state is MyProfileLoaded) return state.verifiedClaims;
        if (state is MyProfileUpdated) return state.verifiedClaims;
        if (state is MyProfileLoading) return state.verifiedClaims;
        return const [];
      });
    } on ProviderNotFoundException {
      return const [];
    }
  }

  static List<IdentityClaim> _readOtherClaims(BuildContext context) {
    try {
      return context.select<OtherProfileBloc, List<IdentityClaim>>((bloc) {
        final state = bloc.state;
        if (state is OtherProfileLoaded) return state.verifiedClaims;
        return const [];
      });
    } on ProviderNotFoundException {
      return const [];
    }
  }
}

/// Unique identifier display (NIP-05 or full npub with ellipsis).
/// Uses profile accent color when available, falls back to vineGreen.
/// Shows warning for failed NIP-05 verification on own profile.
/// Hides unverified NIP-05s for other profiles (potential impersonation).
class _UniqueIdentifier extends ConsumerWidget {
  const _UniqueIdentifier({
    required this.userIdHex,
    required this.nip05,
    required this.isOwnProfile,
    this.accentColor,
  });

  final String userIdHex;
  final String? nip05;
  final bool isOwnProfile;

  /// Optional accent color (from profile color) for the link text and icon.
  final Color? accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasNip05 = nip05 != null && nip05!.isNotEmpty;
    final npub = NostrKeyUtils.encodePubKey(userIdHex);
    const linkColor = VineTheme.vineGreen;

    // Watch NIP-05 verification status
    final verificationStatus = hasNip05
        ? ref
              .watch(nip05VerificationProvider(userIdHex))
              .whenOrNull(data: (status) => status)
        : null;

    final verificationFailed =
        verificationStatus == Nip05VerificationStatus.failed;

    // For other profiles: hide unverified NIP-05s (show npub instead)
    // For own profile: show with warning so user knows there's an issue
    final String displayText;
    if (hasNip05) {
      if (verificationFailed && !isOwnProfile) {
        // Don't show unverified NIP-05s for other users - potential impersonation
        displayText = truncateNpubForDisplay(npub);
      } else {
        displayText = nip05!;
      }
    } else {
      displayText = truncateNpubForDisplay(npub);
    }

    return GestureDetector(
      onTap: () {
        final verifiedNip05 = hasNip05 && !verificationFailed ? nip05 : null;
        final profileUrl = buildProfileUrl(verifiedNip05, npub);
        ClipboardUtils.copy(
          context,
          profileUrl,
          message: context.l10n.profileLinkCopied,
        );
      },
      child: Text(
        displayText,
        style: VineTheme.bodyMediumFont(color: linkColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Maximum characters of a raw npub to show before the ellipsis when it is
/// used as the fallback identifier on the profile screen.
const int profileNpubMaxChars = 16;

/// Trim a raw npub for the profile identifier row.
///
/// Shows the first [profileNpubMaxChars] characters followed by an ellipsis
/// when the npub is longer than that. Used only when no NIP-05 / divine
/// username is available (or the NIP-05 is unverified on another user's
/// profile).
String truncateNpubForDisplay(String npub) {
  if (npub.length <= profileNpubMaxChars) return npub;
  return '${npub.substring(0, profileNpubMaxChars)}...';
}

/// Build a shareable profile URL.
///
/// If the user has a `.divine.video` NIP-05 subdomain (e.g. `_@thomas.divine.video`),
/// returns `https://thomas.divine.video`. Otherwise falls back to
/// `https://divine.video/profile/{npub}`.
@visibleForTesting
String buildProfileUrl(String? nip05, String npub) {
  if (nip05 != null && nip05.isNotEmpty) {
    // NIP-05 format: `_@username.divine.video` or `user@domain.com`
    final atIndex = nip05.indexOf('@');
    if (atIndex != -1) {
      final domain = nip05.substring(atIndex + 1);
      if (domain.endsWith('.divine.video')) {
        return 'https://$domain';
      }
    }
  }
  return 'https://divine.video/profile/$npub';
}

/// About/bio text display with expandable "Show more/less" functionality.
