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
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Full-screen bottom sheet for finding and selecting a user to share with.
///
/// Shows the user's contacts initially, with search functionality to find
/// any Nostr user. Returns a [ShareableUser] when a user is selected.
class FindPeopleSheet extends ConsumerStatefulWidget {
  const FindPeopleSheet({super.key});

  @override
  ConsumerState<FindPeopleSheet> createState() => _FindPeopleSheetState();

  /// Show the find people sheet and return the selected user.
  static Future<ShareableUser?> show(BuildContext context) {
    return showModalBottomSheet<ShareableUser>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FindPeopleSheet(),
    );
  }
}

class _FindPeopleSheetState extends ConsumerState<FindPeopleSheet> {
  final TextEditingController _searchController = TextEditingController();
  UserSearchBloc? _searchBloc;
  List<ShareableUser> _contacts = [];
  bool _contactsLoaded = false;

  @override
  void initState() {
    super.initState();
    final profileRepo = ref.read(profileRepositoryProvider);
    if (profileRepo != null) {
      _searchBloc = UserSearchBloc(
        profileRepository: profileRepo,
        hasVideos: false,
      );
    }
    _loadContacts();
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
            Expanded(child: _buildResultsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    if (!_contactsLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      );
    }

    if (_searchController.text.isNotEmpty && _searchBloc != null) {
      return BlocBuilder<UserSearchBloc, UserSearchState>(
        bloc: _searchBloc,
        builder: (context, state) {
          return switch (state.status) {
            UserSearchStatus.loading => const Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            ),
            UserSearchStatus.success when state.results.isNotEmpty =>
              ListView.builder(
                itemCount: state.results.length,
                itemBuilder: (context, index) {
                  final profile = state.results[index];
                  return _UserResultTile(
                    user: ShareableUser(
                      pubkey: profile.pubkey,
                      displayName: profile.bestDisplayName,
                      picture: profile.picture,
                    ),
                    nip05: profile.nip05,
                    onTap: () => _selectUser(
                      ShareableUser(
                        pubkey: profile.pubkey,
                        displayName: profile.bestDisplayName,
                        picture: profile.picture,
                      ),
                    ),
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
            UserSearchStatus.initial => _buildContactsList(),
          };
        },
      );
    }

    return _buildContactsList();
  }

  Widget _buildContactsList() {
    if (_contacts.isEmpty) {
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
      itemCount: _contacts.length,
      itemBuilder: (context, index) {
        final contact = _contacts[index];
        final userProfileService = ref.read(userProfileServiceProvider);
        final profile = userProfileService.getCachedProfile(contact.pubkey);

        return _UserResultTile(
          user: contact,
          nip05: profile?.nip05,
          onTap: () => _selectUser(contact),
        );
      },
    );
  }

  void _onSearchChanged(String value) {
    if (value.trim().isEmpty) {
      _searchBloc?.add(const UserSearchCleared());
    } else {
      _searchBloc?.add(UserSearchQueryChanged(value));
    }
    setState(() {});
  }

  void _selectUser(ShareableUser user) {
    Navigator.of(context).pop(user);
  }

  Future<void> _loadContacts() async {
    try {
      final followRepository = ref.read(followRepositoryProvider);
      final userProfileService = ref.read(userProfileServiceProvider);

      final followList = followRepository?.followingPubkeys ?? [];
      final contacts = <ShareableUser>[];

      final uncachedPubkeys = followList
          .where((pk) => !userProfileService.hasProfile(pk))
          .toList();
      if (uncachedPubkeys.isNotEmpty) {
        await Future.wait(uncachedPubkeys.map(userProfileService.fetchProfile));
      }

      for (final pubkey in followList) {
        try {
          final profile = userProfileService.getCachedProfile(pubkey);
          contacts.add(
            ShareableUser(
              pubkey: pubkey,
              displayName: profile?.bestDisplayName,
              picture: profile?.picture,
            ),
          );
        } catch (e) {
          Log.error(
            'Error loading contact profile $pubkey: $e',
            name: 'FindPeopleSheet',
            category: LogCategory.ui,
          );
          contacts.add(ShareableUser(pubkey: pubkey));
        }
      }

      if (mounted) {
        setState(() {
          _contacts = contacts;
          _contactsLoaded = true;
        });
      }
    } catch (e) {
      Log.error(
        'Error loading contacts: $e',
        name: 'FindPeopleSheet',
        category: LogCategory.ui,
      );
      if (mounted) {
        setState(() {
          _contacts = [];
          _contactsLoaded = true;
        });
      }
    }
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
