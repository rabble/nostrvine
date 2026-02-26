// ABOUTME: Dialog for sending/sharing a video privately with another user
// ABOUTME: Extracted from share_video_menu.dart with UserSearchBloc-based search

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';

/// Dialog for sending video to a specific user via search or contacts.
class SendToUserDialog extends ConsumerStatefulWidget {
  const SendToUserDialog({required this.video, super.key});
  final VideoEvent video;

  @override
  ConsumerState<SendToUserDialog> createState() => _SendToUserDialogState();
}

class _SendToUserDialogState extends ConsumerState<SendToUserDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  UserSearchBloc? _searchBloc;
  List<ShareableUser> _contacts = [];
  bool _contactsLoaded = false;

  @override
  void initState() {
    super.initState();
    final profileRepo = ref.read(profileRepositoryProvider);
    if (profileRepo == null) {
      Log.error(
        'profileRepositoryProvider is null during initState',
        name: 'SendToUserDialog',
        category: LogCategory.ui,
      );
      return;
    }
    _searchBloc = UserSearchBloc(
      profileRepository: profileRepo,
      hasVideos: false,
    );
    _loadUserContacts();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: VineTheme.cardBackground,
    title: const Text(
      'Share with user',
      style: TextStyle(color: VineTheme.whiteText),
    ),
    content: SizedBox(
      width: double.maxFinite,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _searchController,
            enableInteractiveSelection: true,
            style: const TextStyle(color: VineTheme.whiteText),
            decoration: const InputDecoration(
              hintText: 'Search by name, npub, or pubkey...',
              hintStyle: TextStyle(color: VineTheme.secondaryText),
              prefixIcon: Icon(Icons.search, color: VineTheme.secondaryText),
            ),
            onChanged: (value) {
              if (value.trim().isEmpty) {
                _searchBloc?.add(const UserSearchCleared());
              } else {
                _searchBloc?.add(UserSearchQueryChanged(value));
              }
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _messageController,
            enableInteractiveSelection: true,
            style: const TextStyle(color: VineTheme.whiteText),
            decoration: const InputDecoration(
              hintText: 'Add a personal message (optional)',
              hintStyle: TextStyle(color: VineTheme.secondaryText),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          // Show contacts or search results
          if (!_contactsLoaded) ...[
            const Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            ),
          ] else if (_searchController.text.isEmpty &&
              _contacts.isNotEmpty) ...[
            // Show user's contacts when not searching
            const Text(
              'Your Contacts',
              style: TextStyle(
                color: VineTheme.whiteText,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: _contacts.length,
                itemBuilder: (context, index) =>
                    _buildUserTile(_contacts[index]),
              ),
            ),
          ] else if (_searchController.text.isEmpty && _contacts.isEmpty) ...[
            // No contacts found
            const Center(
              child: Text(
                'No contacts found. Start following people to see them here.',
                style: TextStyle(color: VineTheme.secondaryText),
                textAlign: TextAlign.center,
              ),
            ),
          ] else if (_searchController.text.isNotEmpty &&
              _searchBloc != null) ...[
            // Show search results from BLoC
            BlocBuilder<UserSearchBloc, UserSearchState>(
              bloc: _searchBloc,
              builder: (context, state) {
                return switch (state.status) {
                  UserSearchStatus.loading => const Center(
                    child: CircularProgressIndicator(
                      color: VineTheme.vineGreen,
                    ),
                  ),
                  UserSearchStatus.success when state.results.isNotEmpty =>
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Search Results',
                          style: TextStyle(
                            color: VineTheme.whiteText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            itemCount: state.results.length,
                            itemBuilder: (context, index) {
                              final profile = state.results[index];
                              return _buildUserTile(
                                ShareableUser(
                                  pubkey: profile.pubkey,
                                  displayName: profile.bestDisplayName,
                                  picture: profile.picture,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  UserSearchStatus.success => const Center(
                    child: Text(
                      'No users found. Try searching by name or public key.',
                      style: TextStyle(color: VineTheme.secondaryText),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  UserSearchStatus.failure => const Center(
                    child: Text(
                      'Search failed. Please try again.',
                      style: TextStyle(color: VineTheme.secondaryText),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  UserSearchStatus.initial => const SizedBox.shrink(),
                };
              },
            ),
          ],
        ],
      ),
    ),
    actions: [TextButton(onPressed: context.pop, child: const Text('Cancel'))],
  );

  /// Load user's contacts from their follow list (NIP-02)
  Future<void> _loadUserContacts() async {
    try {
      final followRepository = ref.read(followRepositoryProvider);
      final userProfileService = ref.read(userProfileServiceProvider);

      // Get the user's follow list
      final followList = followRepository?.followingPubkeys ?? [];
      final contacts = <ShareableUser>[];

      // Batch-fetch uncached profiles before building the list
      final uncachedPubkeys = followList
          .where((pk) => !userProfileService.hasProfile(pk))
          .toList();
      if (uncachedPubkeys.isNotEmpty) {
        await Future.wait(uncachedPubkeys.map(userProfileService.fetchProfile));
      }

      // Convert follows to ShareableUser objects with profile data
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
            name: 'SendToUserDialog',
            category: LogCategory.ui,
          );
          // Still add the contact without profile data
          contacts.add(
            ShareableUser(pubkey: pubkey),
          );
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
        'Error loading user contacts: $e',
        name: 'SendToUserDialog',
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

  /// Build a user tile for contacts or search results
  Widget _buildUserTile(ShareableUser user) {
    // Get user profile to check for nip05
    final userProfileService = ref.read(userProfileServiceProvider);
    final profile = userProfileService.getCachedProfile(user.pubkey);

    // Display nip05 if available, otherwise npub (never show raw hex)
    // Use normalizeToNpub to convert hex to npub format
    final displayId =
        profile?.nip05 ?? normalizeToNpub(user.pubkey) ?? user.pubkey;

    return ListTile(
      leading: UserAvatar(imageUrl: user.picture, size: 40),
      title: UserName.fromPubKey(
        user.pubkey,
        style: const TextStyle(color: VineTheme.whiteText),
        anonymousName: 'Anonymous',
      ),
      subtitle: Text(
        displayId,
        style: const TextStyle(color: VineTheme.secondaryText),
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _sendToUser(user),
      dense: true,
    );
  }

  Future<void> _sendToUser(ShareableUser user) async {
    try {
      final sharingService = ref.read(videoSharingServiceProvider);
      final result = await sharingService.shareVideoWithUser(
        video: widget.video,
        recipientPubkey: user.pubkey,
        personalMessage: _messageController.text.trim().isEmpty
            ? null
            : _messageController.text.trim(),
      );

      if (mounted) {
        context.pop(); // Close dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success
                  ? 'Video sent to ${user.displayName ?? 'user'}'
                  : 'Failed to send video: ${result.error}',
            ),
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to send video: $e',
        name: 'SendToUserDialog',
        category: LogCategory.ui,
      );
    }
  }

  @override
  void dispose() {
    _searchBloc?.close();
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}
