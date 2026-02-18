// ABOUTME: Modal bottom sheet for searching and picking Nostr users
// ABOUTME: Supports filtering by mutual follows (fast local search)
// ABOUTME: or all users (network search) with mute-check validation

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
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
  required String title,
  String searchText = 'Search by name',
}) {
  return VineBottomSheet.show<UserProfile>(
    context: context,
    initialChildSize: 1,
    maxChildSize: 1,
    minChildSize: 1,
    title: Column(
      spacing: 2,
      children: [
        Text(
          title,
          style: VineTheme.titleMediumFont(fontSize: 16, height: 1.5),
        ),
        Text(searchText, style: VineTheme.bodySmallFont()),
      ],
    ),
    buildScrollBody: (scrollController) => UserPickerSheet(
      filterMode: filterMode,
      scrollController: scrollController,
    ),
  );
}

/// A bottom sheet widget for searching and selecting a user.
class UserPickerSheet extends ConsumerStatefulWidget {
  /// Creates a user picker bottom sheet.
  const UserPickerSheet({
    required this.filterMode,
    this.scrollController,
    super.key,
  });

  /// How to filter search results.
  final UserPickerFilterMode filterMode;

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
    final hintText = _useLocalSearch
        ? 'Filter by name...'
        : 'Search by name...';

    return Column(
      children: [
        // Search field
        Semantics(
          textField: true,
          label: hintText,
          child: Container(
            margin: .fromLTRB(16, 16, 16, 4),
            decoration: BoxDecoration(
              color: VineTheme.surfaceContainer,
              borderRadius: .circular(20),
            ),
            child: TextField(
              controller: _searchController,
              textInputAction: .search,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchChanged,
              cursorColor: VineTheme.vineGreen,
              style: VineTheme.bodyFont(
                color: VineTheme.onSurface,
                fontSize: 16,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: VineTheme.bodyFont(
                  color: VineTheme.onSurfaceMuted,
                  fontSize: 16,
                  height: 1.5,
                ),
                prefixIcon: const Padding(
                  padding: .only(left: 16, right: 8),
                  child: Icon(
                    Icons.search,
                    color: VineTheme.onSurfaceMuted,
                    size: 24,
                  ),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                contentPadding: const .symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),

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
      return _EmptyFollowList();
    }

    if (_filteredFollowProfiles.isEmpty) {
      return _buildNoResults();
    }

    return ListView.separated(
      controller: widget.scrollController,
      itemCount: _filteredFollowProfiles.length,
      padding: const .symmetric(vertical: 32),
      separatorBuilder: (context, index) =>
          Divider(height: 40, thickness: 1, color: VineTheme.outlineDisabled),
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
    return ListView.separated(
      controller: widget.scrollController,
      itemCount: state.results.length,
      padding: const .symmetric(vertical: 32),
      separatorBuilder: (context, index) =>
          Divider(height: 40, thickness: 1, color: VineTheme.outlineDisabled),
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
    return Semantics(
      button: true,
      label: 'Select ${profile.bestDisplayName}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            spacing: 16,
            children: [
              UserAvatar(
                imageUrl: profile.picture,
                name: profile.bestDisplayName,
                size: 40,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: .start,
                  children: [
                    Text(
                      profile.bestDisplayName,
                      maxLines: 1,
                      overflow: .ellipsis,
                      style: VineTheme.titleMediumFont(
                        fontSize: 16,
                        color: VineTheme.onSurface,
                      ),
                    ),
                    if (profile.nip05 != null && profile.nip05!.isNotEmpty)
                      Text(
                        profile.nip05!,
                        maxLines: 1,
                        overflow: .ellipsis,
                        style: VineTheme.bodyMediumFont(
                          color: VineTheme.onSurface,
                        ),
                      ),
                  ],
                ),
              ),

              Container(
                padding: const .all(8),
                decoration: ShapeDecoration(
                  color: VineTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: .circular(16)),
                ),
                child: SvgPicture.asset(
                  'assets/icon/plus.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const .mode(VineTheme.onPrimary, .srcIn),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFollowList extends StatelessWidget {
  const _EmptyFollowList();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: .center,
        children: [
          Text(
            'Your crew is out there',
            style: VineTheme.headlineSmallFont(color: VineTheme.onSurface),
            textAlign: .center,
          ),
          const SizedBox(height: 8),
          Text(
            'Follow people you vibe with. '
            'When they follow back, you can collab.',
            style: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceVariant),
            textAlign: .center,
          ),
          const SizedBox(height: 32),
          Semantics(
            button: true,
            label: 'Go back',
            child: InkWell(
              onTap: context.pop,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const .symmetric(horizontal: 24, vertical: 12),
                decoration: ShapeDecoration(
                  color: VineTheme.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(width: 2, color: VineTheme.outlineMuted),
                    borderRadius: .circular(20),
                  ),
                ),
                child: Text(
                  'Go back',
                  textAlign: TextAlign.center,
                  style: VineTheme.titleMediumFont(
                    fontSize: 16,
                    color: VineTheme.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
