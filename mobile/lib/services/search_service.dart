// ABOUTME: Search service for finding users, videos, and hashtags across Nostr network
// ABOUTME: Provides debounced search with local caching and history management

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/search_result.dart';
import '../services/nostr_service_interface.dart';

class SearchService extends ChangeNotifier {
  final INostrService _nostrService;
  final List<SearchResult> _cachedResults = [];
  final List<SearchQuery> _searchHistory = [];
  Timer? _debounceTimer;
  bool _isSearching = false;
  String? _lastQuery;
  SearchResultType _lastType = SearchResultType.user;

  // Search configuration
  static const Duration _debounceDelay = Duration(milliseconds: 500);
  static const int _maxHistoryItems = 10;
  static const int _maxCachedResults = 100;
  static const String _historyKey = 'search_history';

  SearchService({required INostrService nostrService}) 
      : _nostrService = nostrService {
    _loadSearchHistory();
  }

  // Getters
  bool get isSearching => _isSearching;
  List<SearchResult> get cachedResults => List.unmodifiable(_cachedResults);
  List<SearchQuery> get searchHistory => List.unmodifiable(_searchHistory);

  /// Perform search with debouncing
  Future<List<SearchResult>> search(
    String query, 
    SearchResultType type, {
    Map<String, dynamic> filters = const {},
  }) async {
    if (query.trim().isEmpty) {
      _cachedResults.clear();
      notifyListeners();
      return [];
    }

    final searchQuery = SearchQuery(
      query: query.trim(),
      type: type,
      filters: filters,
    );

    // Cancel previous search
    _debounceTimer?.cancel();

    return Completer<List<SearchResult>>().future.then((_) async {
      // Start debounce timer
      _debounceTimer = Timer(_debounceDelay, () async {
        await _performSearch(searchQuery);
      });

      // Wait for debounce to complete
      await Future.delayed(_debounceDelay + const Duration(milliseconds: 50));
      return _cachedResults;
    });
  }

  /// Perform immediate search without debouncing
  Future<List<SearchResult>> searchImmediate(SearchQuery searchQuery) async {
    _debounceTimer?.cancel();
    return await _performSearch(searchQuery);
  }

  /// Clear search results and history
  void clearResults() {
    _cachedResults.clear();
    _lastQuery = null;
    notifyListeners();
  }

  /// Clear search history
  Future<void> clearHistory() async {
    _searchHistory.clear();
    await _saveSearchHistory();
    notifyListeners();
  }

  /// Add query to search history
  void addToHistory(SearchQuery query) {
    // Remove existing identical query
    _searchHistory.removeWhere((h) => h == query);
    
    // Add to front
    _searchHistory.insert(0, query);
    
    // Limit size
    if (_searchHistory.length > _maxHistoryItems) {
      _searchHistory.removeRange(_maxHistoryItems, _searchHistory.length);
    }
    
    _saveSearchHistory();
    notifyListeners();
  }

  /// Get suggested searches (popular hashtags, recent users, etc.)
  Future<List<SearchResult>> getSuggestions(SearchResultType type) async {
    try {
      switch (type) {
        case SearchResultType.hashtag:
          return await _getPopularHashtags();
        case SearchResultType.user:
          return await _getRecentUsers();
        case SearchResultType.video:
          return await _getRecentVideos();
      }
    } catch (e) {
      debugPrint('❌ Failed to get search suggestions: $e');
      return [];
    }
  }

  // Private methods

  /// Perform the actual search operation
  Future<List<SearchResult>> _performSearch(SearchQuery searchQuery) async {
    try {
      _isSearching = true;
      _lastQuery = searchQuery.query;
      _lastType = searchQuery.type;
      notifyListeners();

      List<SearchResult> results = [];

      switch (searchQuery.type) {
        case SearchResultType.user:
          results = await _searchUsers(searchQuery.query, searchQuery.filters);
          break;
        case SearchResultType.video:
          results = await _searchVideos(searchQuery.query, searchQuery.filters);
          break;
        case SearchResultType.hashtag:
          results = await _searchHashtags(searchQuery.query, searchQuery.filters);
          break;
      }

      // Update cache
      _cachedResults.clear();
      _cachedResults.addAll(results);

      // Add to search history
      addToHistory(searchQuery);

      debugPrint('🔍 Search completed: ${results.length} results for "${searchQuery.query}"');
      
      return results;
    } catch (e) {
      debugPrint('❌ Search failed: $e');
      return [];
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  /// Search for users by name, username, or npub
  Future<List<SearchResult>> _searchUsers(String query, Map<String, dynamic> filters) async {
    final results = <SearchResult>[];
    
    try {
      // For now, create mock results - in real implementation this would query Nostr relays
      // TODO: Implement actual Nostr user search via relays
      await Future.delayed(const Duration(milliseconds: 800)); // Simulate network delay
      
      // Mock user results
      final mockUsers = [
        UserSearchResult(
          pubkey: 'npub1mock1example',
          displayName: 'Test User',
          username: 'testuser@example.com',
          bio: 'A test user for search functionality',
          followCount: 42,
        ),
        UserSearchResult(
          pubkey: 'npub1mock2example', 
          displayName: 'Demo Creator',
          username: 'demo@nostrvine.app',
          bio: 'Creating amazing vine content',
          followCount: 128,
        ),
      ].where((user) => 
        user.displayName.toLowerCase().contains(query.toLowerCase()) ||
        user.username.toLowerCase().contains(query.toLowerCase())
      ).toList();

      for (final user in mockUsers) {
        results.add(SearchResult(
          type: SearchResultType.user,
          id: user.pubkey,
          data: user,
        ));
      }
    } catch (e) {
      debugPrint('❌ User search failed: $e');
    }

    return results;
  }

  /// Search for videos by title, description, or hashtags
  Future<List<SearchResult>> _searchVideos(String query, Map<String, dynamic> filters) async {
    final results = <SearchResult>[];
    
    try {
      // TODO: Implement actual video search via Nostr relays
      await Future.delayed(const Duration(milliseconds: 600));
      
      // Mock video results
      final mockVideos = [
        VideoSearchResult(
          eventId: 'event_mock_1',
          title: 'Funny Cat Video',
          description: 'A hilarious cat doing cat things',
          creatorName: 'Cat Lover',
          creatorPubkey: 'npub1catlover',
          hashtags: ['#cats', '#funny', '#pets'],
          viewCount: 1234,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        VideoSearchResult(
          eventId: 'event_mock_2', 
          title: 'Coding Tutorial',
          description: 'Learn Flutter in 60 seconds',
          creatorName: 'Dev Teacher',
          creatorPubkey: 'npub1devteacher',
          hashtags: ['#coding', '#flutter', '#tutorial'],
          viewCount: 5678,
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        ),
      ].where((video) =>
        video.title.toLowerCase().contains(query.toLowerCase()) ||
        video.description.toLowerCase().contains(query.toLowerCase()) ||
        video.hashtags.any((tag) => tag.toLowerCase().contains(query.toLowerCase()))
      ).toList();

      for (final video in mockVideos) {
        results.add(SearchResult(
          type: SearchResultType.video,
          id: video.eventId,
          data: video,
        ));
      }
    } catch (e) {
      debugPrint('❌ Video search failed: $e');
    }

    return results;
  }

  /// Search for hashtags
  Future<List<SearchResult>> _searchHashtags(String query, Map<String, dynamic> filters) async {
    final results = <SearchResult>[];
    
    try {
      // TODO: Implement actual hashtag search via Nostr relays
      await Future.delayed(const Duration(milliseconds: 400));
      
      // Mock hashtag results
      final mockHashtags = [
        HashtagSearchResult(
          hashtag: '#nostrvine',
          usageCount: 1024,
          lastUsed: DateTime.now().subtract(const Duration(minutes: 15)),
        ),
        HashtagSearchResult(
          hashtag: '#nostr',
          usageCount: 5432,
          lastUsed: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        HashtagSearchResult(
          hashtag: '#bitcoin',
          usageCount: 9876,
          lastUsed: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
      ].where((hashtag) =>
        hashtag.hashtag.toLowerCase().contains(query.toLowerCase())
      ).toList();

      for (final hashtag in mockHashtags) {
        results.add(SearchResult(
          type: SearchResultType.hashtag,
          id: hashtag.hashtag,
          data: hashtag,
        ));
      }
    } catch (e) {
      debugPrint('❌ Hashtag search failed: $e');
    }

    return results;
  }

  /// Get popular hashtags for suggestions
  Future<List<SearchResult>> _getPopularHashtags() async {
    // TODO: Implement actual trending hashtag discovery
    return [];
  }

  /// Get recent users for suggestions  
  Future<List<SearchResult>> _getRecentUsers() async {
    // TODO: Implement recent user discovery
    return [];
  }

  /// Get recent videos for suggestions
  Future<List<SearchResult>> _getRecentVideos() async {
    // TODO: Implement recent video discovery
    return [];
  }

  /// Load search history from local storage
  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);
      
      if (historyJson != null) {
        final historyList = jsonDecode(historyJson) as List;
        _searchHistory.clear();
        
        for (final item in historyList) {
          try {
            final query = SearchQuery(
              query: item['query'] ?? '',
              type: SearchResultType.values[item['type'] ?? 0],
              filters: Map<String, dynamic>.from(item['filters'] ?? {}),
            );
            _searchHistory.add(query);
          } catch (e) {
            debugPrint('⚠️ Failed to parse search history item: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load search history: $e');
    }
  }

  /// Save search history to local storage
  Future<void> _saveSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = _searchHistory.map((query) => {
        'query': query.query,
        'type': query.type.index,
        'filters': query.filters,
      }).toList();
      
      await prefs.setString(_historyKey, jsonEncode(historyList));
    } catch (e) {
      debugPrint('⚠️ Failed to save search history: $e');
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}