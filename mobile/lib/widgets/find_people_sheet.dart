// ABOUTME: Full-screen bottom sheet for searching and selecting a user.
// ABOUTME: Used by the share sheet to find recipients for video sharing via DM.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Full-screen bottom sheet for finding and selecting a user to share with.
///
/// Shows [contacts] (pre-loaded by the calling BLoC) initially, with search
/// functionality to find any Nostr user by name or npub.
/// Returns a [ShareableUser] when a user is selected.
class FindPeopleSheet extends ConsumerStatefulWidget {
  const FindPeopleSheet({
    required this.contacts,
    this.searchTimeout = const Duration(seconds: 20),
    super.key,
  });

  /// Pre-loaded contacts from the parent share sheet BLoC.
  final List<ShareableUser> contacts;

  /// Optional timeout forwarded to the internally created [UserSearchBloc].
  final Duration? searchTimeout;

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
    return showModalBottomSheet<ShareableUser>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: VineTheme.transparent,
      builder: (context) => FindPeopleSheet(contacts: contacts),
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
        hasVideos: false,
        searchTimeout: widget.searchTimeout,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Material(
      color: VineTheme.surfaceBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: SizedBox(
        height: screenHeight * 0.92,
        child: Column(
          children: [
            const _DragIndicator(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: VineTheme.whiteText),
                decoration: InputDecoration(
                  hintText: 'Find people',
                  hintStyle: const TextStyle(color: VineTheme.secondaryText),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: VineTheme.secondaryText,
                  ),
                  filled: true,
                  fillColor: VineTheme.containerLow,
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
              child: _ResultsList(
                searchQuery: _searchQuery,
                searchBloc: _searchBloc,
                contacts: widget.contacts,
                onSelectUser: _selectUser,
              ),
            ),
          ],
        ),
      ),
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

class _DragIndicator extends StatelessWidget {
  const _DragIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: VineTheme.secondaryText,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.searchQuery,
    required this.searchBloc,
    required this.contacts,
    required this.onSelectUser,
  });

  final String searchQuery;
  final UserSearchBloc? searchBloc;
  final List<ShareableUser> contacts;
  final ValueChanged<ShareableUser> onSelectUser;

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isNotEmpty && searchBloc != null) {
      return BlocBuilder<UserSearchBloc, UserSearchState>(
        bloc: searchBloc,
        builder: (context, state) {
          return switch (state.status) {
            UserSearchStatus.loading when state.results.isNotEmpty =>
              ListView.builder(
                itemCount: state.results.length,
                itemBuilder: (context, index) {
                  final profile = state.results[index];
                  final user = ShareableUser(
                    pubkey: profile.pubkey,
                    displayName: profile.bestDisplayName,
                    picture: profile.picture,
                  );
                  return _UserResultTile(
                    user: user,
                    nip05: profile.nip05,
                    onTap: () => onSelectUser(user),
                  );
                },
              ),
            UserSearchStatus.loading => const Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            ),
            UserSearchStatus.success when state.results.isNotEmpty =>
              ListView.builder(
                itemCount: state.results.length,
                itemBuilder: (context, index) {
                  final profile = state.results[index];
                  final user = ShareableUser(
                    pubkey: profile.pubkey,
                    displayName: profile.bestDisplayName,
                    picture: profile.picture,
                  );
                  return _UserResultTile(
                    user: user,
                    nip05: profile.nip05,
                    onTap: () => onSelectUser(user),
                  );
                },
              ),
            UserSearchStatus.success => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No users found',
                  style: TextStyle(color: VineTheme.secondaryText),
                ),
              ),
            ),
            UserSearchStatus.failure => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Search failed. Please try again.',
                  style: TextStyle(color: VineTheme.secondaryText),
                ),
              ),
            ),
            UserSearchStatus.initial => _ContactsList(
              contacts: contacts,
              onSelectUser: onSelectUser,
            ),
          };
        },
      );
    }

    return _ContactsList(contacts: contacts, onSelectUser: onSelectUser);
  }
}

class _ContactsList extends StatelessWidget {
  const _ContactsList({required this.contacts, required this.onSelectUser});

  final List<ShareableUser> contacts;
  final ValueChanged<ShareableUser> onSelectUser;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No contacts found.\nStart following people to see them here.',
            style: TextStyle(color: VineTheme.secondaryText),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
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

class _UserResultTile extends ConsumerWidget {
  const _UserResultTile({required this.user, required this.onTap, this.nip05});

  final ShareableUser user;
  final String? nip05;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayId = nip05 ?? normalizeToNpub(user.pubkey) ?? user.pubkey;

    return ListTile(
      leading: UserAvatar(imageUrl: user.picture, size: 48),
      title: Text(
        user.displayName ?? 'Anonymous',
        style: const TextStyle(
          color: VineTheme.whiteText,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        displayId.startsWith('npub') ? displayId : '@$displayId',
        style: const TextStyle(color: VineTheme.secondaryText),
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
