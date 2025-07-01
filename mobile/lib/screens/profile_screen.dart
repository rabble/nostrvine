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

class ProfileScreen extends StatefulWidget {
  final String? profilePubkey; // If null, shows current user's profile
  
  const ProfileScreen({super.key, this.profilePubkey});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isOwnProfile = true;
  String? _targetPubkey;
  String? _playingVideoId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Determine if viewing own profile and set target pubkey
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProfile();
    });
  }
  
  
  Future<void> _initializeProfile() async {
    final authService = context.read<AuthService>();
    final currentUserPubkey = authService.currentPublicKeyHex;
    
    // Ensure AuthService is properly initialized before proceeding
    if (!authService.isAuthenticated || currentUserPubkey == null) {
      Log.warning('AuthService not ready, deferring profile initialization', name: 'ProfileScreen', category: LogCategory.ui);
      // Retry after a short delay
      Future.delayed(const Duration(milliseconds: 100), _initializeProfile);
      return;
    }
    
    // Clear any playing video when switching profiles
    _playingVideoId = null;
    
    // Determine target pubkey and ownership
    setState(() {
      _targetPubkey = widget.profilePubkey ?? currentUserPubkey;
      _isOwnProfile = _targetPubkey == currentUserPubkey;
    });
    
    Log.info('🔍 Profile init debug:', name: 'ProfileScreen', category: LogCategory.ui);
    Log.info('  - widget.profilePubkey: ${widget.profilePubkey?.substring(0, 8) ?? "null"}', name: 'ProfileScreen', category: LogCategory.ui);
    Log.info('  - currentUserPubkey: ${currentUserPubkey.substring(0, 8)}', name: 'ProfileScreen', category: LogCategory.ui);
    Log.info('  - _isOwnProfile: $_isOwnProfile', name: 'ProfileScreen', category: LogCategory.ui);
    Log.info('  - _targetPubkey: ${_targetPubkey?.substring(0, 8) ?? "null"}', name: 'ProfileScreen', category: LogCategory.ui);
    
    // Log current cached profile
    final userProfileService = context.read<UserProfileService>();
    final cachedProfile = userProfileService.getCachedProfile(_targetPubkey!);
    if (cachedProfile != null) {
      Log.info('📋 ProfileScreen: Cached profile found on init:', name: 'ProfileScreen', category: LogCategory.ui);
      Log.info('  - name: ${cachedProfile.name}', name: 'ProfileScreen', category: LogCategory.ui);
      Log.info('  - displayName: ${cachedProfile.displayName}', name: 'ProfileScreen', category: LogCategory.ui);
      Log.info('  - about: ${cachedProfile.about}', name: 'ProfileScreen', category: LogCategory.ui);
      Log.info('  - eventId: ${cachedProfile.eventId}', name: 'ProfileScreen', category: LogCategory.ui);
      Log.info('  - createdAt: ${cachedProfile.createdAt}', name: 'ProfileScreen', category: LogCategory.ui);
    } else {
      Log.info('📋 ProfileScreen: No cached profile found on init for ${_targetPubkey!.substring(0, 8)}...', name: 'ProfileScreen', category: LogCategory.ui);
    }
    
    // Debug video count vs stats count mismatch
    final profileVideosProvider = context.read<ProfileVideosProvider>();
    final profileStatsProvider = context.read<ProfileStatsProvider>();
    
    Log.warning('🔍 ProfileScreen: Debug video count mismatch check:', name: 'ProfileScreen', category: LogCategory.ui);
    Log.warning('  - ProfileVideosProvider count: ${profileVideosProvider.videoCount}', name: 'ProfileScreen', category: LogCategory.ui);
    Log.warning('  - ProfileStatsProvider count: ${profileStatsProvider.stats?.videoCount ?? "null"}', name: 'ProfileScreen', category: LogCategory.ui);
    Log.warning('  - Current user pubkey: ${context.read<AuthService>().currentPublicKeyHex?.substring(0, 8) ?? "null"}', name: 'ProfileScreen', category: LogCategory.ui);
    Log.warning('  - Target pubkey: ${_targetPubkey?.substring(0, 8) ?? "null"}', name: 'ProfileScreen', category: LogCategory.ui);
    
    // Load profile data for the target user
    if (_targetPubkey != null) {
      // Force refresh both stats and videos to resolve any cache issues
      Log.info('🔄 Forcing refresh of profile data for ${_targetPubkey!.substring(0, 8)}', name: 'ProfileScreen', category: LogCategory.ui);
      
      // Clear any cache and reload
      try {
        await profileStatsProvider.refreshStats();
        await profileVideosProvider.refreshVideos(); 
      } catch (e) {
        Log.error('Error during force refresh: $e', name: 'ProfileScreen', category: LogCategory.ui);
      }
      
      _loadProfileStats();
      _loadProfileVideos();
      
      // If viewing another user's profile, fetch their profile data
      if (!_isOwnProfile) {
        _loadUserProfile();
      }
      
      // Note: Video events are managed globally by Riverpod providers
      // Profile-specific video loading is handled by ProfileVideosProvider
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
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Check if the profile pubkey has changed
    if (widget.profilePubkey != oldWidget.profilePubkey) {
      Log.info('Profile pubkey changed from ${oldWidget.profilePubkey} to ${widget.profilePubkey}', 
               name: 'ProfileScreen', category: LogCategory.ui);
      // Reinitialize with new profile
      _initializeProfile();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Consumer5<AuthService, UserProfileService, SocialService, ProfileStatsProvider, ProfileVideosProvider>(
        builder: (context, authService, userProfileService, socialService, profileStatsProvider, profileVideosProvider, child) {
        // Get profile for display name in app bar
        final authProfile = _isOwnProfile ? authService.currentProfile : null;
        final cachedProfile = _targetPubkey != null ? userProfileService.getCachedProfile(_targetPubkey!) : null;
        final userName = cachedProfile?.bestDisplayName ?? authProfile?.displayName ?? 'Anonymous';
        
        
        return Scaffold(
          key: ValueKey('profile_screen_${_targetPubkey ?? 'unknown'}'),
          backgroundColor: VineTheme.backgroundColor,
          appBar: AppBar(
            backgroundColor: VineTheme.vineGreen,
            elevation: 1,
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
                  Log.debug('� Hamburger menu tapped', name: 'ProfileScreen', category: LogCategory.ui);
                  _showOptionsMenu();
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
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
      body: Stack(
        children: [
          NestedScrollView(
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Profile header
                      _buildProfileHeader(socialService, profileStatsProvider),
                      
                      // Stats row - wrapped in error boundary
                      Builder(
                        builder: (context) {
                          try {
                            return _buildStatsRow(profileStatsProvider);
                          } catch (e) {
                            Log.error('Error building stats row: $e', name: 'ProfileScreen', category: LogCategory.ui);
                            return Container(
                              height: 50,
                              color: Colors.grey[800],
                              child: const Center(
                                child: Text('Stats loading...', style: TextStyle(color: Colors.white)),
                              ),
                            );
                          }
                        },
                      ),
                      
                      // Action buttons - wrapped in error boundary
                      Builder(
                        builder: (context) {
                          try {
                            return _buildActionButtons();
                          } catch (e) {
                            Log.error('Error building action buttons: $e', name: 'ProfileScreen', category: LogCategory.ui);
                            return Container(height: 50);
                          }
                        },
                      ),
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyTabBarDelegate(
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
              key: ValueKey('tab_view_${_targetPubkey ?? 'unknown'}'),
              controller: _tabController,
              children: [
                _buildVinesGrid(),
                _buildLikedGrid(),
                _buildRepostsGrid(),
              ],
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
    } catch (e, stackTrace) {
      Log.error('ProfileScreen build error: $e', name: 'ProfileScreen', category: LogCategory.ui);
      Log.error('Stack trace: $stackTrace', name: 'ProfileScreen', category: LogCategory.ui);
      
      // Return a simple error screen instead of crashing
      return Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        appBar: AppBar(
          backgroundColor: VineTheme.vineGreen,
          title: const Text('Profile', style: TextStyle(color: Colors.white)),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 64),
              SizedBox(height: 16),
              Text(
                'Error loading profile',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              SizedBox(height: 8),
              Text(
                'Please try again',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildProfileHeader(SocialService socialService, ProfileStatsProvider profileStatsProvider) {
    return Consumer2<AuthService, UserProfileService>(
      builder: (context, authService, userProfileService, child) {
        // Get the profile data for the target user (could be current user or another user)
        final authProfile = _isOwnProfile ? authService.currentProfile : null;
        final cachedProfile = _targetPubkey != null ? userProfileService.getCachedProfile(_targetPubkey!) : null;
        
        final profilePictureUrl = authProfile?.picture ?? cachedProfile?.picture;
        // Always prefer cachedProfile (UserProfileService) over authProfile for display name
        // because UserProfileService has the most up-to-date data from the relay
        final displayName = cachedProfile?.bestDisplayName ?? authProfile?.displayName ?? 'Anonymous';
        final hasCustomName = displayName != 'Anonymous' && 
                              !displayName.startsWith('npub1');
        
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
                          children: [
                            const Text(
                              'Complete Your Profile',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
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
              
              // Profile picture and follow button row
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
      },
    );
  }

  
  /// Build a stat column with loading state support
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
  
  /// Format large numbers (e.g., 1234 -> "1.2K")
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

  Widget _buildActionButtons() {
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


  Widget _buildVinesGrid() {
    return Consumer<ProfileVideosProvider>(
      builder: (context, profileVideosProvider, child) {
        Log.error('� ProfileVideosProvider state: loading=${profileVideosProvider.isLoading}, hasVideos=${profileVideosProvider.hasVideos}, hasError=${profileVideosProvider.hasError}, videoCount=${profileVideosProvider.videoCount}, loadingState=${profileVideosProvider.loadingState}', name: 'ProfileScreen', category: LogCategory.ui);
        
        // Show loading state ONLY if actually loading
        if (profileVideosProvider.isLoading && profileVideosProvider.videoCount == 0) {
          return Center(
            child: GridView.builder(
              padding: const EdgeInsets.all(1),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: 9, // Show 9 placeholder tiles
              itemBuilder: (context, index) {
                return Container(
                  color: Colors.grey.shade900,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        }

    // Show error state
    if (profileVideosProvider.hasError) {
      return Center(
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
      );
    }

    // Show empty state
    if (!profileVideosProvider.hasVideos) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 80), // Add padding to avoid FAB overlap
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
              Icon(Icons.videocam_outlined, color: Colors.grey, size: 64),
              SizedBox(height: 16),
              Text(
                'No Videos Yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                _isOwnProfile 
                  ? 'Share your first video to see it here'
                  : 'This user hasn\'t shared any videos yet',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32), // Increased spacing
              // Changed from centered button to an icon button in the top corner
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: IconButton(
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
                ),
              ),
            ],
          ),
          ),
        ),
      );
    }

    // Show video grid
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        // Load more videos when scrolling near the bottom
        if (!profileVideosProvider.isLoadingMore &&
            profileVideosProvider.hasMore &&
            scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 200) {
          profileVideosProvider.loadMoreVideos();
        }
        return false;
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
          childAspectRatio: 1.0, // Square aspect ratio for vine-style videos
        ),
        itemCount: profileVideosProvider.hasMore
            ? profileVideosProvider.videoCount + 1 // +1 for loading indicator
            : profileVideosProvider.videoCount,
        itemBuilder: (context, index) {
          // Show loading indicator at the end if loading more
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
          
          // Debug log video data
          if (index < 3) { // Only log first 3 to avoid spam
            Log.debug('Video $index: id=${videoEvent.id.substring(0, 8)}, thumbnail=${videoEvent.thumbnailUrl?.substring(0, 50) ?? "null"}, videoUrl=${videoEvent.videoUrl?.substring(0, 50) ?? "null"}', 
                     name: 'ProfileScreen', category: LogCategory.ui);
          }
          
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
      ),
    );
      },
    );
  }

  Widget _buildLikedGrid() {
    return Consumer2<AuthService, SocialService>(
      builder: (context, authService, socialService, child) {
        if (_targetPubkey == null) {
          return const Center(
            child: Text(
              'Sign in to view liked videos',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        
        return FutureBuilder<List<Event>>(
          future: socialService.fetchLikedEvents(_targetPubkey!),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Loading liked videos...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }
            
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading liked videos',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            
            final likedEvents = snapshot.data ?? [];
            
            if (likedEvents.isEmpty) {
              return const Center(
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
              );
            }
            
            // Convert Events to VideoEvents for display
            final videoEvents = likedEvents
                .where((event) => event.kind == 22) // Filter for NIP-71 video events
                .map((event) {
                  try {
                    return VideoEvent.fromNostrEvent(event);
                  } catch (e) {
                    Log.error('Error converting event to VideoEvent: $e', name: 'ProfileScreen', category: LogCategory.ui);
                    return null;
                  }
                })
                .where((videoEvent) => videoEvent != null)
                .cast<VideoEvent>()
                .toList();
            
            return GridView.builder(
              padding: const EdgeInsets.all(2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: 0.7,
              ),
              itemCount: videoEvents.length,
              itemBuilder: (context, index) {
                final videoEvent = videoEvents[index];
                
                return GestureDetector(
                  onTap: () => _openLikedVideo(videoEvent),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Stack(
                      children: [
                        // Video thumbnail
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.withValues(alpha: 0.3),
                                  Colors.blue.withValues(alpha: 0.3),
                                ],
                              ),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.play_circle_outline,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        
                        // Like indicator
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: 16,
                          ),
                        ),
                        
                        // Video title if available
                        if (videoEvent.title?.isNotEmpty == true)
                          Positioned(
                            bottom: 4,
                            left: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                videoEvent.title!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRepostsGrid() {
    return Consumer2<AuthService, VideoEventService>(
      builder: (context, authService, videoEventService, child) {
        if (_targetPubkey == null) {
          return const Center(
            child: Text(
              'Sign in to view reposts',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        
        // Get all video events and filter for reposts by this user
        final allVideos = videoEventService.videoEvents;
        final userReposts = allVideos.where((video) => 
          video.isRepost && video.reposterPubkey == _targetPubkey
        ).toList();
        
        if (userReposts.isEmpty) {
          return const Center(
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
          );
        }
        
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 0.7,
          ),
          itemCount: userReposts.length,
          itemBuilder: (context, index) {
            final videoEvent = userReposts[index];
            
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
                    
                    // Repost indicator
                    Positioned(
                      top: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.repeat,
                          color: VineTheme.vineGreen,
                          size: 16,
                        ),
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
        );
      },
    );
  }

  void _createNewVine() {
    // Navigate to universal camera screen for recording a new vine
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UniversalCameraScreen(),
      ),
    );
  }

  void _showOptionsMenu() {
    Log.debug('� _showOptionsMenu called', name: 'ProfileScreen', category: LogCategory.ui);
    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.grey[900],
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.white),
              title: const Text('Settings', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _openSettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.white),
              title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _editProfile();
              },
            ),
          ],
        ),
      ),
    );
    } catch (e) {
      Log.error('Error showing options menu: $e', name: 'ProfileScreen', category: LogCategory.ui);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening menu: $e')),
      );
    }
  }

  void _showUserOptions() {
    Log.verbose('_showUserOptions called for user profile', name: 'ProfileScreen', category: LogCategory.ui);
    try {
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.grey[900],
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.share, color: Colors.white),
                title: const Text('Share Profile', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _shareProfile();
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.white),
                title: const Text('Copy Public Key', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _copyNpubToClipboard();
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Block User', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _blockUser();
                },
              ),
              ListTile(
                leading: const Icon(Icons.report, color: Colors.orange),
                title: const Text('Report User', style: TextStyle(color: Colors.orange)),
                onTap: () {
                  Navigator.pop(context);
                  _reportUser();
                },
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      Log.error('Error showing user options menu: $e', name: 'ProfileScreen', category: LogCategory.ui);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening menu: $e')),
      );
    }
  }

  void _setupProfile() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProfileSetupScreen(isNewUser: true),
      ),
    );
    
    // Refresh profile data when returning from setup
    if (result == true && mounted) {
      setState(() {
        // Trigger rebuild to show updated profile
      });
      
      // Refresh profile data
      final authService = context.read<AuthService>();
      final userProfileService = context.read<UserProfileService>();
      if (authService.currentPublicKeyHex != null) {
        userProfileService.fetchProfile(authService.currentPublicKeyHex!);
      }
      
      // Reload profile stats and videos
      _loadProfileStats();
      _loadProfileVideos();
    }
  }

  void _editProfile() async {
    Log.info('📝 Edit Profile button tapped', name: 'ProfileScreen', category: LogCategory.ui);
    
    // Log current profile before editing
    final userProfileService = context.read<UserProfileService>();
    final authService = context.read<AuthService>();
    final currentPubkey = authService.currentPublicKeyHex!;
    
    final profileBeforeEdit = userProfileService.getCachedProfile(currentPubkey);
    if (profileBeforeEdit != null) {
      Log.info('📋 Profile before edit:', name: 'ProfileScreen', category: LogCategory.ui);
      Log.info('  - name: ${profileBeforeEdit.name}', name: 'ProfileScreen', category: LogCategory.ui);
      Log.info('  - about: ${profileBeforeEdit.about}', name: 'ProfileScreen', category: LogCategory.ui);
      Log.info('  - eventId: ${profileBeforeEdit.eventId}', name: 'ProfileScreen', category: LogCategory.ui);
    }
    
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProfileSetupScreen(isNewUser: false),
      ),
    );
    
    Log.info('📝 Returned from ProfileSetupScreen with result: $result', name: 'ProfileScreen', category: LogCategory.ui);
    
    // Refresh profile data when returning from setup
    if (result == true && mounted) {
      Log.info('✅ Profile update successful, refreshing data...', name: 'ProfileScreen', category: LogCategory.ui);
      
      // Force refresh the AuthService profile from UserProfileService
      await authService.refreshCurrentProfile(userProfileService);
      
      // Also refresh profile stats and videos
      _loadProfileStats();
      _loadProfileVideos();
      
      // Force a rebuild to show updated profile
      setState(() {});
    }
    
  }

  void _shareProfile() {
    // TODO: Implement profile sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing profile...')),
    );
  }

  void _blockUser() {
    if (_targetPubkey == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Block User', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to block this user? You won\'t see their content anymore.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement blocking functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User blocked successfully')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _reportUser() {
    if (_targetPubkey == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Report User', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Report this user for inappropriate content or behavior?',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement reporting functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User reported successfully')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Report'),
          ),
        ],
      ),
    );
  }

  void _followUser() async {
    if (_targetPubkey == null) return;
    
    try {
      final socialService = context.read<SocialService>();
      await socialService.followUser(_targetPubkey!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully followed user!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to follow user: $e')),
        );
      }
    }
  }

  void _unfollowUser() async {
    if (_targetPubkey == null) return;
    
    try {
      final socialService = context.read<SocialService>();
      await socialService.unfollowUser(_targetPubkey!);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully unfollowed user!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unfollow user: $e')),
        );
      }
    }
  }

  void _sendMessage() {
    // TODO: Implement messaging functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening messages...')),
    );
  }

  void _openVine(VideoEvent videoEvent) {
    setState(() {
      _playingVideoId = videoEvent.id;
    });
  }

  void _openLikedVideo(VideoEvent videoEvent) {
    setState(() {
      _playingVideoId = videoEvent.id;
    });
  }

  Widget _buildVideoOverlay() {
    return Consumer<ProfileVideosProvider>(
      builder: (context, profileVideosProvider, child) {
        // Find the video in profile videos first
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

        // If not found in profile videos, try to find in liked videos or reposts
        if (video.content == 'Video not found') {
          // Get from VideoEventService which has all videos
          final videoEventService = Provider.of<VideoEventService>(context, listen: false);
          final allVideos = videoEventService.videoEvents;
          final foundVideo = allVideos.firstWhere(
            (v) => v.id == _playingVideoId,
            orElse: () => video, // Use the placeholder if still not found
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

  void _openSettings() {
    // Show settings menu with debug options
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.notifications, color: Colors.white),
              title: const Text('Notification Settings', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Navigate to notification settings
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Notification settings coming soon')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip, color: Colors.white),
              title: const Text('Privacy', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _openPrivacySettings();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud, color: Colors.white),
              title: const Text('Relay Settings', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Manage Nostr relays', style: TextStyle(color: Colors.grey)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RelaySettingsScreen(),
                  ),
                );
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.orange),
              title: const Text('Debug Menu', style: TextStyle(color: Colors.orange)),
              subtitle: const Text('Developer options', style: TextStyle(color: Colors.grey)),
              onTap: () {
                Navigator.pop(context);
                _openDebugMenu();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openDebugMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_circle_outline, color: Colors.green),
              title: const Text('Video Player Test', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Test video playback functionality', style: TextStyle(color: Colors.grey)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DebugVideoTestScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.cloud_queue, color: Colors.blue),
              title: const Text('Relay Status', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Check connection to Nostr relays', style: TextStyle(color: Colors.grey)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RelaySettingsScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.storage, color: Colors.purple),
              title: const Text('Clear Cache', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Clear video and image caches', style: TextStyle(color: Colors.grey)),
              onTap: () {
                Navigator.pop(context);
                // TODO: Clear cache
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cache cleared')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openPrivacySettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              
              // Title
              const Text(
                'Privacy Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    // Backup nsec key Section
                    ListTile(
                      leading: const Icon(Icons.key, color: Colors.purple),
                      title: const Text('Backup Private Key (nsec)', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Copy your private key for backup or use in other Nostr apps', style: TextStyle(color: Colors.grey)),
                      onTap: () {
                        Navigator.pop(context);
                        _showNsecBackupDialog();
                      },
                    ),
                    
                    const Divider(color: Colors.grey),
                    
                    // Import Different Identity Section
                    ListTile(
                      leading: const Icon(Icons.login, color: Colors.green),
                      title: const Text('Switch Identity', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Import a different Nostr identity using nsec', style: TextStyle(color: Colors.grey)),
                      onTap: () {
                        Navigator.pop(context);
                        _showSwitchIdentityDialog();
                      },
                    ),
                    
                    const Divider(color: Colors.grey),
                    
                    // Analytics Opt-Out Section
                    Consumer<AnalyticsService>(
                      builder: (context, analyticsService, child) {
                        return ListTile(
                          leading: const Icon(Icons.analytics_outlined, color: Colors.orange),
                          title: const Text('Analytics', style: TextStyle(color: Colors.white)),
                          subtitle: const Text('Help improve OpenVine by sharing anonymous usage data', style: TextStyle(color: Colors.grey)),
                          trailing: Switch(
                            value: analyticsService.analyticsEnabled,
                            onChanged: (value) async {
                              await analyticsService.setAnalyticsEnabled(value);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(value 
                                      ? 'Analytics enabled - Thank you for helping improve OpenVine!' 
                                      : 'Analytics disabled - Your privacy is respected'),
                                    backgroundColor: value ? Colors.green : Colors.orange,
                                  ),
                                );
                              }
                            },
                            activeColor: VineTheme.vineGreen,
                          ),
                        );
                      },
                    ),
                    
                    const Divider(color: Colors.grey),
                    
                    // Data Export Section
                    ListTile(
                      leading: const Icon(Icons.download, color: Colors.blue),
                      title: const Text('Export My Data', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Download all your posts and profile data', style: TextStyle(color: Colors.grey)),
                      onTap: () {
                        Navigator.pop(context);
                        _showDataExportDialog();
                      },
                    ),
                    
                    const Divider(color: Colors.grey),
                    
                    // Right to be Forgotten Section
                    ListTile(
                      leading: const Icon(Icons.delete_forever, color: Colors.red),
                      title: const Text('Right to be Forgotten', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Request deletion of all your data (NIP-62)', style: TextStyle(color: Colors.grey)),
                      onTap: () {
                        Navigator.pop(context);
                        _showRightToBeForgottenDialog();
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Explanation text
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'About Nostr Privacy',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Nostr is a decentralized protocol. While you can request deletion, data may persist on some relays. The "Right to be Forgotten" publishes a NIP-62 deletion request that compliant relays will honor.',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
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

  void _showDataExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Export Data', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This feature will compile and download all your posts, profile information, and associated data.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement data export
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Data export feature coming soon')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Export'),
          ),
        ],
      ),
    );
  }

  void _showRightToBeForgottenDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 8),
            const Text(
              'Right to be Forgotten',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will publish a NIP-62 deletion request to all relays requesting removal of:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            const Text(
              '• All your posts and videos\n'
              '• Your profile information\n'
              '• Your reactions and comments\n'
              '• All associated metadata',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⚠️ WARNING: This action cannot be undone. While compliant relays will honor this request, some data may persist on non-compliant relays due to the decentralized nature of Nostr.',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmRightToBeForgotten();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _confirmRightToBeForgotten() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Final Confirmation',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Type "DELETE MY DATA" to confirm:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextFormField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'DELETE MY DATA',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.grey[800],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                // Enable/disable button based on exact match
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _executeRightToBeForgotten();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete All Data'),
          ),
        ],
      ),
    );
  }

  void _executeRightToBeForgotten() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey[900],
          content: const Row(
            children: [
              CircularProgressIndicator(color: Colors.red),
              SizedBox(width: 16),
              Text(
                'Publishing deletion request...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );

      final socialService = context.read<SocialService>();
      await socialService.publishRightToBeForgotten();

      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.grey[900],
            title: const Text(
              'Deletion Request Sent',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Your NIP-62 deletion request has been published to all relays. Compliant relays will begin removing your data. This may take some time to propagate across the network.',
              style: TextStyle(color: Colors.grey),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Optionally log out the user
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish deletion request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyNpubToClipboard() async {
    if (_targetPubkey == null) return;
    
    try {
      final npub = NostrEncoding.encodePublicKey(_targetPubkey!);
      await Clipboard.setData(ClipboardData(text: npub));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Public key copied to clipboard'),
              ],
            ),
            backgroundColor: VineTheme.vineGreen,
            duration: const Duration(seconds: 2),
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

  void _showNsecBackupDialog() async {
    final authService = context.read<AuthService>();
    final nsec = await authService.exportNsec();
    
    if (nsec == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No private key available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            const Icon(Icons.key, color: Colors.purple),
            const SizedBox(width: 8),
            const Text(
              'Backup Private Key',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your private key (nsec) allows you to access your account from any Nostr app. Keep it safe and never share it publicly.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple, width: 1),
              ),
              child: SelectableText(
                nsec,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.yellow, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Store this safely! Anyone with this key can control your account.',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: nsec));
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Private key copied to clipboard'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            child: const Text('Copy to Clipboard'),
          ),
        ],
      ),
    );
  }

  void _showSwitchIdentityDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            const Icon(Icons.swap_horiz, color: Colors.green),
            const SizedBox(width: 8),
            const Text(
              'Switch Identity',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will sign you out of your current identity and allow you to import a different one.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Make sure you have backed up your current nsec before switching!',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Sign out current user (without deleting keys)
              final authService = context.read<AuthService>();
              await authService.signOut(deleteKeys: false);
              
              // Navigate to key import screen
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const KeyImportScreen(),
                  ),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

/// Delegate for creating a sticky tab bar in NestedScrollView
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _StickyTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      decoration: BoxDecoration(
        color: VineTheme.backgroundColor, // Match the main background
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_StickyTabBarDelegate oldDelegate) {
    return tabBar != oldDelegate.tabBar;
  }
}