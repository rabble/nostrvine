// ABOUTME: Instagram-style scrollable profile screen implementation
// ABOUTME: Uses CustomScrollView with slivers for smooth scrolling experience

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:nostr_sdk/event.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import '../services/social_service.dart';
import '../services/video_event_service.dart';
import '../services/analytics_service.dart';
import '../providers/profile_stats_provider.dart';
import '../providers/profile_videos_provider.dart';
import '../models/video_event.dart';
import '../theme/vine_theme.dart';
import '../utils/nostr_encoding.dart';
import 'profile_setup_screen.dart';
import 'debug_video_test.dart';
import 'universal_camera_screen.dart';
import 'key_import_screen.dart';
import 'relay_settings_screen.dart';
import '../widgets/video_fullscreen_overlay.dart';
import '../utils/unified_logger.dart';

class ProfileScreenScrollable extends StatefulWidget {
  final String? profilePubkey;
  
  const ProfileScreenScrollable({super.key, this.profilePubkey});

  @override
  State<ProfileScreenScrollable> createState() => _ProfileScreenScrollableState();
}

class _ProfileScreenScrollableState extends State<ProfileScreenScrollable> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isOwnProfile = true;
  String? _targetPubkey;
  String? _playingVideoId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProfile();
    });
  }
  
  void _initializeProfile() {
    final authService = context.read<AuthService>();
    final currentUserPubkey = authService.currentPublicKeyHex;
    
    if (!authService.isAuthenticated || currentUserPubkey == null) {
      Log.warning('AuthService not ready, deferring profile initialization', name: 'ProfileScreen', category: LogCategory.ui);
      Future.delayed(const Duration(milliseconds: 100), _initializeProfile);
      return;
    }
    
    _playingVideoId = null;
    
    setState(() {
      _targetPubkey = widget.profilePubkey ?? currentUserPubkey;
      _isOwnProfile = _targetPubkey == currentUserPubkey;
    });
    
    if (_targetPubkey != null) {
      _loadProfileStats();
      _loadProfileVideos();
      
      if (!_isOwnProfile) {
        _loadUserProfile();
      }
    }
  }
  
  void _loadProfileStats() {
    if (_targetPubkey == null) return;
    final profileStatsProvider = context.read<ProfileStatsProvider>();
    profileStatsProvider.loadProfileStats(_targetPubkey!);
  }
  
  void _loadProfileVideos() {
    if (_targetPubkey == null) {
      Log.error('Cannot load profile videos: _targetPubkey is null', name: 'ProfileScreen', category: LogCategory.ui);
      return;
    }
    
    Log.debug('Loading profile videos for: ${_targetPubkey!.substring(0, 8)}... (isOwnProfile: $_isOwnProfile)', name: 'ProfileScreen', category: LogCategory.ui);
    try {
      final profileVideosProvider = context.read<ProfileVideosProvider>();
      profileVideosProvider.loadVideosForUser(_targetPubkey!).then((_) {
        Log.info('Profile videos load completed for ${_targetPubkey!.substring(0, 8)}', name: 'ProfileScreen', category: LogCategory.ui);
      }).catchError((error) {
        Log.error('Profile videos load failed for ${_targetPubkey!.substring(0, 8)}: $error', name: 'ProfileScreen', category: LogCategory.ui);
      });
    } catch (e) {
      Log.error('Error initiating profile videos load: $e', name: 'ProfileScreen', category: LogCategory.ui);
    }
  }
  
  void _loadUserProfile() {
    if (_targetPubkey == null) return;
    final userProfileService = context.read<UserProfileService>();
    userProfileService.fetchProfile(_targetPubkey!);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer5<AuthService, UserProfileService, SocialService, ProfileStatsProvider, ProfileVideosProvider>(
      builder: (context, authService, userProfileService, socialService, profileStatsProvider, profileVideosProvider, child) {
        final authProfile = _isOwnProfile ? authService.currentProfile : null;
        final cachedProfile = !_isOwnProfile ? userProfileService.getCachedProfile(_targetPubkey!) : null;
        final userName = authProfile?.displayName ?? cachedProfile?.displayName ?? 'Anonymous';
        
        return Scaffold(
          backgroundColor: VineTheme.backgroundColor,
          body: Stack(
            children: [
              DefaultTabController(
                length: 3,
                child: NestedScrollView(
                  controller: _scrollController,
                  headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                    return [
                      // App Bar
                      SliverAppBar(
                        backgroundColor: VineTheme.vineGreen,
                        pinned: true,
                        title: Row(
                          children: [
                            const Icon(Icons.lock_outline, color: VineTheme.whiteText, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              userName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          if (_isOwnProfile) ...[
                            IconButton(
                              icon: const Icon(Icons.add_box_outlined, color: Colors.white),
                              onPressed: _createNewVine,
                            ),
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  Log.debug('📱 Hamburger menu tapped', name: 'ProfileScreen', category: LogCategory.ui);
                                  _showOptionsMenu();
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Icon(
                                    Icons.menu,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ] else ...[
                            IconButton(
                              icon: const Icon(Icons.more_vert, color: Colors.white),
                              onPressed: _showUserOptions,
                            ),
                          ],
                        ],
                      ),
                      
                      // Profile Header
                      SliverToBoxAdapter(
                        child: _buildScrollableProfileHeader(authService, userProfileService, profileStatsProvider),
                      ),
                      
                      // Stats Row
                      SliverToBoxAdapter(
                        child: _buildStatsRow(profileStatsProvider),
                      ),
                      
                      // Action Buttons
                      SliverToBoxAdapter(
                        child: _buildActionButtons(socialService),
                      ),
                      
                      // Sticky Tab Bar
                      SliverPersistentHeader(
                        pinned: true,
                        delegate: _SliverAppBarDelegate(
                          TabBar(
                            controller: _tabController,
                            indicatorColor: Colors.white,
                            indicatorWeight: 2,
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.grey,
                            tabs: const [
                              Tab(icon: Icon(Icons.grid_on, size: 20)),
                              Tab(icon: Icon(Icons.favorite_border, size: 20)),
                              Tab(icon: Icon(Icons.repeat, size: 20)),
                            ],
                          ),
                        ),
                      ),
                    ];
                  },
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSliverVinesGrid(profileVideosProvider),
                      _buildSliverLikedGrid(socialService),
                      _buildSliverRepostsGrid(),
                    ],
                  ),
                ),
              ),
              
              // Video overlay for full-screen playback
              if (_playingVideoId != null)
                _buildVideoOverlay(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScrollableProfileHeader(
    AuthService authService, 
    UserProfileService userProfileService,
    ProfileStatsProvider profileStatsProvider,
  ) {
    final authProfile = _isOwnProfile ? authService.currentProfile : null;
    final cachedProfile = !_isOwnProfile ? userProfileService.getCachedProfile(_targetPubkey!) : null;
    
    final profilePictureUrl = authProfile?.picture ?? cachedProfile?.picture;
    final displayName = authProfile?.displayName ?? cachedProfile?.displayName;
    final hasCustomName = displayName != null && 
                          !displayName.startsWith('npub1') &&
                          displayName != 'Anonymous';
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Setup profile banner for new users with default names (only on own profile)
          if (_isOwnProfile && !hasCustomName)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.purple, Colors.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Complete Your Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Add your name, bio, and picture to get started',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _setupProfile(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.purple,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Set Up',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          
          // Profile picture and stats row
          Row(
            children: [
              // Profile picture
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.purple, Colors.pink, Colors.orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey,
                  backgroundImage: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                      ? NetworkImage(profilePictureUrl)
                      : null,
                  child: profilePictureUrl == null || profilePictureUrl.isEmpty
                      ? const Icon(Icons.person, color: Colors.white, size: 40)
                      : null,
                ),
              ),
              
              const SizedBox(width: 20),
              
              // Stats
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDynamicStatColumn(
                      profileStatsProvider.hasData ? profileStatsProvider.stats!.videoCount : null,
                      'Vines',
                      profileStatsProvider.isLoading,
                    ),
                    _buildDynamicStatColumn(
                      profileStatsProvider.hasData ? profileStatsProvider.stats!.followers : null,
                      'Followers',
                      profileStatsProvider.isLoading,
                    ),
                    _buildDynamicStatColumn(
                      profileStatsProvider.hasData ? profileStatsProvider.stats!.following : null,
                      'Following',
                      profileStatsProvider.isLoading,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Name and bio
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SelectableText(
                      displayName ?? 'Anonymous',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    // Add NIP-05 verification badge if verified
                    if ((authProfile?.nip05 ?? cachedProfile?.nip05) != null && 
                        (authProfile?.nip05 ?? cachedProfile?.nip05)!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                // Show NIP-05 identifier if present
                if ((authProfile?.nip05 ?? cachedProfile?.nip05) != null && 
                    (authProfile?.nip05 ?? cachedProfile?.nip05)!.isNotEmpty)
                  Text(
                    authProfile?.nip05 ?? cachedProfile?.nip05 ?? '',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                const SizedBox(height: 4),
                if ((authProfile?.about ?? cachedProfile?.about) != null && (authProfile?.about ?? cachedProfile?.about)!.isNotEmpty)
                  SelectableText(
                    (authProfile?.about ?? cachedProfile?.about)!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                const SizedBox(height: 8),
                // Public key display with copy functionality
                if (_targetPubkey != null)
                  GestureDetector(
                    onTap: () => _copyNpubToClipboard(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey[600]!, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SelectableText(
                            NostrEncoding.encodePublicKey(_targetPubkey!),
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.copy,
                            color: Colors.grey,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverVinesGrid(ProfileVideosProvider profileVideosProvider) {
    if (profileVideosProvider.isLoading && profileVideosProvider.videoCount == 0) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      );
    }

    if (profileVideosProvider.hasError) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Error loading videos',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                profileVideosProvider.error ?? 'Unknown error',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => profileVideosProvider.refreshVideos(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                  foregroundColor: VineTheme.whiteText,
                ),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (!profileVideosProvider.hasVideos) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_outlined, color: Colors.grey, size: 64),
              const SizedBox(height: 16),
              const Text(
                'No Videos Yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isOwnProfile 
                  ? 'Share your first video to see it here'
                  : 'This user hasn\'t shared any videos yet',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),
              IconButton(
                onPressed: () async {
                  Log.debug('Manual refresh videos requested for ${_targetPubkey?.substring(0, 8)}', name: 'ProfileScreen', category: LogCategory.ui);
                  if (_targetPubkey != null) {
                    try {
                      await profileVideosProvider.refreshVideos();
                      Log.info('Manual refresh completed', name: 'ProfileScreen', category: LogCategory.ui);
                    } catch (e) {
                      Log.error('Manual refresh failed: $e', name: 'ProfileScreen', category: LogCategory.ui);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Refresh failed: $e')),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.refresh, color: VineTheme.vineGreen, size: 28),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(2),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= profileVideosProvider.videoCount) {
                  return Container(
                    decoration: BoxDecoration(
                      color: VineTheme.cardBackground,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: VineTheme.vineGreen,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }

                final videoEvent = profileVideosProvider.videos[index];
                
                return GestureDetector(
                  onTap: () => _openVine(videoEvent),
                  child: Container(
                    decoration: BoxDecoration(
                      color: VineTheme.cardBackground,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Stack(
                      children: [
                        // Video thumbnail
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: videoEvent.thumbnailUrl != null && videoEvent.thumbnailUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: videoEvent.thumbnailUrl!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        gradient: LinearGradient(
                                          colors: [
                                            VineTheme.vineGreen.withValues(alpha: 0.3),
                                            Colors.blue.withValues(alpha: 0.3),
                                          ],
                                        ),
                                      ),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: VineTheme.whiteText,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        gradient: LinearGradient(
                                          colors: [
                                            VineTheme.vineGreen.withValues(alpha: 0.3),
                                            Colors.blue.withValues(alpha: 0.3),
                                          ],
                                        ),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.play_circle_outline,
                                          color: VineTheme.whiteText,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      gradient: LinearGradient(
                                        colors: [
                                          VineTheme.vineGreen.withValues(alpha: 0.3),
                                          Colors.blue.withValues(alpha: 0.3),
                                        ],
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.play_circle_outline,
                                        color: VineTheme.whiteText,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        
                        // Play icon overlay
                        const Center(
                          child: Icon(
                            Icons.play_circle_filled,
                            color: Colors.white70,
                            size: 32,
                          ),
                        ),
                        
                        // Duration indicator
                        if (videoEvent.duration != null)
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                videoEvent.formattedDuration,
                                style: const TextStyle(
                                  color: VineTheme.whiteText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
              childCount: profileVideosProvider.hasMore
                  ? profileVideosProvider.videoCount + 1
                  : profileVideosProvider.videoCount,
            ),
          ),
        ),
        // Load more trigger
        if (profileVideosProvider.hasMore && !profileVideosProvider.isLoadingMore)
          SliverToBoxAdapter(
            child: Container(
              height: 80,
              alignment: Alignment.center,
              child: ElevatedButton(
                onPressed: () => profileVideosProvider.loadMoreVideos(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Load More'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSliverLikedGrid(SocialService socialService) {
    // Placeholder for liked grid - implement similar to vines grid
    return const SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, color: Colors.grey, size: 64),
            SizedBox(height: 16),
            Text(
              'No Liked Videos Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Videos you like will appear here',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverRepostsGrid() {
    // Placeholder for reposts grid - implement similar to vines grid
    return const SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.repeat, color: Colors.grey, size: 64),
            SizedBox(height: 16),
            Text(
              'No Reposts Yet',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Videos you repost will appear here',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper methods (copied from original)
  Widget _buildDynamicStatColumn(int? count, String label, bool isLoading) {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isLoading
              ? const Text(
                  '—',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                )
              : Text(
                  count != null ? _formatCount(count) : '—',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
  
  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }

  Widget _buildStatsRow(ProfileStatsProvider profileStatsProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: profileStatsProvider.isLoading
                    ? const Text(
                        '—',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : Text(
                        _formatCount(profileStatsProvider.stats?.totalViews ?? 0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
              Text(
                'Total Views',
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: profileStatsProvider.isLoading
                    ? const Text(
                        '—',
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : Text(
                        _formatCount(profileStatsProvider.stats?.totalLikes ?? 0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
              Text(
                'Total Likes',
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(SocialService socialService) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          if (_isOwnProfile) ...[
            Expanded(
              child: ElevatedButton(
                onPressed: _editProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Edit Profile'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _shareProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Share Profile'),
              ),
            ),
          ] else ...[
            Expanded(
              child: Consumer<SocialService>(
                builder: (context, socialService, child) {
                  final isFollowing = socialService.isFollowing(_targetPubkey!);
                  return ElevatedButton(
                    onPressed: isFollowing ? _unfollowUser : _followUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isFollowing ? Colors.grey[700] : Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(isFollowing ? 'Following' : 'Follow'),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: _sendMessage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Icon(Icons.mail_outline),
            ),
          ],
        ],
      ),
    );
  }

  // All the action methods
  void _createNewVine() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UniversalCameraScreen(),
      ),
    );
  }

  void _showOptionsMenu() {
    // Implementation from original file
  }

  void _showUserOptions() {
    // Implementation from original file
  }

  void _setupProfile() async {
    // Implementation from original file
  }

  void _editProfile() async {
    // Implementation from original file
  }

  void _shareProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing profile...')),
    );
  }

  void _followUser() async {
    // Implementation from original file
  }

  void _unfollowUser() async {
    // Implementation from original file
  }

  void _sendMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening messages...')),
    );
  }

  void _openVine(VideoEvent videoEvent) {
    setState(() {
      _playingVideoId = videoEvent.id;
    });
  }

  Widget _buildVideoOverlay() {
    return Consumer<ProfileVideosProvider>(
      builder: (context, profileVideosProvider, child) {
        VideoEvent video = profileVideosProvider.videos.firstWhere(
          (v) => v.id == _playingVideoId,
          orElse: () => VideoEvent(
            id: _playingVideoId!,
            pubkey: _targetPubkey ?? '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            content: 'Video not found',
            timestamp: DateTime.now(),
          ),
        );

        if (video.content == 'Video not found') {
          final videoEventService = Provider.of<VideoEventService>(context, listen: false);
          final allVideos = videoEventService.videoEvents;
          final foundVideo = allVideos.firstWhere(
            (v) => v.id == _playingVideoId,
            orElse: () => video,
          );
          video = foundVideo;
        }

        return VideoFullscreenOverlay(
          video: video,
          onClose: () {
            setState(() {
              _playingVideoId = null;
            });
          },
        );
      },
    );
  }

  void _copyNpubToClipboard() async {
    if (_targetPubkey == null) return;
    
    try {
      final npub = NostrEncoding.encodePublicKey(_targetPubkey!);
      await Clipboard.setData(ClipboardData(text: npub));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check, color: Colors.white),
                SizedBox(width: 8),
                Text('Public key copied to clipboard'),
              ],
            ),
            backgroundColor: VineTheme.vineGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Custom delegate for sticky tab bar
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: VineTheme.backgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}