// ABOUTME: Screen for viewing other users' profiles from their pubkey
// ABOUTME: Displays user info, videos, and provides follow/unfollow functionality

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/user_profile_service.dart';
import '../services/nostr_service_interface.dart';
import '../models/user_profile.dart';

class UserProfileScreen extends StatefulWidget {
  final String userPubkey;
  final String? initialDisplayName; // Optional hint for immediate display
  
  const UserProfileScreen({
    super.key,
    required this.userPubkey,
    this.initialDisplayName,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  UserProfile? _userProfile;
  bool _isLoading = true;
  bool _isOwnProfile = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); // Only public tabs for other users
    _loadUserProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final userProfileService = context.read<UserProfileService>();
      final nostrService = context.read<INostrService>();
      
      // Check if this is the current user's profile
      final currentUserPubkey = nostrService.publicKey;
      _isOwnProfile = currentUserPubkey == widget.userPubkey;
      
      // Try to get cached profile first
      _userProfile = userProfileService.getCachedProfile(widget.userPubkey);
      
      if (_userProfile != null) {
        setState(() {
          _isLoading = false;
        });
      }
      
      // Always try to fetch fresh profile data
      final profile = await userProfileService.fetchProfile(widget.userPubkey);
      
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading user profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            if (!_isOwnProfile) ...[
              const Icon(Icons.person_outline, color: Colors.white, size: 16),
              const SizedBox(width: 4),
            ],
            Text(
              _userProfile?.bestDisplayName ?? widget.initialDisplayName ?? 'User Profile',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          if (!_isOwnProfile)
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onPressed: _showUserOptions,
            ),
        ],
      ),
      body: _isLoading ? _buildLoadingState() : _buildProfileContent(),
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
            'Loading profile...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent() {
    if (_errorMessage != null) {
      return _buildErrorState();
    }

    return Column(
      children: [
        // Profile header
        _buildProfileHeader(),
        
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
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_off,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Profile Not Found',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage?.contains('not found') == true 
                  ? 'This user profile could not be loaded.'
                  : 'Failed to load profile. Check your connection.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadUserProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final profile = _userProfile;
    final displayName = profile?.bestDisplayName ?? widget.initialDisplayName ?? 'Unknown User';
    final avatarUrl = profile?.picture;
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
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
                  backgroundImage: (avatarUrl?.isNotEmpty == true) 
                      ? NetworkImage(avatarUrl!) 
                      : null,
                  child: (avatarUrl?.isEmpty != false)
                      ? const Icon(Icons.person, color: Colors.white, size: 40)
                      : null,
                ),
              ),
              
              const SizedBox(width: 20),
              
              // Stats placeholder - TODO: Get real stats from Nostr events
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn('--', 'Vines'),
                    _buildStatColumn('--', 'Followers'),
                    _buildStatColumn('--', 'Following'),
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
                Text(
                  displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                if (profile?.about?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    profile!.about!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                // Show shortened pubkey for verification
                Text(
                  '@${widget.userPubkey.substring(0, 8)}...${widget.userPubkey.substring(widget.userPubkey.length - 8)}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String number, String label) {
    return Column(
      children: [
        Text(
          number,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    // Additional stats could go here in the future
    return const SizedBox.shrink();
  }

  Widget _buildActionButtons() {
    if (_isOwnProfile) {
      return const SizedBox.shrink(); // Own profile - no action buttons needed
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _toggleFollow,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Follow'), // TODO: Show "Following" if already followed
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _sendMessage,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Message'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Colors.purple,
        tabs: const [
          Tab(text: 'Vines'),
          Tab(text: 'Liked'),
        ],
      ),
    );
  }

  Widget _buildVinesGrid() {
    // TODO: Load and display user's videos
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library_outlined, color: Colors.grey, size: 64),
          SizedBox(height: 16),
          Text(
            'No videos yet',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Videos from this user will appear here',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLikedGrid() {
    // TODO: Load and display liked videos (if public)
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_outline, color: Colors.grey, size: 64),
          SizedBox(height: 16),
          Text(
            'Liked videos',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Liked videos may be private',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _toggleFollow() {
    // TODO: Implement follow/unfollow functionality with NIP-02 contact lists
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Follow functionality for ${_userProfile?.bestDisplayName ?? "user"} - Coming soon'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  void _sendMessage() {
    // TODO: Implement direct messaging functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Messaging with ${_userProfile?.bestDisplayName ?? "user"} - Coming soon'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showUserOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
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
              leading: const Icon(Icons.flag, color: Colors.white),
              title: const Text('Report User', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _reportUser();
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.white),
              title: const Text('Block User', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _blockUser();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _shareProfile() {
    // TODO: Implement profile sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile sharing - Coming soon'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _reportUser() {
    // TODO: Implement user reporting functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User reporting - Coming soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _blockUser() {
    // TODO: Implement user blocking functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User blocking - Coming soon'),
        backgroundColor: Colors.red,
      ),
    );
  }
}