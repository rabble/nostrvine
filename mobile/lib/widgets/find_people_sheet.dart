// ABOUTME: Full-screen bottom sheet for searching and selecting a user.
// ABOUTME: Used by the share sheet to find recipients for video sharing via DM.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Full-screen bottom sheet for finding and selecting a user to share with.
///
/// Shows [contacts] (pre-loaded by the calling BLoC) initially, with search
/// functionality to find any Nostr user by name or npub.
/// Returns a [ShareableUser] when a user is selected.
class FindPeopleSheet extends ConsumerStatefulWidget {
  const FindPeopleSheet({
    required this.contacts,
    this.scrollController,
    this.searchTimeout = const Duration(seconds: 20),
    super.key,
  });

  /// Pre-loaded contacts from the parent share sheet BLoC.
  final List<ShareableUser> contacts;

  /// Scroll controller handed down by the enclosing [VineBottomSheet] so
  /// flinging the result list drags the sheet itself.
  final ScrollController? scrollController;

  /// Optional timeout forwarded to the internally created [UserSearchBloc].
  final Duration? searchTimeout;

  /// Fraction of the viewport the sheet occupies, matching the Figma spec
  /// (node 13945:91140) — tall enough for the list, short enough to leave
  /// the scrim visible above it.
  static const double _sheetHeightFraction = 0.92;

  @override
  ConsumerState<FindPeopleSheet> createState() => _FindPeopleSheetState();

  /// Show the find people sheet and return the selected user.
  ///
  /// [contacts] are passed from the calling BLoC so this sheet does not
  /// need to load them independently.
  static Future<ShareableUser?> show(
    BuildContext context, {
    List<ShareableUser> contacts = const [],
  }) {
    return VineBottomSheet.show<ShareableUser>(
      context: context,
      showHeader: false,
      showHeaderDivider: false,
      initialChildSize: _sheetHeightFraction,
      maxChildSize: _sheetHeightFraction,
      minChildSize: VineTheme.bottomSheetDismissFloor,
      buildScrollBody: (scrollController) => FindPeopleSheet(
        contacts: contacts,
        scrollController: scrollController,
      ),
    );
  }
}

class _FindPeopleSheetState extends ConsumerState<FindPeopleSheet> {
  final TextEditingController _searchController = TextEditingController();
  UserSearchBloc? _searchBloc;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final profileRepo = ref.read(profileRepositoryProvider);
    if (profileRepo != null) {
      _searchBloc = UserSearchBloc(
        profileRepository: profileRepo,
        searchTimeout: widget.searchTimeout,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            textInputAction: .search,
            style: VineTheme.bodyLargeFont(
              color: context.vineColors.primaryText,
            ),
            decoration: InputDecoration(
              hintText: context.l10n.shareFindPeople,
              hintStyle: VineTheme.bodyLargeFont(
                color: context.vineColors.secondaryText,
              ),
              prefixIconConstraints: const BoxConstraints(),
              prefixIcon: Padding(
                padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
                child: DivineIcon(
                  icon: DivineIconName.search,
                  color: context.vineColors.secondaryText,
                ),
              ),
              filled: true,
              fillColor: context.vineColors.containerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
            ),
            onChanged: _onSearchChanged,
          ),
        ),
        Expanded(
          // VineBottomSheet paints its surface with a ColoredBox, which would
          // hide the tiles' ink splashes without an own Material in between.
          child: Material(
            type: MaterialType.transparency,
            child: _ResultsList(
              searchQuery: _searchQuery,
              searchBloc: _searchBloc,
              contacts: widget.contacts,
              scrollController: widget.scrollController,
              onSelectUser: _selectUser,
            ),
          ),
        ),
        SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
      ],
    );
  }

  void _onSearchChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _searchBloc?.add(const UserSearchCleared());
    } else {
      _searchBloc?.add(UserSearchQueryChanged(value));
    }
    setState(() => _searchQuery = trimmed);
  }

  void _selectUser(ShareableUser user) {
    Navigator.of(context).pop(user);
  }

  @override
  void dispose() {
    _searchBloc?.close();
    _searchController.dispose();
    super.dispose();
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.searchQuery,
    required this.searchBloc,
    required this.contacts,
    required this.scrollController,
    required this.onSelectUser,
  });

  final String searchQuery;
  final UserSearchBloc? searchBloc;
  final List<ShareableUser> contacts;
  final ScrollController? scrollController;
  final ValueChanged<ShareableUser> onSelectUser;

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isNotEmpty && searchBloc != null) {
      return BlocBuilder<UserSearchBloc, UserSearchState>(
        bloc: searchBloc,
        builder: (context, state) {
          return switch (state.status) {
            UserSearchStatus.loading when state.results.isNotEmpty =>
              _SearchResultsList(
                results: state.results,
                scrollController: scrollController,
                onSelectUser: onSelectUser,
              ),
            UserSearchStatus.loading => Center(
              child: CircularProgressIndicator(
                color: context.vineColors.accentPositive,
              ),
            ),
            UserSearchStatus.success when state.results.isNotEmpty =>
              _SearchResultsList(
                results: state.results,
                scrollController: scrollController,
                onSelectUser: onSelectUser,
              ),
            UserSearchStatus.success => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.l10n.userSearchNoResults,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
              ),
            ),
            UserSearchStatus.failure => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  context.l10n.userPickerSearchFailedTryAgain,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
              ),
            ),
            UserSearchStatus.initial => _ContactsList(
              contacts: contacts,
              scrollController: scrollController,
              onSelectUser: onSelectUser,
            ),
          };
        },
      );
    }

    return _ContactsList(
      contacts: contacts,
      scrollController: scrollController,
      onSelectUser: onSelectUser,
    );
  }
}

/// The list of profiles matching the current search query.
class _SearchResultsList extends StatelessWidget {
  const _SearchResultsList({
    required this.results,
    required this.scrollController,
    required this.onSelectUser,
  });

  final List<UserProfile> results;
  final ScrollController? scrollController;
  final ValueChanged<ShareableUser> onSelectUser;

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.viewPaddingOf(context).bottom;
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.only(bottom: 16 + bottomSafeArea),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final user = ShareableUser.fromProfile(
          results[index].pubkey,
          results[index],
        );
        return _UserResultTile(user: user, onTap: () => onSelectUser(user));
      },
    );
  }
}

class _ContactsList extends StatelessWidget {
  const _ContactsList({
    required this.contacts,
    required this.scrollController,
    required this.onSelectUser,
  });

  final List<ShareableUser> contacts;
  final ScrollController? scrollController;
  final ValueChanged<ShareableUser> onSelectUser;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            context.l10n.findPeopleNoContacts,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final bottomSafeArea = MediaQuery.viewPaddingOf(context).bottom;
    return ListView.builder(
      controller: scrollController,
      padding: EdgeInsets.only(bottom: 16 + bottomSafeArea),
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        return _UserResultTile(
          user: contact,
          onTap: () => onSelectUser(contact),
        );
      },
    );
  }
}

class _UserResultTile extends StatelessWidget {
  const _UserResultTile({required this.user, required this.onTap});

  final ShareableUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final handle = user.handle;

    return ListTile(
      leading: UserAvatar(
        imageUrl: user.picture,
        placeholderSeed: user.pubkey,
        size: 48,
      ),
      title: Text(
        user.displayName ?? context.l10n.findPeopleAnonymousUser,
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      // No npub fallback: a row without a nip05 or a name shows the name
      // line only, matching the Figma spec and the new-message sheet.
      subtitle: handle == null
          ? null
          : Text(
              handle,
              style: VineTheme.bodyMediumFont(
                color: context.vineColors.secondaryText,
              ),
              overflow: TextOverflow.ellipsis,
            ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
