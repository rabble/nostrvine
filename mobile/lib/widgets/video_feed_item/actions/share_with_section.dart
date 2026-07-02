part of 'share_action_button.dart';

/// Placeholder rows shown (skeletonized) while the real contacts load, so the
/// shimmer has the same avatar + name shape it dissolves into — instead of a
/// spinner that pops. See #5391.
final List<ShareableUser> _skeletonContacts = List.generate(
  6,
  (_) => const ShareableUser(pubkey: '', displayName: 'Username'),
);

// ---------------------------------------------------------------------------
// "Share with" horizontal contact row
// ---------------------------------------------------------------------------

class _ShareWithSection extends StatelessWidget {
  const _ShareWithSection({
    required this.contacts,
    required this.contactsLoaded,
    required this.selectedPubkeys,
    required this.onFindPeople,
    required this.onContactTapped,
  });

  final List<ShareableUser> contacts;
  final bool contactsLoaded;
  final Set<String> selectedPubkeys;
  final VoidCallback onFindPeople;
  final ValueChanged<ShareableUser> onContactTapped;

  static const double _itemWidth = 72;
  static const double _avatarSize = 48;
  static const double _avatarRadius = _avatarSize * 0.286;
  static const double _rowHeight = 90;

  @override
  Widget build(BuildContext context) {
    // While loading, render placeholder rows so the shimmer matches the real
    // avatar + name layout it will dissolve into.
    final displayContacts = contactsLoaded ? contacts : _skeletonContacts;

    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              context.l10n.shareWithTitle,
              style: const TextStyle(
                color: VineTheme.whiteText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            height: _rowHeight,
            // Skeleton contacts shimmer, then dissolve into the real list when
            // it loads (enableSwitchAnimation), instead of a spinner that pops.
            child: IdentitySkeletonizer(
              isLoading: !contactsLoaded,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                // +1 for the always-present "Find people" entry.
                itemCount: displayContacts.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Keep "Find people" solid + tappable during the shimmer.
                    return Skeleton.keep(
                      child: _FindPeopleItem(onTap: onFindPeople),
                    );
                  }

                  final contact = displayContacts[index - 1];
                  if (!contactsLoaded) {
                    // Placeholder bone — not interactive, excluded from a11y.
                    return ExcludeSemantics(
                      child: _ContactItem(
                        user: contact,
                        isSelected: false,
                        onTap: () {},
                      ),
                    );
                  }

                  return _ContactItem(
                    user: contact,
                    isSelected: selectedPubkeys.contains(contact.pubkey),
                    onTap: () => onContactTapped(contact),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FindPeopleItem extends StatelessWidget {
  const _FindPeopleItem({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.shareFindPeople,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: _ShareWithSection._itemWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Container(
                width: _ShareWithSection._avatarSize,
                height: _ShareWithSection._avatarSize,
                decoration: BoxDecoration(
                  color: VineTheme.vineGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(
                    _ShareWithSection._avatarRadius,
                  ),
                ),
                child: const Center(
                  child: DivineIcon(
                    icon: DivineIconName.search,
                    color: VineTheme.vineGreen,
                  ),
                ),
              ),
              Text(
                context.l10n.shareFindPeopleMultiline,
                style: const TextStyle(
                  color: VineTheme.secondaryText,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactItem extends StatelessWidget {
  const _ContactItem({
    required this.user,
    required this.isSelected,
    required this.onTap,
  });

  final ShareableUser user;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: user.displayName ?? context.l10n.shareContactFallback,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: _ShareWithSection._itemWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Stack(
                children: [
                  UserAvatar(
                    imageUrl: user.picture,
                    name: user.displayName,
                    size: _ShareWithSection._avatarSize,
                  ),
                  if (isSelected)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: VineTheme.vineGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const DivineIcon(
                          icon: DivineIconName.check,
                          size: 14,
                          color: VineTheme.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                user.displayName ?? context.l10n.shareUserFallback,
                style: TextStyle(
                  color: isSelected
                      ? VineTheme.vineGreen
                      : VineTheme.secondaryText,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
