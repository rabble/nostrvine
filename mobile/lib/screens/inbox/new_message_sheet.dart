// ABOUTME: Bottom sheet for composing a new direct message
// ABOUTME: Shows searchable user list for selecting a DM recipient
// ABOUTME: Reuses UserSearchBloc for search and profile loading

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:profile_repository/profile_repository.dart';

/// A bottom sheet for selecting a recipient to start a new DM conversation.
///
/// Shows the user's followed contacts initially. Typing in the search
/// field queries for users by name or npub. Selecting a user returns
/// their [UserProfile] and dismisses the sheet.
///
/// Requires a [ProfileRepository] for searching users and an optional
/// [FollowRepository] for loading the user's followed contacts.
class NewMessageSheet extends StatefulWidget {
  const NewMessageSheet({
    required this.profileRepository,
    this.followRepository,
    super.key,
  });

  /// The profile repository used for user search and contact loading.
  final ProfileRepository profileRepository;

  /// The follow repository used for loading followed contacts.
  /// When null, the contacts list shows an empty state.
  final FollowRepository? followRepository;

  /// Shows the new message sheet and returns the selected [UserProfile].
  ///
  /// Returns null without showing the sheet if [profileRepository] is
  /// not available (e.g. during Nostr client initialization).
  static Future<UserProfile?> show(
    BuildContext context, {
    required ProfileRepository profileRepository,
    FollowRepository? followRepository,
  }) {
    return showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NewMessageSheet(
        profileRepository: profileRepository,
        followRepository: followRepository,
      ),
    );
  }

  @override
  State<NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<NewMessageSheet> {
  final _searchController = TextEditingController();
  late final UserSearchBloc _searchBloc;
  List<UserProfile> _contacts = [];
  List<UserProfile> _filteredContacts = [];
  bool _contactsLoaded = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchBloc = UserSearchBloc(
      profileRepository: widget.profileRepository,
      hasVideos: false,
    );
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final followRepo = widget.followRepository;
    if (followRepo == null) {
      setState(() => _contactsLoaded = true);
      return;
    }

    final pubkeys = followRepo.followingPubkeys;
    final futures = pubkeys.map(
      (pk) => widget.profileRepository.getCachedProfile(pubkey: pk),
    );
    final results = await Future.wait(futures);
    final profiles = results.whereType<UserProfile>().toList()
      ..sort(
        (a, b) => a.bestDisplayName.toLowerCase().compareTo(
          b.bestDisplayName.toLowerCase(),
        ),
      );

    if (mounted) {
      setState(() {
        _contacts = profiles;
        _filteredContacts = profiles;
        _contactsLoaded = true;
      });
    }
  }

  void _onSearchChanged(String value) {
    final trimmed = value.trim();
    setState(() => _searchQuery = trimmed);

    if (trimmed.isEmpty) {
      _searchBloc.add(const UserSearchCleared());
      setState(() => _filteredContacts = _contacts);
    } else {
      _searchBloc.add(UserSearchQueryChanged(value));
      setState(() {
        _filteredContacts = _contacts.where((profile) {
          final name = profile.bestDisplayName.toLowerCase();
          final nip05 = (profile.nip05 ?? '').toLowerCase();
          return name.contains(trimmed.toLowerCase()) ||
              nip05.contains(trimmed.toLowerCase());
        }).toList();
      });
    }
  }

  void _selectUser(UserProfile profile) {
    Navigator.of(context).pop(profile);
  }

  @override
  void dispose() {
    _searchBloc.close();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Material(
      color: VineTheme.surfaceBackground,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: SizedBox(
        height: screenHeight * 0.92,
        child: Column(
          children: [
            const _SheetHeader(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: _SearchField(
                controller: _searchController,
                onChanged: _onSearchChanged,
              ),
            ),
            Expanded(
              child: _searchQuery.isNotEmpty
                  ? _NetworkResults(
                      searchBloc: _searchBloc,
                      localResults: _filteredContacts,
                      onSelectUser: _selectUser,
                    )
                  : _ContactsList(
                      contacts: _filteredContacts,
                      isLoaded: _contactsLoaded,
                      onSelectUser: _selectUser,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 64,
          height: 4,
          decoration: BoxDecoration(
            color: VineTheme.onSurfaceDisabled,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'New message',
          style: VineTheme.titleMediumFont(fontSize: 16, height: 24 / 16),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, thickness: 1, color: VineTheme.outlineMuted),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: VineTheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.search, color: VineTheme.onSurfaceMuted, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              style: VineTheme.bodyLargeFont(),
              decoration: InputDecoration(
                hintText: 'Find people',
                hintStyle: VineTheme.bodyLargeFont(
                  color: VineTheme.onSurfaceMuted,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactsList extends StatelessWidget {
  const _ContactsList({
    required this.contacts,
    required this.isLoaded,
    required this.onSelectUser,
  });

  final List<UserProfile> contacts;
  final bool isLoaded;
  final ValueChanged<UserProfile> onSelectUser;

  @override
  Widget build(BuildContext context) {
    if (!isLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      );
    }

    if (contacts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No contacts found.\nFollow people to see them here.',
            style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: contacts.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        thickness: 1,
        color: VineTheme.outlineMuted,
        indent: 72,
      ),
      itemBuilder: (context, index) {
        final profile = contacts[index];
        return _UserTile(
          profile: profile,
          onTap: () => onSelectUser(profile),
        );
      },
    );
  }
}

class _NetworkResults extends StatelessWidget {
  const _NetworkResults({
    required this.searchBloc,
    required this.localResults,
    required this.onSelectUser,
  });

  final UserSearchBloc searchBloc;
  final List<UserProfile> localResults;
  final ValueChanged<UserProfile> onSelectUser;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserSearchBloc, UserSearchState>(
      bloc: searchBloc,
      builder: (context, state) {
        return switch (state.status) {
          UserSearchStatus.loading => const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          ),
          UserSearchStatus.success when state.results.isNotEmpty =>
            ListView.separated(
              itemCount: state.results.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 1,
                color: VineTheme.outlineMuted,
                indent: 72,
              ),
              itemBuilder: (context, index) {
                final profile = state.results[index];
                return _UserTile(
                  profile: profile,
                  onTap: () => onSelectUser(profile),
                );
              },
            ),
          UserSearchStatus.success => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'No users found',
                style: VineTheme.bodyMediumFont(
                  color: VineTheme.onSurfaceMuted,
                ),
              ),
            ),
          ),
          UserSearchStatus.failure => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Search failed. Please try again.',
                style: VineTheme.bodyMediumFont(
                  color: VineTheme.onSurfaceMuted,
                ),
              ),
            ),
          ),
          UserSearchStatus.initial => _ContactsList(
            contacts: localResults,
            isLoaded: true,
            onSelectUser: onSelectUser,
          ),
        };
      },
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.profile, required this.onTap});

  final UserProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: [
            UserAvatar(
              imageUrl: profile.picture,
              name: profile.bestDisplayName,
              size: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.bestDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VineTheme.titleMediumFont(
                      fontSize: 16,
                      height: 24 / 16,
                    ),
                  ),
                  if (profile.nip05 != null && profile.nip05!.isNotEmpty)
                    Text(
                      '@${profile.nip05}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VineTheme.bodyMediumFont(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
