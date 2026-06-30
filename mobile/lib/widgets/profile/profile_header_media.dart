part of 'profile_header_widget.dart';

/// Hero tag for the avatar ↔ lightbox shared-element flight, scoped to the
/// user. A global tag would let two profile headers with the same tag in one
/// navigator (e.g. other-profile → other-profile, both on the root navigator)
/// morph one user's avatar into another's during the page transition.
String _avatarHeroTag(String userIdHex) => 'profile_avatar_hero_$userIdHex';

/// Size and corner radius of the full-screen lightbox avatar.
const double _lightboxAvatarSize = 288;
const double _lightboxAvatarCornerRadius = 112;

/// Corner-radius-to-size ratio of the lightbox avatar, also matched by the
/// 144px header avatar (56px radius). The Hero flight reproduces this ratio at
/// every interpolated size so the corner stays proportional. The default
/// flight shuttle instead paints the destination's fixed 112px radius onto the
/// shrinking flight box, which clamps to a full circle while the box is smaller
/// than 224px and makes the avatar briefly round mid-flight.
const double _avatarHeroCornerRatio =
    _lightboxAvatarCornerRadius / _lightboxAvatarSize;

class _AboutText extends StatefulWidget {
  const _AboutText({required this.about});

  final String about;

  /// Maximum lines to show when collapsed.
  static const int _collapsedMaxLines = 3;

  @override
  State<_AboutText> createState() => _AboutTextState();
}

class _AboutTextState extends State<_AboutText> {
  bool _isExpanded = false;
  bool _needsExpansion = false;

  @override
  Widget build(BuildContext context) {
    final textStyle = VineTheme.bodyMediumFont(
      color: VineTheme.onSurfaceVariant,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure if text exceeds max lines
        final textSpan = TextSpan(text: widget.about, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: _AboutText._collapsedMaxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        _needsExpansion = textPainter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isExpanded)
              SelectableLinkifiedText(text: widget.about, style: textStyle)
            else
              LinkifiedText(
                text: widget.about,
                style: textStyle,
                maxLines: _AboutText._collapsedMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
            if (_needsExpansion)
              GestureDetector(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _isExpanded
                        ? context.l10n.profileShowLess
                        : context.l10n.profileShowMore,
                    style: VineTheme.bodySmallFont(color: VineTheme.vineGreen),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// The 334px background banner area. Shows a banner image, a color gradient,
/// or a plain dark background depending on what the profile provides.
///
/// Uses a foreground [BoxDecoration] gradient scrim instead of a [Stack] to
/// avoid parentData assertions during route transitions.
class ProfileBanner extends StatelessWidget {
  const ProfileBanner({
    required this.height,
    this.bannerUrl,
    this.profileColor,
    super.key,
  });

  final double height;
  final String? bannerUrl;
  final Color? profileColor;

  @override
  Widget build(BuildContext context) {
    // Gradient scrim that fades to the surface background at the bottom.
    // Applied as foregroundDecoration so it overlays the background content.
    final scrimDecoration = BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          VineTheme.surfaceBackground.withValues(alpha: 0),
          VineTheme.surfaceBackground,
        ],
      ),
    );

    if (bannerUrl != null) {
      return _BannerImage(
        bannerUrl: bannerUrl!,
        height: height,
        scrimDecoration: scrimDecoration,
      );
    }

    final backgroundGradient = profileColor != null
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [profileColor!, profileColor!],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [VineTheme.containerLow, VineTheme.surfaceBackground],
          );

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(gradient: backgroundGradient),
      foregroundDecoration: scrimDecoration,
    );
  }
}

/// Banner with a network image and a gradient scrim overlay.
/// Uses [VineCachedImage] so banner art benefits from the shared on-disk
/// cache layer instead of hitting the network on every rebuild.
class _BannerImage extends StatelessWidget {
  const _BannerImage({
    required this.bannerUrl,
    required this.height,
    required this.scrimDecoration,
  });

  final String bannerUrl;
  final double height;
  final BoxDecoration scrimDecoration;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      foregroundDecoration: scrimDecoration,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(color: VineTheme.surfaceBackground),
      child: VineCachedImage(
        imageUrl: bannerUrl,
        errorWidget: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

/// Stats row displaying Followers, Following, Likes, and Loops with dividers.
///
/// Shows a skeleton for up to [_ProfileStatsRowState._skeletonTimeout] while
/// stats are being fetched. After the timeout the row keeps all four columns
/// visible but renders a `—` placeholder for each count, rather than
/// shimmering indefinitely or collapsing the row (which would shift the
/// surrounding profile layout).
class _ProfileStatsRow extends StatefulWidget {
  const _ProfileStatsRow({required this.userIdHex, this.profileStats});

  final String userIdHex;
  final ProfileStats? profileStats;

  @override
  State<_ProfileStatsRow> createState() => _ProfileStatsRowState();
}

class _ProfileStatsRowState extends State<_ProfileStatsRow> {
  static const _skeletonTimeout = Duration(seconds: 7);

  /// Two-digit placeholder painted behind the Skeletonizer shimmer while the
  /// real stats load. The number itself is never visible — it only sets the
  /// width of the skeleton bar.
  static const _skeletonPlaceholderCount = 99;

  Timer? _timer;
  bool _timeoutExpired = false;

  @override
  void initState() {
    super.initState();
    if (widget.profileStats == null) {
      _timer = Timer(_skeletonTimeout, () {
        if (mounted) setState(() => _timeoutExpired = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = widget.profileStats == null;

    final hasFollowers = widget.profileStats?.followers != null;
    final hasFollowing = widget.profileStats?.following != null;
    final hasLikes = widget.profileStats?.totalLikes != null;
    final hasLoops = widget.profileStats?.totalViews != null;

    final l10n = context.l10n;
    final columns = <Widget>[
      if (hasLoops || isLoading)
        ProfileStatColumn(
          count: isLoading
              ? _skeletonPlaceholderCount
              : widget.profileStats!.totalViews,
          label: l10n.profileLoopsLabel,
          isLoading: isLoading && _timeoutExpired,
        ),
      if (hasLikes || isLoading)
        ProfileStatColumn(
          count: isLoading
              ? _skeletonPlaceholderCount
              : widget.profileStats!.totalLikes,
          label: l10n.profileLikesLabel,
          isLoading: isLoading && _timeoutExpired,
        ),
      if (hasFollowing || isLoading)
        ProfileStatColumn(
          count: isLoading
              ? _skeletonPlaceholderCount
              : widget.profileStats!.following,
          label: l10n.profileFollowingLabel,
          isLoading: isLoading && _timeoutExpired,
          onTap: () => context.push(
            FollowingScreenRouter.pathForPubkey(widget.userIdHex),
          ),
        ),
      if (hasFollowers || isLoading)
        ProfileStatColumn(
          count: isLoading
              ? _skeletonPlaceholderCount
              : widget.profileStats!.followers,
          label: l10n.profileFollowersLabel,
          isLoading: isLoading && _timeoutExpired,
          onTap: () => context.push(
            FollowersScreenRouter.pathForPubkey(widget.userIdHex),
          ),
        ),
    ];

    return Skeletonizer(
      enabled: isLoading && !_timeoutExpired,
      enableSwitchAnimation: true,
      effect: vineSkeletonEffect,
      child: Row(
        children: [
          for (int i = 0; i < columns.length; i++) ...[
            if (i > 0) const _StatDivider(),
            Expanded(child: columns[i]),
          ],
        ],
      ),
    );
  }
}

/// Vertical divider between stat columns.
class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 2,
      height: 44,
      child: ColoredBox(color: VineTheme.outlineMuted),
    );
  }
}

/// Profile avatar with optional action label overlapping the bottom edge.
///
/// When [pendingActions] is non-empty, a pill-shaped label (e.g. "Secure
/// your account") is centred below the avatar. A red count badge appears
/// on the label when more than one action is pending. Tapping either the
/// avatar or the label triggers [onActionTap].
///
/// The avatar shimmers when an enclosing [Skeletonizer] is enabled. The
/// pending-action label is decorative chrome and is wrapped in
/// [Skeleton.keep] so it stays interactive and unshimmered (#4163).
class _ProfileAvatarWithColor extends StatelessWidget {
  const _ProfileAvatarWithColor({
    required this.imageUrl,
    required this.userIdHex,
    this.profileColor,
    this.pendingActions = const [],
    this.onActionTap,
  });

  final String? imageUrl;

  /// Hex pubkey used as the placeholder tone seed so the same user gets
  /// the same accent color here as in notifications and other surfaces.
  final String userIdHex;
  final Color? profileColor;

  /// Ordered list of pending profile actions. The first action determines
  /// the label text and icon.
  final List<ProfileActionType> pendingActions;

  /// Called when the label or avatar is tapped.
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    const avatarSize = 144.0;
    final hasAvatar = imageUrl != null && imageUrl!.isNotEmpty;
    final avatarWidget = UserAvatar(
      imageUrl: imageUrl,
      placeholderSeed: userIdHex,
      size: avatarSize,
    );
    final avatar = hasAvatar
        ? GestureDetector(
            onTap: () => _showAvatarLightbox(
              context,
              imageUrl: imageUrl,
              userIdHex: userIdHex,
            ),
            child: Hero(
              tag: _avatarHeroTag(userIdHex),
              flightShuttleBuilder: (_, _, _, _, _) => _AvatarHeroFlightShuttle(
                imageUrl: imageUrl,
                userIdHex: userIdHex,
              ),
              child: avatarWidget,
            ),
          )
        : avatarWidget;

    if (pendingActions.isEmpty) return avatar;

    // The label overlaps the avatar bottom, so we need extra space below.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // Reserve space for label overflow below the avatar.
        const SizedBox(width: avatarSize, height: avatarSize + 16),
        avatar,
        Positioned(
          bottom: 0,
          child: Skeleton.replace(
            replacement: const SizedBox.shrink(),
            child: GestureDetector(
              onTap: onActionTap,
              child: _ProfileActionLabel(
                action: pendingActions.first,
                badgeCount: pendingActions.length,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Pill-shaped label shown below the profile avatar for the highest-priority
/// pending action. Displays an icon and text matching the action type, with
/// an optional red badge when multiple actions are pending.
class _ProfileActionLabel extends StatelessWidget {
  const _ProfileActionLabel({required this.action, required this.badgeCount});

  final ProfileActionType action;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (action) {
      ProfileActionType.secureAccount => (
        DivineIconName.lockSimple,
        'Secure your account',
      ),
      ProfileActionType.completeProfile => (
        DivineIconName.pencilSimple,
        'Complete your profile',
      ),
    };

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
          decoration: BoxDecoration(
            color: VineTheme.accentYellowBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(0.4, 0.4),
                blurRadius: 0.6,
              ),
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(1, 1),
                blurRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 8,
            children: [
              DivineIcon(icon: icon, size: 16, color: VineTheme.accentYellow),
              Text(
                label,
                style: VineTheme.titleSmallFont(color: VineTheme.accentYellow),
              ),
            ],
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -4,
            top: -8,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: VineTheme.error,
                borderRadius: BorderRadius.circular(1000),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount.toString(),
                style: VineTheme.labelSmallFont(),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar lightbox
// ---------------------------------------------------------------------------

class _AvatarHeroFlightShuttle extends StatelessWidget {
  const _AvatarHeroFlightShuttle({required this.userIdHex, this.imageUrl});

  final String? imageUrl;
  final String userIdHex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxSize = constraints.biggest.shortestSide;
        return UserAvatar(
          imageUrl: imageUrl,
          placeholderSeed: userIdHex,
          size: boxSize,
          cornerRadius: boxSize * _avatarHeroCornerRatio,
        );
      },
    );
  }
}

void _showAvatarLightbox(
  BuildContext context, {
  required String userIdHex,
  String? imageUrl,
}) {
  // Push on the root navigator so the full-screen blurred backdrop covers the
  // bottom navigation bar: on the own-profile tab the nearest navigator is the
  // StatefulShellRoute branch, confined to the Scaffold body. (The previous
  // showGeneralDialog used useRootNavigator: true for the same reason.) The
  // Hero flight still runs across the boundary because Flutter collects heroes
  // from the current PageRoute of nested navigators, so the header avatar
  // (branch) and the lightbox (root) are matched. A PageRoute — not a
  // PopupRoute like showGeneralDialog — is required for the HeroController.
  Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: VineTheme.transparent,
      barrierDismissible: true,
      barrierLabel: context.l10n.profileAvatarLightboxBarrierLabel,
      pageBuilder: (context, _, _) =>
          _AvatarLightbox(imageUrl: imageUrl, userIdHex: userIdHex),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _AvatarLightbox extends StatelessWidget {
  const _AvatarLightbox({required this.userIdHex, this.imageUrl});

  final String? imageUrl;

  /// Pubkey used as the placeholder seed so the lightbox's fallback
  /// colour matches the avatar everywhere else when the image fails.
  final String userIdHex;

  @override
  Widget build(BuildContext context) {
    final safeAreaTop = MediaQuery.of(context).padding.top;

    return Semantics(
      label: context.l10n.profileAvatarLightboxCloseSemanticLabel,
      button: true,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: SizedBox.expand(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: ColoredBox(
              color: VineTheme.scrim65,
              child: Stack(
                children: [
                  Center(
                    child: Hero(
                      tag: _avatarHeroTag(userIdHex),
                      child: UserAvatar(
                        imageUrl: imageUrl,
                        placeholderSeed: userIdHex,
                        size: _lightboxAvatarSize,
                        cornerRadius: _lightboxAvatarCornerRadius,
                      ),
                    ),
                  ),
                  Positioned(
                    top: safeAreaTop + 12,
                    left: 12,
                    child: DivineIconButton(
                      icon: DivineIconName.x,
                      type: DivineIconButtonType.ghostSecondary,
                      size: DivineIconButtonSize.small,
                      onPressed: () => Navigator.of(context).pop(),
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
