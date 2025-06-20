import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:nostr/nostr.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import '../services/social_service.dart';
import '../providers/profile_stats_provider.dart';
import '../models/video_event.dart';
import '../theme/vine_theme.dart';
import 'profile_setup_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final bool _isOwnProfile = true; // TODO: Determine if viewing own profile

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // Load profile stats when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileStats();
    });
  }
  
  void _loadProfileStats() {
    final authService = context.read<AuthService>();
    final profileStatsProvider = context.read<ProfileStatsProvider>();
    
    final currentUserPubkey = authService.currentPublicKeyHex;
    if (currentUserPubkey != null) {
      profileStatsProvider.loadProfileStats(currentUserPubkey);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer4<AuthService, UserProfileService, SocialService, ProfileStatsProvider>(
      builder: (context, authService, userProfileService, socialService, profileStatsProvider, child) {
        final userProfile = authService.currentProfile;
        final userName = userProfile?.displayName ?? 'Anonymous';
        
        return Scaffold(
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
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: _showOptionsMenu,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: _showUserOptions,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Profile header
          _buildProfileHeader(socialService),
          
          // Stats row
          _buildStatsRow(),
          
          // Action buttons
          _buildActionButtons(),
          
          const SizedBox(height: 20),
          
          // Tab bar
          _buildTabBar(),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVinesGrid(),
                _buildLikedGrid(),
                _buildPrivateGrid(),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildProfileHeader(SocialService socialService) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final userProfile = authService.currentProfile;
        final profilePictureUrl = userProfile?.picture;
        final hasCustomName = userProfile?.displayName != null && 
                              !userProfile!.displayName.startsWith('npub1') &&
                              userProfile.displayName != 'Anonymous';
        
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Setup profile banner for new users with default names
              if (!hasCustomName)
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
                child: FutureBuilder<Map<String, int>>(
                  future: authService.currentPublicKeyHex != null 
                      ? socialService.getFollowerStats(authService.currentPublicKeyHex!)
                      : Future.value({'followers': 0, 'following': 0}),
                  builder: (context, snapshot) {
                    final stats = snapshot.data ?? {'followers': 0, 'following': 0};
                    final followersCount = stats['followers'] ?? 0;
                    final followingCount = stats['following'] ?? 0;
                    
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildDynamicStatColumn(
                          profileStatsProvider.hasData ? profileStatsProvider.stats!.videoCount : null,
                          'Vines',
                          profileStatsProvider.isLoading,
                        ),
                        _buildStatColumn(_formatCount(followersCount), 'Followers'),
                        _buildStatColumn(_formatCount(followingCount), 'Following'),
                      ],
                    );
                  },
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
                Text(
                  userProfile?.displayName ?? 'Anonymous',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                if (userProfile?.about != null && userProfile!.about!.isNotEmpty)
                  Text(
                    userProfile.about!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.3,
                    ),
                  ),
                const SizedBox(height: 8),
                // Public key display
                if (authService.currentNpub != null)
                  Text(
                    authService.currentNpub!,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontFamily: 'monospace',
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

  Widget _buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
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
  
  /// Build a stat column with loading state support
  Widget _buildDynamicStatColumn(int? count, String label, bool isLoading) {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  count != null ? _formatCount(count) : '...',
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

  Widget _buildStatsRow() {
    return Consumer<ProfileStatsProvider>(
      builder: (context, profileStatsProvider, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: profileStatsProvider.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                  const Text(
                    'Total Views',
                    style: TextStyle(
                      color: Colors.grey,
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
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
                  const Text(
                    'Total Likes',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Column(
                children: [
                  Text(
                    'Gold',
                    style: TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'Creator Tier',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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
              child: ElevatedButton(
                onPressed: _followUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Follow'),
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

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!, width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 2,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        tabs: const [
          Tab(icon: Icon(Icons.grid_on, size: 20)),
          Tab(icon: Icon(Icons.favorite_border, size: 20)),
          Tab(icon: Icon(Icons.lock_outline, size: 20)),
        ],
      ),
    );
  }

  Widget _buildVinesGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        childAspectRatio: 0.7,
      ),
      itemCount: 21, // Placeholder count
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _openVine(index),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              children: [
                // Thumbnail placeholder
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
                
                // View count
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.play_arrow, color: Colors.white, size: 12),
                        Text(
                          '${(index + 1) * 234}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLikedGrid() {
    return Consumer2<AuthService, SocialService>(
      builder: (context, authService, socialService, child) {
        final currentUserPubkey = authService.currentPublicKeyHex;
        
        if (currentUserPubkey == null) {
          return const Center(
            child: Text(
              'Sign in to view liked videos',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        
        return FutureBuilder<List<Event>>(
          future: socialService.fetchLikedEvents(currentUserPubkey),
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
                .where((event) => event.kind == 34550) // Filter for video events
                .map((event) {
                  try {
                    return VideoEvent.fromNostrEvent(event);
                  } catch (e) {
                    debugPrint('Error converting event to VideoEvent: $e');
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

  Widget _buildPrivateGrid() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, color: Colors.grey, size: 64),
          SizedBox(height: 16),
          Text(
            'Private Vines',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Only you can see your private vines',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _createNewVine() {
    // TODO: Navigate to camera screen
    Navigator.pushNamed(context, '/camera');
  }

  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
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
              leading: const Icon(Icons.archive, color: Colors.white),
              title: const Text('Archive', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.qr_code, color: Colors.white),
              title: const Text('QR Code', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserOptions() {
    // TODO: Implement user options for viewing other profiles
  }

  void _setupProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProfileSetupScreen(isNewUser: true),
      ),
    );
  }

  void _editProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProfileSetupScreen(isNewUser: false),
      ),
    );
  }

  void _shareProfile() {
    // TODO: Implement profile sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing profile...')),
    );
  }

  void _followUser() async {
    // TODO: Get the actual pubkey of the user we're viewing
    // For now, this is a placeholder since _isOwnProfile is hardcoded to true
    final targetPubkey = 'placeholder_pubkey'; // This would come from navigation arguments
    
    try {
      final socialService = context.read<SocialService>();
      await socialService.followUser(targetPubkey);
      
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

  void _sendMessage() {
    // TODO: Implement messaging functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening messages...')),
    );
  }

  void _openVine(int index) {
    // TODO: Navigate to vine detail screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening vine $index')),
    );
  }

  void _openLikedVideo(VideoEvent videoEvent) {
    // TODO: Navigate to video detail screen or open in feed
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening liked video: ${videoEvent.title ?? videoEvent.id.substring(0, 8)}')),
    );
  }

  void _openSettings() {
    // TODO: Navigate to settings screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening settings...')),
    );
  }
}