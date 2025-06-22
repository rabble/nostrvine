// ABOUTME: Activity screen showing user interactions like likes, follows, and comments
// ABOUTME: Displays notifications feed similar to original Vine's activity tab

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/vine_theme.dart';
import '../services/social_service.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import '../services/video_manager_interface.dart';
import '../services/video_event_service.dart';
import '../models/video_event.dart';
import 'profile_screen.dart';
import 'explore_video_screen.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

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
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        if (!authService.isAuthenticated) {
          return _buildUnauthenticatedState();
        }

        return Scaffold(
          backgroundColor: VineTheme.backgroundColor,
          appBar: AppBar(
            backgroundColor: VineTheme.vineGreen,
            elevation: 0,
            title: const Text(
              'Activity',
              style: TextStyle(
                color: VineTheme.whiteText,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: VineTheme.whiteText,
              indicatorWeight: 2,
              labelColor: VineTheme.whiteText,
              unselectedLabelColor: VineTheme.whiteText.withValues(alpha: 0.7),
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'ALL'),
                Tab(text: 'FOLLOWING'),
                Tab(text: 'YOU'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildAllActivity(),
              _buildFollowingActivity(),
              _buildPersonalActivity(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnauthenticatedState() {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        elevation: 0,
        title: const Text(
          'Activity',
          style: TextStyle(
            color: VineTheme.whiteText,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outlined,
              size: 64,
              color: VineTheme.secondaryText,
            ),
            SizedBox(height: 16),
            Text(
              'Sign in to see activity',
              style: TextStyle(
                color: VineTheme.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Connect your Nostr keys to see\nlikes, follows, and comments.',
              style: TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllActivity() {
    return Consumer3<IVideoManager, VideoEventService, SocialService>(
      builder: (context, videoManager, videoEventService, socialService, child) {
        final activities = _generateMockActivities(videoEventService, socialService);
        
        if (activities.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 64,
                  color: VineTheme.secondaryText,
                ),
                SizedBox(height: 16),
                Text(
                  'No activity yet',
                  style: TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'When people interact with your content\nor you follow others, it will show up here.',
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            return _ActivityItem(
              activity: activities[index],
              onVideoTap: activities[index].targetVideo != null 
                ? () => _openVideo(activities[index].targetVideo!, videoEventService)
                : null,
            );
          },
        );
      },
    );
  }

  Widget _buildFollowingActivity() {
    return Consumer<SocialService>(
      builder: (context, socialService, child) {
        final followingPubkeys = socialService.followingPubkeys;
        
        if (followingPubkeys.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 64,
                  color: VineTheme.secondaryText,
                ),
                SizedBox(height: 16),
                Text(
                  'You\'re not following anyone',
                  style: TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Follow some creators to see\ntheir activity here.',
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

        return Consumer<UserProfileService>(
          builder: (context, userProfileService, child) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: followingPubkeys.length,
              itemBuilder: (context, index) {
                final pubkey = followingPubkeys[index];
                final profile = userProfileService.getCachedProfile(pubkey);
                return _FollowingItem(
                  pubkey: pubkey,
                  profile: profile,
                  onTap: () => _openUserProfile(pubkey),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPersonalActivity() {
    return Consumer3<AuthService, VideoEventService, SocialService>(
      builder: (context, authService, videoEventService, socialService, child) {
        // Get current user's videos
        final userVideos = videoEventService.videoEvents
            .where((video) => video.pubkey == authService.currentPublicKeyHex)
            .toList();

        if (userVideos.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.video_library_outlined,
                  size: 64,
                  color: VineTheme.secondaryText,
                ),
                SizedBox(height: 16),
                Text(
                  'No videos yet',
                  style: TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Create your first vine to start\nreceiving activity notifications.',
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: userVideos.length,
          itemBuilder: (context, index) {
            final video = userVideos[index];
            return _PersonalVideoItem(
              video: video,
              onTap: () => _openVideo(video, videoEventService),
            );
          },
        );
      },
    );
  }

  List<ActivityData> _generateMockActivities(VideoEventService videoEventService, SocialService socialService) {
    final activities = <ActivityData>[];
    
    // Add recent follows
    final following = socialService.followingPubkeys;
    for (int i = 0; i < following.length && i < 3; i++) {
      activities.add(ActivityData(
        type: ActivityType.follow,
        actorPubkey: following[i],
        timestamp: DateTime.now().subtract(Duration(hours: i + 1)),
        message: 'You followed this user',
      ));
    }

    // Add sample likes (mock data since we don't have real notification system yet)
    final recentVideos = videoEventService.videoEvents.take(3).toList();
    for (int i = 0; i < recentVideos.length; i++) {
      activities.add(ActivityData(
        type: ActivityType.like,
        actorPubkey: recentVideos[i].pubkey,
        targetVideo: recentVideos[i],
        timestamp: DateTime.now().subtract(Duration(hours: i * 2 + 2)),
        message: 'liked your video',
      ));
    }

    // Sort by timestamp (most recent first)
    activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return activities;
  }

  void _openUserProfile(String pubkey) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProfileScreen(profilePubkey: pubkey),
      ),
    );
  }

  void _openVideo(VideoEvent video, VideoEventService videoEventService) {
    debugPrint('🎬 Opening video from Activity: ${video.id.substring(0, 8)}...');
    debugPrint('📺 Video URL: ${video.videoUrl}');
    debugPrint('🖼️ Thumbnail URL: ${video.thumbnailUrl}');
    debugPrint('📝 Title: ${video.title}');
    
    // Check if video has a valid URL
    if (video.videoUrl?.isEmpty != false) {
      debugPrint('❌ Cannot open video - empty or null video URL');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Video URL is not available'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final allVideos = videoEventService.videoEvents;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ExploreVideoScreen(
          startingVideo: video,
          videoList: allVideos,
          contextTitle: 'Activity Video',
        ),
      ),
    );
  }
}

enum ActivityType { like, follow, comment, repost }

class ActivityData {
  final ActivityType type;
  final String actorPubkey;
  final VideoEvent? targetVideo;
  final DateTime timestamp;
  final String message;

  ActivityData({
    required this.type,
    required this.actorPubkey,
    this.targetVideo,
    required this.timestamp,
    required this.message,
  });
}

class _ActivityItem extends StatelessWidget {
  final ActivityData activity;
  final VoidCallback? onVideoTap;

  const _ActivityItem({
    required this.activity,
    this.onVideoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProfileService>(
      builder: (context, userProfileService, child) {
        final profile = userProfileService.getCachedProfile(activity.actorPubkey);
        final userName = profile?.displayName ?? 'Anonymous';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Activity icon
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getActivityColor(activity.type),
                    ),
                    child: Icon(
                      _getActivityIcon(activity.type),
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Activity content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(color: VineTheme.primaryText, fontSize: 14),
                            children: [
                              TextSpan(
                                text: userName,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: ' ${activity.message}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTimestamp(activity.timestamp),
                          style: const TextStyle(
                            color: VineTheme.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Video thumbnail if applicable
                  if (activity.targetVideo != null) ...[
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: onVideoTap,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: VineTheme.vineGreen,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getActivityColor(ActivityType type) {
    switch (type) {
      case ActivityType.like:
        return Colors.red;
      case ActivityType.follow:
        return VineTheme.vineGreen;
      case ActivityType.comment:
        return Colors.blue;
      case ActivityType.repost:
        return Colors.orange;
    }
  }

  IconData _getActivityIcon(ActivityType type) {
    switch (type) {
      case ActivityType.like:
        return Icons.favorite;
      case ActivityType.follow:
        return Icons.person_add;
      case ActivityType.comment:
        return Icons.chat_bubble;
      case ActivityType.repost:
        return Icons.repeat;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${difference.inDays ~/ 7}w ago';
    }
  }
}

class _FollowingItem extends StatelessWidget {
  final String pubkey;
  final dynamic profile;
  final VoidCallback onTap;

  const _FollowingItem({
    required this.pubkey,
    required this.profile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Card(
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
          title: Text(
            profile?.displayName ?? 'Anonymous',
            style: const TextStyle(
              color: VineTheme.whiteText,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            '@${pubkey.substring(0, 8)}...',
            style: const TextStyle(
              color: VineTheme.secondaryText,
              fontSize: 12,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: VineTheme.vineGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Following',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _PersonalVideoItem extends StatelessWidget {
  final VideoEvent video;
  final VoidCallback? onTap;

  const _PersonalVideoItem({
    required this.video,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: Colors.grey[900],
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
            children: [
              // Video thumbnail
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
              
              // Video info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (video.title?.isNotEmpty == true) ...[
                      Text(
                        video.title!,
                        style: const TextStyle(
                          color: VineTheme.whiteText,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                    ],
                    Text(
                      video.relativeTime,
                      style: const TextStyle(
                        color: VineTheme.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Consumer<SocialService>(
                      builder: (context, socialService, child) {
                        final likeCount = socialService.getCachedLikeCount(video.id) ?? 0;
                        return Text(
                          '$likeCount likes',
                          style: const TextStyle(
                            color: VineTheme.secondaryText,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}