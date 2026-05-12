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
import 'package:openvine/l10n/l10n.dart';
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
Future<List<UserProfile>?> showUserPickerSheet(
  BuildContext context, {
  required UserPickerFilterMode filterMode,
  required String title,
  bool autoFocus = false,
  String? searchText,
  String? searchHint,
  ValueChanged<UserProfile>? onUserToggled,
  int? maxCount,
  Set<String> excludePubkeys = const {},
  List<UserProfile> initialSelectedProfiles = const [],
}) {
  return VineBottomSheet.show<List<UserProfile>?>(
    context: context,
    initialChildSize: 1,
    maxChildSize: 1,
    minChildSize: 0.8,
    showDragHandle: false,
    showHeader: false,
    buildScrollBody: (scrollController) => UserPickerSheet(
      filterMode: filterMode,
      scrollController: scrollController,
      autoFocus: autoFocus,
      title: title,
      searchText: searchText,
      maxCount: maxCount,
      excludePubkeys: excludePubkeys,
      searchHint: searchHint,
      onUserToggled: onUserToggled,
      initialSelectedProfiles: initialSelectedProfiles,
    ),
  );
}

/// A bottom sheet widget for searching and selecting a user.
class UserPickerSheet extends ConsumerStatefulWidget {
  /// Creates a user picker bottom sheet.
  const UserPickerSheet({
    required this.filterMode,
    required this.title,
    this.scrollController,
    this.autoFocus = false,
    this.searchText,
    this.maxCount,
    this.excludePubkeys = const {},
    this.searchHint,
    this.onUserToggled,
    this.initialSelectedProfiles = const [],
    super.key,
  });

  /// How to filter search results.
  final UserPickerFilterMode filterMode;

  /// Title shown in the header.
  final String title;

  /// Optional helper text shown below the title in the header.
  final String? searchText;

  /// Optional maximum selectable count shown in the header as
  /// "selected/max title".
  final int? maxCount;

  /// Scroll controller for the draggable sheet.
  final ScrollController? scrollController;

  final bool autoFocus;

  /// Pubkeys to exclude from search results (already selected users).
  final Set<String> excludePubkeys;

  /// Optional override for the search field hint text.
  final String? searchHint;

  /// When provided, tapping a user calls this callback instead of popping
  /// the sheet. Use this for multi-select flows where the sheet should stay
  /// open. Selected users should be tracked by the caller and reflected via
  /// [excludePubkeys] (they will appear in the checked state).
  final ValueChanged<UserProfile>? onUserToggled;

  /// Profiles pre-selected when the sheet opens.
  final List<UserProfile> initialSelectedProfiles;

  @override
  ConsumerState<UserPickerSheet> createState() => _UserPickerSheetState();
}

class _UserPickerSheetState extends ConsumerState<UserPickerSheet> {
  static const _searchInputBorderRadius = 20.0;

  UserSearchBloc? _searchBloc;
  final _searchController = TextEditingController();

  // For mutualFollowsOnly: local follow list search
  List<UserProfile> _followProfiles = [];
  List<UserProfile> _filteredFollowProfiles = [];
  bool _followListLoaded = false;
  final _selectedProfiles = <UserProfile>[];

  /// Whether the profile repository was unavailable at init time.
  bool _profileRepoMissing = false;

  /// Tracks selected pubkeys locally so toggling is reflected immediately.
  /// Initialised from [widget.excludePubkeys] so pre-selected users show
  /// as checked from the start.
  late Set<String> _selectedPubkeys;

  bool get _useLocalSearch =>
      widget.filterMode == UserPickerFilterMode.mutualFollowsOnly;

  @override
  void initState() {
    super.initState();
    _selectedPubkeys = {
      ...widget.excludePubkeys,
      for (final profile in widget.initialSelectedProfiles) profile.pubkey,
    };
    if (widget.initialSelectedProfiles.isNotEmpty) {
      _selectedProfiles.addAll(widget.initialSelectedProfiles);
    }
    final profileRepo = ref.read(profileRepositoryProvider);
    if (profileRepo == null) {
      _profileRepoMissing = true;
      return;
    }
    _searchBloc = UserSearchBloc(
      profileRepository: profileRepo,
      followRepository: ref.read(followRepositoryProvider),
    );

    if (_useLocalSearch) {
      _loadFollowProfiles();
    }
  }

  /// Loads profiles of followed users for local search.
  ///
  /// For [UserPickerFilterMode.mutualFollowsOnly], fetches the current user's
  /// followers from the relay in parallel with profile loading, then filters
  /// the list to actual mutual follows. This way the mutual-follow check
  /// happens once when the sheet opens rather than per-profile after selection.
  Future<void> _loadFollowProfiles() async {
    final followRepo = ref.read(followRepositoryProvider);
    final profileRepo = ref.read(profileRepositoryProvider);
    if (profileRepo == null) {
      setState(() => _followListLoaded = true);
      return;
    }

    final followingPubkeys = followRepo.followingPubkeys;

    // Start both fetches in parallel: profile cache (fast, SQLite) and
    // my followers from relay (needed for mutual-follow filtering).
    final profilesFuture = Future.wait(
      followingPubkeys.map((pk) => profileRepo.getCachedProfile(pubkey: pk)),
    );
    try {
      final myFollowersFuture =
          widget.filterMode == UserPickerFilterMode.mutualFollowsOnly
          ? followRepo
                .getMyFollowers()
                .then<Set<String>?>((followers) => followers.toSet())
                // Relay/network failures should not block sheet loading.
                .catchError((Object _, StackTrace _) => null)
          : Future<Set<String>?>.value(const <String>{});

      final (rawProfiles, myFollowersSet) = await (
        profilesFuture,
        myFollowersFuture,
      ).wait;

      var profiles = rawProfiles.whereType<UserProfile>().toList();

      // When mutual-follow fetch fails, fall back to local follows so the
      // picker remains usable instead of hanging in loading.
      if (widget.filterMode == UserPickerFilterMode.mutualFollowsOnly &&
          myFollowersSet != null) {
        profiles = profiles
            .where((p) => myFollowersSet.contains(p.pubkey))
            .toList();
      }

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
    } catch (_) {
      if (mounted) {
        setState(() {
          _followProfiles = const [];
          _filteredFollowProfiles = const [];
          _followListLoaded = true;
        });
      }
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
    if (widget.onUserToggled != null) {
      setState(() {
        if (_selectedPubkeys.contains(profile.pubkey)) {
          _selectedPubkeys.remove(profile.pubkey);
        } else {
          _selectedPubkeys.add(profile.pubkey);
        }
      });
      widget.onUserToggled!(profile);
    } else if (widget.maxCount != null) {
      setState(() {
        if (_selectedProfiles.any((p) => p.pubkey == profile.pubkey)) {
          _selectedProfiles.removeWhere((p) => p.pubkey == profile.pubkey);
          _selectedPubkeys.remove(profile.pubkey);
        } else if (_selectedProfiles.length < widget.maxCount!) {
          _selectedProfiles.add(profile);
          _selectedPubkeys.add(profile.pubkey);
        }
      });
    } else {
      Navigator.of(context).pop([profile]);
    }
  }

  void _handleDone() {
    Navigator.of(context).pop(List.of(_selectedProfiles));
  }

  void _handleClear() {
    Navigator.of(context).pop(<UserProfile>[]);
  }

  @override
  Widget build(BuildContext context) {
    if (_profileRepoMissing) {
      return const _ProfileRepoUnavailable();
    }

    final hintText =
        widget.searchHint ??
        (_useLocalSearch
            ? context.l10n.userPickerFilterByNameHint
            : context.l10n.userPickerSearchByNameHint);
    final disabledPubkeys = widget.onUserToggled == null
        ? widget.excludePubkeys
        : const <String>{};

    return Column(
      crossAxisAlignment: .stretch,
      children: [
        VineBottomSheetHeader(
          showDivider: false,
          leadingAction: DivineIconButton(
            icon: .x,
            type: .secondary,
            size: .small,
            onPressed: context.pop,
          ),
          title: _UserPickerTitle(
            title: widget.title,
            subtitle: widget.searchText,
            selectedCount: _selectedProfiles.length,
            maxCount: widget.maxCount,
          ),
          trailingAction: widget.maxCount != null
              ? DivineIconButton(
                  icon: .check,
                  size: .small,
                  onPressed: _handleDone,
                )
              : widget.initialSelectedProfiles.isNotEmpty
              ? DivineIconButton(
                  icon: .trash,
                  size: .small,
                  type: .error,
                  onPressed: _handleClear,
                )
              : null,
        ),

        // Search field
        Semantics(
          textField: true,
          label: hintText,
          child: Container(
            margin: const .fromLTRB(16, 16, 16, 4),
            decoration: BoxDecoration(
              color: VineTheme.surfaceContainer,
              borderRadius: .circular(_searchInputBorderRadius),
            ),
            child: TextField(
              autofocus: widget.autoFocus,
              controller: _searchController,
              textInputAction: .search,
              // iOS predictive text and autocorrect silently rewrite the
              // query (e.g. "liz" → "Liz"), which re-fires `onChanged` and
              // blanks the results. Search fields should always opt out.
              autocorrect: false,
              enableSuggestions: false,
              onChanged: _onSearchChanged,
              onSubmitted: _onSearchChanged,
              cursorColor: VineTheme.vineGreen,
              style: VineTheme.bodyLargeFont(color: VineTheme.onSurface),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: VineTheme.bodyLargeFont(
                  color: VineTheme.onSurfaceMuted,
                ),
                prefixIcon: const Padding(
                  padding: .only(left: 16, right: 8),
                  child: DivineIcon(
                    icon: DivineIconName.search,
                    color: VineTheme.onSurfaceMuted,
                  ),
                ),
                border: .none,
                enabledBorder: .none,
                focusedBorder: OutlineInputBorder(
                  borderRadius: .circular(_searchInputBorderRadius),
                  borderSide: const BorderSide(
                    color: VineTheme.primary,
                    width: 2,
                  ),
                ),
                disabledBorder: .none,
                filled: false,
                contentPadding: const .symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),

        if (widget.maxCount != null)
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: .topCenter,
            child: _selectedProfiles.isNotEmpty
                ? _SelectedChipsRow(
                    profiles: _selectedProfiles,
                    onRemove: (profile) => setState(() {
                      _selectedProfiles.removeWhere(
                        (p) => p.pubkey == profile.pubkey,
                      );
                      _selectedPubkeys.remove(profile.pubkey);
                    }),
                  )
                : const SizedBox.shrink(),
          ),

        // Results list
        Expanded(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            opacity:
                widget.maxCount != null &&
                    _selectedProfiles.length >= widget.maxCount!
                ? 0.5
                : 1.0,
            child: _useLocalSearch
                ? _LocalResults(
                    scrollController: widget.scrollController,
                    followListLoaded: _followListLoaded,
                    followProfiles: _followProfiles,
                    filteredFollowProfiles: _filteredFollowProfiles,
                    onUserSelected: _onUserSelected,
                    excludePubkeys: disabledPubkeys,
                    selectedPubkeys: _selectedPubkeys,
                    hidePubkeys: {for (final p in _selectedProfiles) p.pubkey},
                  )
                : _NetworkResults(
                    searchBloc: _searchBloc!,
                    scrollController: widget.scrollController,
                    onUserSelected: _onUserSelected,
                    excludePubkeys: disabledPubkeys,
                    selectedPubkeys: _selectedPubkeys,
                    hidePubkeys: {for (final p in _selectedProfiles) p.pubkey},
                  ),
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
    this.isSelected = false,
    super.key,
  });

  final UserProfile profile;
  final VoidCallback onTap;
  final bool isDisabled;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    const textColor = VineTheme.onSurface;

    return Semantics(
      button: true,
      label: isDisabled
          ? context.l10n.userPickerAlreadyAddedSemantics(
              profile.bestDisplayName,
            )
          : context.l10n.userPickerSelectSemantics(profile.bestDisplayName),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: isDisabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            spacing: 16,
            children: [
              Opacity(
                opacity: isDisabled ? 0.5 : 1.0,
                child: UserAvatar(
                  imageUrl: profile.picture,
                  name: profile.bestDisplayName,
                  placeholderSeed: profile.pubkey,
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
              Container(
                padding: const .all(8),
                decoration: ShapeDecoration(
                  color: isDisabled
                      ? VineTheme.surfaceContainer
                      : isSelected
                      ? VineTheme.surfaceContainer
                      : VineTheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: .circular(16)),
                ),
                child: DivineIcon(
                  icon: (isDisabled || isSelected) ? .check : .plus,
                  color: (isDisabled || isSelected)
                      ? VineTheme.onSurfaceMuted
                      : VineTheme.onPrimary,
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
            context.l10n.userPickerEmptyFollowListTitle,
            style: VineTheme.headlineSmallFont(color: VineTheme.onSurface),
            textAlign: .center,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.userPickerEmptyFollowListBody,
            style: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceVariant),
            textAlign: .center,
          ),
          const SizedBox(height: 32),
          Semantics(
            button: true,
            label: context.l10n.userPickerGoBack,
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
                  context.l10n.userPickerGoBack,
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
          context.l10n.userPickerTypeNameToSearch,
          style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
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
          context.l10n.userPickerUnavailable,
          style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
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
          context.l10n.userPickerSearchFailedTryAgain,
          style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
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
          context.l10n.userSearchNoResults,
          style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
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
    this.selectedPubkeys = const {},
    this.hidePubkeys = const {},
  });

  final ScrollController? scrollController;
  final List<UserProfile> results;
  final ValueChanged<UserProfile> onUserSelected;
  final Set<String> excludePubkeys;
  final Set<String> selectedPubkeys;
  final Set<String> hidePubkeys;

  @override
  Widget build(BuildContext context) {
    final visible = hidePubkeys.isEmpty
        ? results
        : results.where((p) => !hidePubkeys.contains(p.pubkey)).toList();
    return ListView.separated(
      controller: scrollController,
      itemCount: visible.length,
      padding: EdgeInsets.fromLTRB(
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
        final profile = visible[index];
        final isDisabled = excludePubkeys.contains(profile.pubkey);
        return _UserSearchTile(
          key: ValueKey('${profile.pubkey}_$isDisabled'),
          profile: profile,
          isDisabled: isDisabled,
          isSelected: selectedPubkeys.contains(profile.pubkey),
          onTap: () => onUserSelected(profile),
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
    this.selectedPubkeys = const {},
    this.hidePubkeys = const {},
  });

  final UserSearchBloc searchBloc;
  final ScrollController? scrollController;
  final ValueChanged<UserProfile> onUserSelected;
  final Set<String> excludePubkeys;
  final Set<String> selectedPubkeys;
  final Set<String> hidePubkeys;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserSearchBloc, UserSearchState>(
      bloc: searchBloc,
      builder: (context, state) {
        return switch (state.status) {
          UserSearchStatus.initial => const _EmptyHint(),
          // Render cached/stale results while a new query loads — prevents
          // the full-screen spinner flash (e.g. when iOS autocorrect silently
          // replaces the query and re-triggers the search).
          UserSearchStatus.loading when state.results.isNotEmpty =>
            _ResultsList(
              scrollController: scrollController,
              results: state.results,
              onUserSelected: onUserSelected,
              excludePubkeys: excludePubkeys,
              selectedPubkeys: selectedPubkeys,
              hidePubkeys: hidePubkeys,
            ),
          UserSearchStatus.loading => const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          ),
          UserSearchStatus.failure => const _ErrorState(),
          UserSearchStatus.success when state.results.isEmpty =>
            const _NoResults(),
          UserSearchStatus.success => _ResultsList(
            scrollController: scrollController,
            results: state.results,
            onUserSelected: onUserSelected,
            excludePubkeys: excludePubkeys,
            selectedPubkeys: selectedPubkeys,
            hidePubkeys: hidePubkeys,
          ),
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
    this.selectedPubkeys = const {},
    this.hidePubkeys = const {},
  });

  final ScrollController? scrollController;
  final bool followListLoaded;
  final List<UserProfile> followProfiles;
  final List<UserProfile> filteredFollowProfiles;
  final ValueChanged<UserProfile> onUserSelected;
  final Set<String> excludePubkeys;
  final Set<String> selectedPubkeys;
  final Set<String> hidePubkeys;

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

    final visible = filteredFollowProfiles
        .where((p) => !hidePubkeys.contains(p.pubkey))
        .toList(growable: false);

    return ListView.separated(
      controller: scrollController,
      itemCount: visible.length,
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
        final profile = visible[index];
        final isDisabled = excludePubkeys.contains(profile.pubkey);
        return _UserSearchTile(
          key: ValueKey('${profile.pubkey}_$isDisabled'),
          profile: profile,
          isDisabled: isDisabled,
          isSelected: selectedPubkeys.contains(profile.pubkey),
          onTap: () => onUserSelected(profile),
        );
      },
    );
  }
}

class _UserPickerTitle extends StatelessWidget {
  const _UserPickerTitle({
    required this.title,
    required this.selectedCount,
    this.subtitle,
    this.maxCount,
  });

  final String title;
  final int selectedCount;
  final String? subtitle;
  final int? maxCount;

  @override
  Widget build(BuildContext context) {
    final displayTitle = maxCount != null
        ? '$selectedCount/$maxCount $title'
        : title;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 2,
      children: [
        Text(
          displayTitle,
          style: VineTheme.titleMediumFont(color: VineTheme.onSurface),
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          Text(
            subtitle!,
            style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceVariant),
          ),
      ],
    );
  }
}

class _SelectedChipsRow extends StatelessWidget {
  const _SelectedChipsRow({required this.profiles, required this.onRemove});

  final List<UserProfile> profiles;
  final ValueChanged<UserProfile> onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final profile in profiles)
            _SelectionChip(
              key: ValueKey(profile.pubkey),
              label: profile.bestDisplayName,
              onRemove: () => onRemove(profile),
            ),
        ],
      ),
    );
  }
}

class _SelectionChip extends StatefulWidget {
  const _SelectionChip({
    required this.label,
    required this.onRemove,
    super.key,
  });

  final String label;
  final VoidCallback onRemove;

  @override
  State<_SelectionChip> createState() => _SelectionChipState();
}

class _SelectionChipState extends State<_SelectionChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  bool _isRemoving = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _fadeAnimation = curved;
    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(curved);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleRemove() async {
    if (_isRemoving) return;
    _isRemoving = true;
    await _controller.reverse();
    widget.onRemove();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: VineTheme.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
                child: Text(
                  widget.label,
                  style: VineTheme.titleSmallFont(color: VineTheme.onSurface),
                ),
              ),
              Semantics(
                button: true,
                label: context.l10n.userPickerRemoveSelectionSemantics(
                  widget.label,
                ),
                child: GestureDetector(
                  onTap: _handleRemove,
                  child: const Padding(
                    padding: EdgeInsets.only(
                      left: 8,
                      right: 12,
                      top: 8,
                      bottom: 8,
                    ),
                    child: DivineIcon(
                      icon: .x,
                      size: 16,
                      color: VineTheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
