// ABOUTME: Bottom sheet for composing a new direct message.
// ABOUTME: Shows searchable user list for selecting a DM recipient.
// ABOUTME: Uses NewMessageSearchBloc for contact loading and search.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/screens/inbox/bloc/bloc.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:profile_repository/profile_repository.dart';

/// A bottom sheet for selecting a recipient to start a new DM conversation.
///
/// Shows the user's followed contacts initially. Typing in the search
/// field queries for users by name or npub. Selecting a user returns
/// their [UserProfile] and dismisses the sheet.
class NewMessageSheet extends StatelessWidget {
  const NewMessageSheet({
    required this.profileRepository,
    required this.followRepository,
    super.key,
  });

  final ProfileRepository profileRepository;
  final FollowRepository followRepository;

  /// Shows the sheet and returns the selected [UserProfile], or null if
  /// the user dismissed without selecting.
  static Future<UserProfile?> show(
    BuildContext context, {
    required ProfileRepository profileRepository,
    required FollowRepository followRepository,
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
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NewMessageSearchBloc(
        profileRepository: profileRepository,
        followRepository: followRepository,
      )..add(const NewMessageSearchStarted()),
      child: const _NewMessageSheetView(),
    );
  }
}

class _NewMessageSheetView extends StatefulWidget {
  const _NewMessageSheetView();

  @override
  State<_NewMessageSheetView> createState() => _NewMessageSheetViewState();
}

class _NewMessageSheetViewState extends State<_NewMessageSheetView> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      context.read<NewMessageSearchBloc>().add(const NewMessageSearchCleared());
    } else {
      context.read<NewMessageSearchBloc>().add(
        NewMessageSearchQueryChanged(trimmed),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Material(
      color: VineTheme.surfaceBackground,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(VineTheme.bottomSheetBorderRadius),
      ),
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
            const Expanded(child: _ResultsBody()),
          ],
        ),
      ),
    );
  }
}

class _ResultsBody extends StatelessWidget {
  const _ResultsBody();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NewMessageSearchBloc, NewMessageSearchState>(
      builder: (context, state) {
        return switch (state.status) {
          NewMessageSearchStatus.loadingContacts => const Center(
            child: CircularProgressIndicator(color: VineTheme.primary),
          ),
          NewMessageSearchStatus.idle => _UserProfileList(
            profiles: state.contacts,
            emptyMessage: 'No contacts found.\nFollow people to see them here.',
          ),
          NewMessageSearchStatus.searching when state.results.isEmpty =>
            const Center(
              child: CircularProgressIndicator(color: VineTheme.primary),
            ),
          NewMessageSearchStatus.searching => _UserProfileList(
            profiles: state.results,
          ),
          NewMessageSearchStatus.searchSuccess when state.results.isNotEmpty =>
            _UserProfileList(profiles: state.results),
          NewMessageSearchStatus.searchSuccess => const _UserProfileList(
            profiles: [],
            emptyMessage: 'No users found',
          ),
          NewMessageSearchStatus.searchFailure when state.results.isNotEmpty =>
            _UserProfileList(profiles: state.results),
          NewMessageSearchStatus.searchFailure => const _UserProfileList(
            profiles: [],
            emptyMessage: 'Search failed. Please try again.',
          ),
        };
      },
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
        Text('New message', style: VineTheme.titleMediumFont()),
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
        spacing: 8,
        children: [
          const Icon(Icons.search, color: VineTheme.onSurfaceMuted, size: 24),
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

class _UserProfileList extends StatelessWidget {
  const _UserProfileList({required this.profiles, this.emptyMessage});

  final List<UserProfile> profiles;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty && emptyMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            emptyMessage!,
            style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: profiles.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        thickness: 1,
        color: VineTheme.outlineMuted,
        indent: 72,
      ),
      itemBuilder: (context, index) {
        final profile = profiles[index];
        return _UserTile(
          profile: profile,
          onTap: () => Navigator.of(context).pop(profile),
        );
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
              placeholderSeed: profile.pubkey,
              size: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    profile.bestDisplayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: VineTheme.titleMediumFont(),
                  ),
                  if (profile.handle.isNotEmpty)
                    Text(
                      profile.handle,
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
