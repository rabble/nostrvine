// ABOUTME: Main search screen with tabbed interface for users, videos, and hashtags
// ABOUTME: Provides comprehensive search functionality with history and suggestions

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/search_result.dart';
import '../services/search_service.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/user_search_item.dart';
import '../widgets/video_search_item.dart';
import '../widgets/hashtag_search_item.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  final SearchResultType? initialType;

  const SearchScreen({
    super.key,
    this.initialQuery,
    this.initialType,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _searchController;
  late SearchService _searchService;
  
  List<SearchResult> _results = [];
  bool _showHistory = true;
  SearchResultType _currentType = SearchResultType.user;

  @override
  void initState() {
    super.initState();
    
    // Initialize controllers
    _tabController = TabController(length: 3, vsync: this);
    _searchController = TextEditingController();
    
    // Set initial values
    _currentType = widget.initialType ?? SearchResultType.user;
    _tabController.index = _currentType.index;
    
    if (widget.initialQuery != null) {
      _searchController.text = widget.initialQuery!;
      _showHistory = false;
    }
    
    // Listen to tab changes
    _tabController.addListener(_onTabChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _searchService = context.read<SearchService>();
    
    // Perform initial search if query provided
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _performSearch(widget.initialQuery!);
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    final newType = SearchResultType.values[_tabController.index];
    if (newType != _currentType) {
      setState(() {
        _currentType = newType;
      });
      
      // Perform new search if there's a query
      if (_searchController.text.isNotEmpty) {
        _performSearch(_searchController.text);
      }
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results.clear();
        _showHistory = true;
      });
      return;
    }

    setState(() {
      _showHistory = false;
    });

    try {
      final results = await _searchService.search(query, _currentType);
      if (mounted) {
        setState(() {
          _results = results;
        });
      }
    } catch (e) {
      debugPrint('❌ Search failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onSearchChanged(String query) {
    _performSearch(query);
  }

  void _onSearchSubmitted(String query) {
    _performSearch(query);
  }

  void _onSearchClear() {
    _searchController.clear();
    setState(() {
      _results.clear();
      _showHistory = true;
    });
  }

  void _onHistoryItemTap(SearchQuery query) {
    _searchController.text = query.query;
    _tabController.index = query.type.index;
    _performSearch(query.query);
  }

  void _onUserTap(UserSearchResult user) {
    // TODO: Navigate to user profile
    debugPrint('👤 Navigate to user profile: ${user.pubkey}');
    Navigator.of(context).pop();
  }

  void _onVideoTap(VideoSearchResult video) {
    // TODO: Navigate to video detail/player
    debugPrint('🎬 Navigate to video: ${video.eventId}');
    Navigator.of(context).pop();
  }

  void _onHashtagTap(HashtagSearchResult hashtag) {
    // TODO: Navigate to hashtag feed
    debugPrint('🏷️ Navigate to hashtag feed: ${hashtag.hashtag}');
    Navigator.of(context).pop();
  }

  void _onFollowUser(UserSearchResult user) {
    // TODO: Implement follow functionality
    debugPrint('➕ Follow user: ${user.pubkey}');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${user.isFollowing ? 'Unfollowed' : 'Following'} ${user.displayName}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Search bar header
          MainSearchBar(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onSubmitted: _onSearchSubmitted,
            onClear: _onSearchClear,
          ),
          
          // Tab bar
          _buildTabBar(),
          
          // Search content
          Expanded(
            child: _buildSearchContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[800]!,
            width: 1,
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.purple,
        indicatorWeight: 2,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey[500],
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
        ),
        tabs: const [
          Tab(text: 'Users'),
          Tab(text: 'Videos'),
          Tab(text: 'Hashtags'),
        ],
      ),
    );
  }

  Widget _buildSearchContent() {
    return Consumer<SearchService>(
      builder: (context, searchService, child) {
        if (searchService.isSearching) {
          return _buildLoadingState();
        }

        if (_showHistory) {
          return _buildHistoryState();
        }

        if (_results.isEmpty && _searchController.text.isNotEmpty) {
          return _buildEmptyState();
        }

        return _buildResults();
      },
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.purple),
          SizedBox(height: 16),
          Text(
            'Searching...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryState() {
    final history = _searchService.searchHistory;
    
    if (history.isEmpty) {
      return _buildEmptyHistoryState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // History header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton(
                onPressed: () => _searchService.clearHistory(),
                child: const Text(
                  'Clear All',
                  style: TextStyle(color: Colors.purple),
                ),
              ),
            ],
          ),
        ),
        
        // History list
        Expanded(
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final query = history[index];
              return _buildHistoryItem(query);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(SearchQuery query) {
    IconData icon;
    switch (query.type) {
      case SearchResultType.user:
        icon = Icons.person;
        break;
      case SearchResultType.video:
        icon = Icons.videocam;
        break;
      case SearchResultType.hashtag:
        icon = Icons.tag;
        break;
    }

    return ListTile(
      leading: Icon(icon, color: Colors.grey[500]),
      title: Text(
        query.query,
        style: const TextStyle(color: Colors.white),
      ),
      subtitle: Text(
        query.type.name.toUpperCase(),
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
      ),
      trailing: IconButton(
        icon: Icon(Icons.close, color: Colors.grey[500], size: 20),
        onPressed: () {
          // TODO: Remove individual history item
        },
      ),
      onTap: () => _onHistoryItemTap(query),
    );
  }

  Widget _buildEmptyHistoryState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No Recent Searches',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start searching to discover users, videos, and hashtags',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;
    
    switch (_currentType) {
      case SearchResultType.user:
        icon = Icons.person_search;
        message = 'No users found for "${_searchController.text}"';
        break;
      case SearchResultType.video:
        icon = Icons.video_library;
        message = 'No videos found for "${_searchController.text}"';
        break;
      case SearchResultType.hashtag:
        icon = Icons.tag;
        message = 'No hashtags found for "${_searchController.text}"';
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No Results',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _results.length,
      separatorBuilder: (context, index) => Divider(
        color: Colors.grey[800],
        height: 1,
        thickness: 0.5,
      ),
      itemBuilder: (context, index) {
        final result = _results[index];
        
        switch (result.type) {
          case SearchResultType.user:
            final user = result.data as UserSearchResult;
            return UserSearchItem(
              user: user,
              onTap: () => _onUserTap(user),
              onFollow: _onFollowUser,
            );
          case SearchResultType.video:
            final video = result.data as VideoSearchResult;
            return VideoSearchItem(
              video: video,
              onTap: () => _onVideoTap(video),
              onCreatorTap: (pubkey) {
                // TODO: Navigate to creator profile
                debugPrint('👤 Navigate to creator: $pubkey');
              },
            );
          case SearchResultType.hashtag:
            final hashtag = result.data as HashtagSearchResult;
            return HashtagSearchItem(
              hashtag: hashtag,
              onTap: () => _onHashtagTap(hashtag),
            );
        }
      },
    );
  }
}