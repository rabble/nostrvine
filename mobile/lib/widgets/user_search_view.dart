// ABOUTME: Widget for displaying user search results
// ABOUTME: Consumes UserSearchBloc from parent BlocProvider

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// Displays user search results from UserSearchBloc.
///
/// Must be used within a BlocProvider<UserSearchBloc>.
class UserSearchView extends StatelessWidget {
  const UserSearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserSearchBloc, UserSearchState>(
      builder: (context, state) {
        return switch (state.status) {
          UserSearchStatus.initial => const _UserSearchEmptyState(),
          UserSearchStatus.loading => const _UserSearchLoadingState(),
          UserSearchStatus.success => _UserSearchResultsList(
            results: state.results,
          ),
          UserSearchStatus.failure => const _UserSearchErrorState(),
        };
      },
    );
  }
}

class _UserSearchEmptyState extends StatelessWidget {
  const _UserSearchEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text('Search for users', style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }
}

class _UserSearchLoadingState extends StatelessWidget {
  const _UserSearchLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(child: CircularProgressIndicator(color: VineTheme.vineGreen));
  }
}

class _UserSearchResultsList extends StatelessWidget {
  const _UserSearchResultsList({required this.results});

  final List<UserProfile> results;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const _UserSearchNoResultsState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final profile = results[index];
        return _SearchUserTile(
          profile: profile,
          onTap: () {
            final npub = normalizeToNpub(profile.pubkey);
            if (npub != null) {
              context.push(OtherProfileScreen.pathForNpub(npub));
            }
          },
        );
      },
    );
  }
}

/// Tile widget for displaying a user from search results.
/// Uses UserProfile from package:models directly.
class _SearchUserTile extends StatelessWidget {
  const _SearchUserTile({required this.profile, this.onTap});

  final UserProfile profile;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'search_user_tile_${profile.pubkey}',
      label: profile.bestDisplayName,
      container: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VineTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              UserAvatar(imageUrl: profile.picture, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.bestDisplayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (profile.about != null && profile.about!.isNotEmpty)
                      Text(
                        profile.about!,
                        style: TextStyle(color: Colors.grey[400], fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserSearchNoResultsState extends StatelessWidget {
  const _UserSearchNoResultsState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text('No users found', style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }
}

class _UserSearchErrorState extends StatelessWidget {
  const _UserSearchErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text('Search failed', style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }
}
