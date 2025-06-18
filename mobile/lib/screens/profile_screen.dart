import 'package:flutter/material.dart';

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.white, size: 16),
            SizedBox(width: 4),
            Text(
              'nostrviner42',
              style: TextStyle(
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
                _buildPrivateGrid(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Profile picture and follow button row
          Row(
            children: [
              // Profile picture
              Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.purple, Colors.pink, Colors.orange],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, color: Colors.white, size: 40),
                ),
              ),
              
              const SizedBox(width: 20),
              
              // Stats
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn('42', 'Vines'),
                    _buildStatColumn('1.2K', 'Followers'),
                    _buildStatColumn('186', 'Following'),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Name and bio
          const Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nostr Viner 🍇',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Creating short, looping magic on the decentralized web ✨\n🌍 Building the future of social media\n🔗 nostr.viner.social',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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

  Widget _buildStatsRow() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            children: [
              Text(
                '2.1M',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
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
              Text(
                '156K',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                'Total Likes',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Column(
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, color: Colors.grey, size: 64),
          SizedBox(height: 16),
          Text(
            'Liked Vines',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Vines you\'ve liked will appear here',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ],
      ),
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

  void _editProfile() {
    // TODO: Navigate to edit profile screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening edit profile...')),
    );
  }

  void _shareProfile() {
    // TODO: Implement profile sharing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sharing profile...')),
    );
  }

  void _followUser() {
    // TODO: Implement follow functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Following user...')),
    );
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

  void _openSettings() {
    // TODO: Navigate to settings screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening settings...')),
    );
  }
}