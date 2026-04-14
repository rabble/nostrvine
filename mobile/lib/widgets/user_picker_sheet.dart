// ABOUTME: Modal bottom sheet for searching and picking Nostr users
// ABOUTME: Supports filtering by mutual follows (fast local search)
// ABOUTME: or all users (network search) with mute-check validation

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  bool autoFocus = false,
  String searchText = 'Search by name',
  Set<String> excludePubkeys = const {},
}) {
  return VineBottomSheet.show<UserProfile>(
    context: context,
    initialChildSize: 1,
    maxChildSize: 1,
    minChildSize: 0.8,
    title: Column(
      spacing: 2,
      children: [
        Text(title, style: VineTheme.titleMediumFont()),
        Text(searchText, style: VineTheme.bodySmallFont()),
      ],
    ),
    buildScrollBody: (scrollController) => UserPickerSheet(
      filterMode: filterMode,
      scrollController: scrollController,
      autoFocus: autoFocus,
      excludePubkeys: excludePubkeys,
    ),
  );
}

/// A bottom sheet widget for searching and selecting a user.
class UserPickerSheet extends ConsumerStatefulWidget {
  /// Creates a user picker bottom sheet.
  const UserPickerSheet({
    required this.filterMode,
    this.scrollController,
    this.autoFocus = false,
    this.excludePubkeys = const {},
    super.key,
  });

  /// How to filter search results.
  final UserPickerFilterMode filterMode;

  /// Scroll controller for the draggable sheet.
  final ScrollController? scrollController;

  final bool autoFocus;

  /// Pubkeys to exclude from search results (already selected users).
  final Set<String> excludePubkeys;

  @override
  ConsumerState<UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends ConsumerState<UserPickerSheet> {
  UserSearchBloc? _searchBloc;
  final _searchController = TextEditingController();

  // For mutualFollowsOnly: local follow list search
  List<UserProfile> _followProfiles = [];
  List<UserProfile> _filteredFollowProfiles = [];
  bool _followListLoaded = false;

  /// Whether the profile repository was unavailable at init time.
  bool _profileRepoMissing = false;

  bool get _useLocalSearch =>
      widget.filterMode == UserPickerFilterMode.mutualFollowsOnly;

  @override
  void initState() {
    super.initState();
    final profileRepo = ref.read(profileRepositoryProvider);
    if (profileRepo == null) {
      _profileRepoMissing = true;
      return;
    }
    _searchBloc = UserSearchBloc(profileRepository: profileRepo);

    if (_useLocalSearch) {
      _loadFollowProfiles();
    }
  }

  /// Loads profiles of followed users from local cache for instant search.
  Future<void> _loadFollowProfiles() async {
    final followRepo = ref.read(followRepositoryProvider);
    final profileRepo = ref.read(profileRepositoryProvider);
    if (profileRepo == null) {
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
      // Keep all profiles including excluded ones — excluded users are shown
      // as disabled in the UI rather than being filtered out entirely.
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
    _searchBloc?.close();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_useLocalSearch) {
      _filterFollowProfiles(query);
    } else {
      if (query.trim().isEmpty) {
        _searchBloc?.add(const UserSearchCleared());
      } else {
        _searchBloc?.add(UserSearchQueryChanged(query));
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
    if (_profileRepoMissing) {
      return const _ProfileRepoUnavailable();
    }

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
            margin: const .fromLTRB(16, 16, 16, 4),
            decoration: BoxDecoration(
              color: VineTheme.surfaceContainer,
              borderRadius: .circular(20),
            ),
            child: TextField(
              autofocus: widget.autoFocus,
              controller: _searchController,
              textInputAction: .search,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchChanged,
              cursorColor: VineTheme.vineGreen,
              style: VineTheme.bodyLargeFont(
                color: VineTheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: VineTheme.bodyLargeFont(
                  color: VineTheme.onSurfaceMuted,
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
              ? _LocalResults(
                  scrollController: widget.scrollController,
                  followListLoaded: _followListLoaded,
                  followProfiles: _followProfiles,
                  filteredFollowProfiles: _filteredFollowProfiles,
                  onUserSelected: _onUserSelected,
                  excludePubkeys: widget.excludePubkeys,
                )
              : _NetworkResults(
                  searchBloc: _searchBloc!,
                  scrollController: widget.scrollController,
                  onUserSelected: _onUserSelected,
                  excludePubkeys: widget.excludePubkeys,
                ),
        ),

        SizedBox(height: MediaQuery.viewInsetsOf(context).bottom),
      ],
    );
  }
}

/// A tile displaying a user profile in the search results.
class _UserSearchTile extends StatelessWidget {
  const _UserSearchTile({
    required this.profile,
    required this.onTap,
    this.isDisabled = false,
  });

  final UserProfile profile;
  final VoidCallback onTap;

  /// Whether this user is already selected and cannot be tapped.
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final textColor = isDisabled
        ? VineTheme.onSurfaceMuted
        : VineTheme.onSurface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        spacing: 16,
        children: [
          Opacity(
            opacity: isDisabled ? 0.5 : 1.0,
            child: UserAvatar(
              imageUrl: profile.picture,
              name: profile.bestDisplayName,
              size: 40,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  profile.bestDisplayName,
                  maxLines: 1,
                  overflow: .ellipsis,
                  style: VineTheme.titleMediumFont(color: textColor),
                ),
                if (profile.nip05 != null && profile.nip05!.isNotEmpty)
                  Text(
                    profile.nip05!,
                    maxLines: 1,
                    overflow: .ellipsis,
                    style: VineTheme.bodyMediumFont(color: textColor),
                  ),
              ],
            ),
          ),

          Semantics(
            button: !isDisabled,
            label: isDisabled
                ? '${profile.bestDisplayName} already added'
                : 'Select ${profile.bestDisplayName}',
            child: InkWell(
              onTap: isDisabled ? null : onTap,
              child: Container(
                padding: const .all(8),
                decoration: ShapeDecoration(
                  color: isDisabled
                      ? VineTheme.surfaceContainer
                      : VineTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: .circular(16)),
                ),
                child: DivineIcon(
                  icon: isDisabled ? .check : .plus,
                  color: isDisabled
                      ? VineTheme.onSurfaceMuted
                      : VineTheme.onPrimary,
                ),
              ),
            ),
          ),
        ],
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
                    side: const BorderSide(
                      width: 2,
                      color: VineTheme.outlineMuted,
                    ),
                    borderRadius: .circular(20),
                  ),
                ),
                child: Text(
                  'Go back',
                  textAlign: TextAlign.center,
                  style: VineTheme.titleMediumFont(color: VineTheme.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Type a name to search',
          style: VineTheme.bodyMediumFont(
            color: VineTheme.onSurfaceMuted,
          ),
        ),
      ),
    );
  }
}

class _ProfileRepoUnavailable extends StatelessWidget {
  const _ProfileRepoUnavailable();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'User search is unavailable. Please try again later.',
          style: VineTheme.bodyMediumFont(
            color: VineTheme.onSurfaceMuted,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Search failed. Please try again.',
          style: VineTheme.bodyMediumFont(
            color: VineTheme.onSurfaceMuted,
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'No users found',
          style: VineTheme.bodyMediumFont(
            color: VineTheme.onSurfaceMuted,
          ),
        ),
      ),
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.scrollController,
    required this.results,
    required this.onUserSelected,
    this.excludePubkeys = const {},
  });

  final ScrollController? scrollController;
  final List<UserProfile> results;
  final ValueChanged<UserProfile> onUserSelected;
  final Set<String> excludePubkeys;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: scrollController,
      itemCount: results.length,
      padding: .fromLTRB(
        0,
        32,
        0,
        32 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      separatorBuilder: (context, index) => const Divider(
        height: 40,
        thickness: 1,
        color: VineTheme.outlineDisabled,
      ),
      itemBuilder: (context, index) {
        final profile = results[index];
        final isDisabled = excludePubkeys.contains(profile.pubkey);
        return _UserSearchTile(
          profile: profile,
          onTap: () => onUserSelected(profile),
          isDisabled: isDisabled,
        );
      },
    );
  }
}

class _NetworkResults extends StatelessWidget {
  const _NetworkResults({
    required this.searchBloc,
    required this.scrollController,
    required this.onUserSelected,
    this.excludePubkeys = const {},
  });

  final UserSearchBloc searchBloc;
  final ScrollController? scrollController;
  final ValueChanged<UserProfile> onUserSelected;
  final Set<String> excludePubkeys;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserSearchBloc, UserSearchState>(
      bloc: searchBloc,
      builder: (context, state) {
        return switch (state.status) {
          UserSearchStatus.initial => const _EmptyHint(),
          UserSearchStatus.loading => const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          ),
          UserSearchStatus.failure => const _ErrorState(),
          UserSearchStatus.success => () {
            return state.results.isEmpty
                ? const _NoResults()
                : _ResultsList(
                    scrollController: scrollController,
                    results: state.results,
                    onUserSelected: onUserSelected,
                    excludePubkeys: excludePubkeys,
                  );
          }(),
        };
      },
    );
  }
}

class _LocalResults extends StatelessWidget {
  const _LocalResults({
    required this.scrollController,
    required this.followListLoaded,
    required this.followProfiles,
    required this.filteredFollowProfiles,
    required this.onUserSelected,
    this.excludePubkeys = const {},
  });

  final ScrollController? scrollController;
  final bool followListLoaded;
  final List<UserProfile> followProfiles;
  final List<UserProfile> filteredFollowProfiles;
  final ValueChanged<UserProfile> onUserSelected;
  final Set<String> excludePubkeys;

  @override
  Widget build(BuildContext context) {
    if (!followListLoaded) {
      return const Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      );
    }

    if (followProfiles.isEmpty) {
      return const _EmptyFollowList();
    }

    if (filteredFollowProfiles.isEmpty) {
      return const _NoResults();
    }

    return ListView.separated(
      controller: scrollController,
      itemCount: filteredFollowProfiles.length,
      padding: .fromLTRB(
        0,
        32,
        0,
        32 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      separatorBuilder: (context, index) => const Divider(
        height: 40,
        thickness: 1,
        color: VineTheme.outlineDisabled,
      ),
      itemBuilder: (context, index) {
        final profile = filteredFollowProfiles[index];
        final isDisabled = excludePubkeys.contains(profile.pubkey);
        return _UserSearchTile(
          profile: profile,
          onTap: () => onUserSelected(profile),
          isDisabled: isDisabled,
        );
      },
    );
  }
}
