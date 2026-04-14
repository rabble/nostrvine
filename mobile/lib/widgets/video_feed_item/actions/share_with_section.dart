part of 'share_action_button.dart';

// ---------------------------------------------------------------------------
// "Share with" horizontal contact row
// ---------------------------------------------------------------------------

class _ShareWithSection extends StatelessWidget {
  const _ShareWithSection({
    required this.contacts,
    required this.contactsLoaded,
    required this.selectedRecipient,
    required this.sentPubkeys,
    required this.onFindPeople,
    required this.onContactTapped,
  });

  final List<ShareableUser> contacts;
  final bool contactsLoaded;
  final ShareableUser? selectedRecipient;
  final Set<String> sentPubkeys;
  final VoidCallback onFindPeople;
  final ValueChanged<ShareableUser> onContactTapped;

  static const double _itemWidth = 72;
  static const double _avatarSize = 48;
  static const double _avatarRadius = _avatarSize * 0.286;
  static const double _rowHeight = 90;

  @override
  Widget build(BuildContext context) {
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
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              // +1 for Find People; when loading, +1 more for the spinner
              itemCount: contactsLoaded
                  ? contacts.length + 1
                  : 2, // Find People + spinner
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _FindPeopleItem(onTap: onFindPeople);
                }

                if (!contactsLoaded) {
                  return const _ContactsLoadingItem();
                }

                final contact = contacts[index - 1];
                final isSelected = selectedRecipient?.pubkey == contact.pubkey;
                final isSent = sentPubkeys.contains(contact.pubkey);

                return _ContactItem(
                  user: contact,
                  isSelected: isSelected,
                  isSent: isSent,
                  onTap: () => onContactTapped(contact),
                );
              },
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

/// Shown in the contacts row while contacts are still loading.
class _ContactsLoadingItem extends StatelessWidget {
  const _ContactsLoadingItem();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: _ShareWithSection._itemWidth,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: VineTheme.vineGreen,
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
    required this.isSent,
    required this.onTap,
  });

  final ShareableUser user;
  final bool isSelected;
  final bool isSent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: user.displayName ?? context.l10n.shareContactFallback,
      child: GestureDetector(
        onTap: isSent ? null : onTap,
        child: SizedBox(
          width: _ShareWithSection._itemWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Stack(
                children: [
                  Opacity(
                    opacity: isSent ? 0.5 : 1.0,
                    child: UserAvatar(
                      imageUrl: user.picture,
                      name: user.displayName,
                      size: _ShareWithSection._avatarSize,
                    ),
                  ),
                  if (isSelected || isSent)
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
                        child: const Icon(
                          Icons.check,
                          size: 14,
                          color: VineTheme.onPrimary,
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                isSent
                    ? context.l10n.shareSent
                    : (user.displayName ?? context.l10n.shareUserFallback),
                style: TextStyle(
                  color: (isSelected || isSent)
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
