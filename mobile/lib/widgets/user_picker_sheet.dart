// ABOUTME: Modal bottom sheet for searching and picking Nostr users
// ABOUTME: Supports filtering by mutual follows (fast local search)
// ABOUTME: or all users (network search) with mute-check validation

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Filter mode for user search in [UserPickerSheet].
enum UserPickerFilterMode {
  /// Only users with mutual follow (for collaborators).
  mutualFollowsOnly,

  /// All users (for Inspired By).
  allUsers,
}

/// Shows a [UserPickerSheet] as a modal bottom sheet.
///
/// Returns the selected [UserProfile] or null if dismissed.
Future<UserProfile?> showUserPickerSheet(
  BuildContext context, {
  required UserPickerFilterMode filterMode,
  String? title,
}) {
  return showModalBottomSheet<UserProfile>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VineTheme.backgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) => UserPickerSheet(
        filterMode: filterMode,
        title: title,
        scrollController: scrollController,
      ),
    ),
  );
}

/// A bottom sheet widget for searching and selecting a user.
class UserPickerSheet extends ConsumerStatefulWidget {
  /// Creates a user picker bottom sheet.
  const UserPickerSheet({
    required this.filterMode,
    this.title,
    this.scrollController,
    super.key,
  });

  /// How to filter search results.
  final UserPickerFilterMode filterMode;

  /// Optional title displayed at the top.
  final String? title;

  /// Scroll controller for the draggable sheet.
  final ScrollController? scrollController;

  @override
  ConsumerState<UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends ConsumerState<UserPickerSheet> {
  late final UserSearchBloc _searchBloc;
  final _searchController = TextEditingController();

  // For mutualFollowsOnly: local follow list search
  List<UserProfile> _followProfiles = [];
  List<UserProfile> _filteredFollowProfiles = [];
  bool _followListLoaded = false;

  bool get _useLocalSearch =>
      widget.filterMode == UserPickerFilterMode.mutualFollowsOnly;

  @override
  void initState() {
    super.initState();
    final profileRepo = ref.read(profileRepositoryProvider);
    _searchBloc = UserSearchBloc(profileRepository: profileRepo!);

    if (_useLocalSearch) {
      _loadFollowProfiles();
    }
  }

  /// Loads profiles of followed users from local cache for instant search.
  Future<void> _loadFollowProfiles() async {
    final followRepo = ref.read(followRepositoryProvider);
    final profileRepo = ref.read(profileRepositoryProvider);
    if (followRepo == null || profileRepo == null) {
      setState(() => _followListLoaded = true);
      return;
    }

    final pubkeys = followRepo.followingPubkeys;

    // Batch-load profiles from SQLite cache (fast, no network)
    final futures = pubkeys.map(
      (pk) => profileRepo.getCachedProfile(pubkey: pk),
    );
    final results = await Future.wait(futures);

    final profiles = results.whereType<UserProfile>().toList();

    // Sort by display name for a nice default list
    profiles.sort(
      (a, b) => a.bestDisplayName.toLowerCase().compareTo(
        b.bestDisplayName.toLowerCase(),
      ),
    );

    if (mounted) {
      setState(() {
        _followProfiles = profiles;
        _filteredFollowProfiles = profiles;
        _followListLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchBloc.close();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_useLocalSearch) {
      _filterFollowProfiles(query);
    } else {
      if (query.trim().isEmpty) {
        _searchBloc.add(const UserSearchCleared());
      } else {
        _searchBloc.add(UserSearchQueryChanged(query));
      }
    }
  }

  void _filterFollowProfiles(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      setState(() => _filteredFollowProfiles = _followProfiles);
      return;
    }

    setState(() {
      _filteredFollowProfiles = _followProfiles.where((profile) {
        final name = profile.bestDisplayName.toLowerCase();
        final nip05 = (profile.nip05 ?? '').toLowerCase();
        return name.contains(trimmed) || nip05.contains(trimmed);
      }).toList();
    });
  }

  void _onUserSelected(UserProfile profile) {
    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    final defaultTitle =
        widget.filterMode == UserPickerFilterMode.mutualFollowsOnly
        ? 'Add collaborator'
        : 'Search users';

    return Column(
      children: [
        // Drag handle
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: VineTheme.onSurfaceMuted,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),

        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            widget.title ?? defaultTitle,
            style: VineTheme.bodyFont(
              color: VineTheme.whiteText,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.33,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Search field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DivineTextField(
            controller: _searchController,
            label: _useLocalSearch ? 'Filter by name' : 'Search by name',
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
          ),
        ),
        const SizedBox(height: 8),

        // Results list
        Expanded(
          child: _useLocalSearch
              ? _buildLocalResults()
              : _buildNetworkResults(),
        ),
      ],
    );
  }

  /// Builds the results list for local follow-list search.
  Widget _buildLocalResults() {
    if (!_followListLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      );
    }

    if (_followProfiles.isEmpty) {
      return _buildEmptyFollowList();
    }

    if (_filteredFollowProfiles.isEmpty) {
      return _buildNoResults();
    }

    return ListView.builder(
      controller: widget.scrollController,
      itemCount: _filteredFollowProfiles.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final profile = _filteredFollowProfiles[index];
        return _UserSearchTile(
          profile: profile,
          onTap: () => _onUserSelected(profile),
        );
      },
    );
  }

  /// Builds the results list using the network search BLoC.
  Widget _buildNetworkResults() {
    return BlocBuilder<UserSearchBloc, UserSearchState>(
      bloc: _searchBloc,
      builder: (context, state) {
        return switch (state.status) {
          UserSearchStatus.initial => _buildEmptyHint(),
          UserSearchStatus.loading => const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          ),
          UserSearchStatus.failure => _buildErrorState(),
          UserSearchStatus.success =>
            state.results.isEmpty
                ? _buildNoResults()
                : _buildResultsList(state),
        };
      },
    );
  }

  Widget _buildEmptyHint() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Type a name to search',
          style: VineTheme.bodyFont(
            color: VineTheme.onSurfaceMuted,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFollowList() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No followed users found',
          style: VineTheme.bodyFont(
            color: VineTheme.onSurfaceMuted,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Search failed. Please try again.',
          style: VineTheme.bodyFont(
            color: VineTheme.onSurfaceMuted,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No users found',
          style: VineTheme.bodyFont(
            color: VineTheme.onSurfaceMuted,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList(UserSearchState state) {
    return ListView.builder(
      controller: widget.scrollController,
      itemCount: state.results.length,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemBuilder: (context, index) {
        final profile = state.results[index];
        return _UserSearchTile(
          profile: profile,
          onTap: () => _onUserSelected(profile),
        );
      },
    );
  }
}

/// A tile displaying a user profile in the search results.
class _UserSearchTile extends StatelessWidget {
  const _UserSearchTile({required this.profile, required this.onTap});

  final UserProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            UserAvatar(
              imageUrl: profile.picture,
              name: profile.bestDisplayName,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.bestDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VineTheme.bodyFont(
                      color: VineTheme.whiteText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.33,
                    ),
                  ),
                  if (profile.nip05 != null && profile.nip05!.isNotEmpty)
                    Text(
                      profile.nip05!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VineTheme.bodyFont(
                        color: VineTheme.onSurfaceMuted,
                        fontSize: 12,
                        height: 1.33,
                      ),
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
