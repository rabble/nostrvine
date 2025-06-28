// ABOUTME: Search screen for finding videos, users, and hashtags in the OpenVine network
// ABOUTME: Provides real-time search functionality with filters and categories

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import '../services/video_event_service.dart';
import '../services/user_profile_service.dart';
import '../models/video_event.dart';
import '../theme/vine_theme.dart';
import 'profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;
  
  List<VideoEvent> _videoResults = [];
  List<String> _userResults = [];
  List<String> _hashtagResults = [];
  
  bool _isSearching = false;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _currentQuery) {
      _currentQuery = query;
      if (query.isNotEmpty) {
        _performSearch(query);
      } else {
        _clearResults();
      }
    }
  }

  void _performSearch(String query) {
    setState(() {
      _isSearching = true;
    });

    try {
      final videoEventService = context.read<VideoEventService>();
      
      // Check if query is an npub identifier
      String? searchPubkey;
      if (query.startsWith('npub') && query.length > 50) {
        try {
          // Convert npub to hex pubkey
          searchPubkey = Nip19.decode(query);
          debugPrint('🔑 Decoded npub to pubkey: $searchPubkey');
        } catch (e) {
          debugPrint('⚠️ Failed to decode npub: $e');
        }
      }

      // Search videos by title, content, hashtags, and author pubkey
      final videoResults = videoEventService.videoEvents.where((video) {
        // If we have a decoded npub, search by author
        if (searchPubkey != null) {
          return video.pubkey == searchPubkey;
        }
        
        // Otherwise search by content
        final titleMatch = video.title?.toLowerCase().contains(query.toLowerCase()) ?? false;
        final contentMatch = video.content.toLowerCase().contains(query.toLowerCase());
        final hashtagMatch = video.hashtags.any((tag) => tag.toLowerCase().contains(query.toLowerCase()));
        return titleMatch || contentMatch || hashtagMatch;
      }).toList();

      // Get hashtags that match the query
      final allHashtags = videoEventService.getAllHashtags();
      final hashtagResults = allHashtags
          .where((tag) => tag.toLowerCase().contains(query.toLowerCase()))
          .toList();

      // Get unique authors from video results for user search
      final userResults = <String>{};
      
      // If we decoded an npub, add that user to results
      if (searchPubkey != null) {
        userResults.add(searchPubkey);
      }
      
      // Add authors from video results
      userResults.addAll(videoResults.map((video) => video.pubkey));
      
      setState(() {
        _videoResults = videoResults;
        _hashtagResults = hashtagResults;
        _userResults = userResults.toList();
        _isSearching = false;
      });

      debugPrint('🔍 Search results for "$query": ${videoResults.length} videos, ${userResults.length} users, ${hashtagResults.length} hashtags');
    } catch (e) {
      debugPrint('❌ Search error: $e');
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _clearResults() {
    setState(() {
      _videoResults.clear();
      _userResults.clear();
      _hashtagResults.clear();
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: VineTheme.whiteText),
          decoration: const InputDecoration(
            hintText: 'Search videos, users, npub, hashtags...',
            hintStyle: TextStyle(color: VineTheme.whiteText),
            border: InputBorder.none,
            suffixIcon: Icon(Icons.search, color: VineTheme.whiteText),
          ),
        ),
        bottom: _currentQuery.isNotEmpty
          ? TabBar(
              controller: _tabController,
              indicatorColor: VineTheme.whiteText,
              indicatorWeight: 2,
              labelColor: VineTheme.whiteText,
              unselectedLabelColor: VineTheme.whiteText.withValues(alpha: 0.7),
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              tabs: [
                Tab(text: 'Videos (${_videoResults.length})'),
                Tab(text: 'Users (${_userResults.length})'),
                Tab(text: 'Hashtags (${_hashtagResults.length})'),
              ],
            )
          : null,
      ),
      body: _currentQuery.isEmpty
        ? _buildEmptyState()
        : _isSearching
          ? _buildLoadingState()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildVideoResults(),
                _buildUserResults(),
                _buildHashtagResults(),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: VineTheme.secondaryText,
          ),
          SizedBox(height: 16),
          Text(
            'Search OpenVine',
            style: TextStyle(
              color: VineTheme.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Find videos, users, and hashtags\nacross the decentralized network.',
            style: TextStyle(
              color: VineTheme.secondaryText,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: VineTheme.vineGreen),
          SizedBox(height: 16),
          Text(
            'Searching...',
            style: TextStyle(
              color: VineTheme.primaryText,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoResults() {
    if (_videoResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 48,
              color: VineTheme.secondaryText,
            ),
            SizedBox(height: 16),
            Text(
              'No videos found',
              style: TextStyle(
                color: VineTheme.primaryText,
                fontSize: 16,
              ),
            ),
            Text(
              'Try a different search term',
              style: TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _videoResults.length,
      itemBuilder: (context, index) {
        final video = _videoResults[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: _VideoSearchResultCard(video: video),
        );
      },
    );
  }

  Widget _buildUserResults() {
    if (_userResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 48,
              color: VineTheme.secondaryText,
            ),
            SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                color: VineTheme.primaryText,
                fontSize: 16,
              ),
            ),
            Text(
              'Try a different search term',
              style: TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Consumer<UserProfileService>(
      builder: (context, userProfileService, child) {
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _userResults.length,
          itemBuilder: (context, index) {
            final pubkey = _userResults[index];
            final profile = userProfileService.getCachedProfile(pubkey);
            return _UserSearchResultCard(
              pubkey: pubkey,
              profile: profile,
              onTap: () => _openUserProfile(pubkey),
            );
          },
        );
      },
    );
  }

  Widget _buildHashtagResults() {
    if (_hashtagResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.tag,
              size: 48,
              color: VineTheme.secondaryText,
            ),
            SizedBox(height: 16),
            Text(
              'No hashtags found',
              style: TextStyle(
                color: VineTheme.primaryText,
                fontSize: 16,
              ),
            ),
            Text(
              'Try a different search term',
              style: TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _hashtagResults.length,
      itemBuilder: (context, index) {
        final hashtag = _hashtagResults[index];
        return _HashtagSearchResultCard(
          hashtag: hashtag,
          onTap: () => _searchHashtag(hashtag),
        );
      },
    );
  }

  void _openUserProfile(String pubkey) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProfileScreen(profilePubkey: pubkey),
      ),
    );
  }

  void _searchHashtag(String hashtag) {
    _searchController.text = '#$hashtag';
    _tabController.animateTo(0); // Switch to videos tab
  }
}

class _VideoSearchResultCard extends StatelessWidget {
  final VideoEvent video;

  const _VideoSearchResultCard({required this.video});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Video thumbnail placeholder
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: VineTheme.vineGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (video.title?.isNotEmpty == true) ...[
                        SelectableText(
                          video.title!,
                          style: const TextStyle(
                            color: VineTheme.whiteText,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (video.content.isNotEmpty) ...[
                        SelectableText(
                          video.content,
                          style: const TextStyle(
                            color: VineTheme.secondaryText,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 4),
                      ],
                      SelectableText(
                        'by ${video.displayPubkey} • ${video.relativeTime}',
                        style: const TextStyle(
                          color: VineTheme.secondaryText,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (video.hashtags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: video.hashtags.take(3).map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: VineTheme.vineGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '#$tag',
                    style: const TextStyle(
                      color: VineTheme.vineGreen,
                      fontSize: 10,
                    ),
                  ),
                )).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UserSearchResultCard extends StatelessWidget {
  final String pubkey;
  final dynamic profile; // UserProfile type would be defined elsewhere
  final VoidCallback onTap;

  const _UserSearchResultCard({
    required this.pubkey,
    required this.profile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: VineTheme.vineGreen,
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: const Icon(
            Icons.person,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: SelectableText(
          profile?.displayName ?? 'Anonymous',
          style: const TextStyle(
            color: VineTheme.whiteText,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          '${pubkey.substring(0, 16)}...',
          style: const TextStyle(
            color: VineTheme.secondaryText,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: VineTheme.secondaryText,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _HashtagSearchResultCard extends StatelessWidget {
  final String hashtag;
  final VoidCallback onTap;

  const _HashtagSearchResultCard({
    required this.hashtag,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: VineTheme.vineGreen.withValues(alpha: 0.2),
            border: Border.all(color: VineTheme.vineGreen, width: 1),
          ),
          child: const Icon(
            Icons.tag,
            color: VineTheme.vineGreen,
            size: 20,
          ),
        ),
        title: Text(
          '#$hashtag',
          style: const TextStyle(
            color: VineTheme.whiteText,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: const Text(
          'Tap to search videos with this hashtag',
          style: TextStyle(
            color: VineTheme.secondaryText,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(
          Icons.search,
          color: VineTheme.secondaryText,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }
}