// ABOUTME: Widget for displaying user search results
// ABOUTME: Consumes UserSearchBloc from parent BlocProvider

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

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
          UserSearchStatus.failure => _UserSearchErrorState(
              error: state.errorMessage,
            ),
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
          Text(
            'Search for users',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

class _UserSearchLoadingState extends StatelessWidget {
  const _UserSearchLoadingState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: VineTheme.vineGreen),
    );
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
        return UserProfileTile(
          pubkey: profile.pubkey,
          showFollowButton: false,
          onTap: () => context.pushProfileGrid(profile.pubkey),
        );
      },
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
          Text(
            'No users found',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}

class _UserSearchErrorState extends StatelessWidget {
  const _UserSearchErrorState({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            'Search failed',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }
}