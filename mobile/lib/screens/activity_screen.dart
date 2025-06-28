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
import '../services/notification_service_enhanced.dart';
import '../models/video_event.dart';
import '../models/notification_model.dart';
import '../models/user_profile.dart' as models;
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
        final notificationService = Provider.of<NotificationServiceEnhanced>(context, listen: false);
        final notifications = notificationService.notifications;
        
        if (notifications.isEmpty) {
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
          itemCount: notifications.length,
          itemBuilder: (context, index) {
            return _NotificationItem(
              notification: notifications[index],
              onTap: () => _handleNotificationTap(notifications[index]),
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

  void _handleNotificationTap(NotificationModel notification) {
    if (notification.targetEventId != null) {
      // Find the video and navigate to it
      final videoEventService = Provider.of<VideoEventService>(context, listen: false);
      final video = videoEventService.getVideoEventById(notification.targetEventId!);
      if (video != null) {
        _openVideo(video, videoEventService);
      }
    } else {
      // Navigate to user profile
      _openUserProfile(notification.actorPubkey);
    }
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


class _NotificationItem extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationItem({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProfileService>(
      builder: (context, userProfileService, child) {
        final profile = userProfileService.getCachedProfile(notification.actorPubkey);
        final userName = profile?.bestDisplayName ?? 'Unknown User';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: profile?.picture != null && profile!.picture!.isNotEmpty
                        ? NetworkImage(profile.picture!)
                        : null,
                    backgroundColor: VineTheme.vineGreen,
                    child: profile?.picture == null || profile!.picture!.isEmpty
                        ? Icon(
                            _getNotificationIcon(),
                            color: VineTheme.whiteText,
                            size: 20,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                userName,
                                style: const TextStyle(
                                  color: VineTheme.whiteText,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (profile?.nip05 != null && profile!.nip05!.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.message,
                          style: const TextStyle(
                            color: VineTheme.secondaryText,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatTimestamp(notification.timestamp),
                          style: const TextStyle(
                            color: VineTheme.secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (notification.targetEventId != null)
                    IconButton(
                      onPressed: onTap,
                      icon: const Icon(
                        Icons.play_arrow,
                        color: VineTheme.vineGreen,
                        size: 24,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getNotificationIcon() {
    switch (notification.type) {
      case NotificationType.like:
        return Icons.favorite;
      case NotificationType.follow:
        return Icons.person_add;
      case NotificationType.repost:
        return Icons.repeat;
      case NotificationType.mention:
        return Icons.alternate_email;
      default:
        return Icons.notifications;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

class _FollowingItem extends StatelessWidget {
  final String pubkey;
  final models.UserProfile? profile;
  final VoidCallback onTap;

  const _FollowingItem({
    required this.pubkey,
    this.profile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundImage: profile?.picture != null && profile!.picture!.isNotEmpty
              ? NetworkImage(profile!.picture!)
              : null,
          backgroundColor: VineTheme.vineGreen,
          child: profile?.picture == null || profile!.picture!.isEmpty
              ? const Icon(Icons.person, color: VineTheme.whiteText)
              : null,
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                profile?.displayName ?? 'Unknown User',
                style: const TextStyle(
                  color: VineTheme.whiteText,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (profile?.nip05 != null && profile!.nip05!.isNotEmpty) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 10,
                ),
              ),
            ],
          ],
        ),
        subtitle: profile?.about != null && profile!.about!.isNotEmpty
            ? Text(
                profile!.about!,
                style: const TextStyle(
                  color: VineTheme.secondaryText,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: VineTheme.secondaryText,
          size: 16,
        ),
      ),
    );
  }
}

class _PersonalVideoItem extends StatelessWidget {
  final VideoEvent video;
  final VoidCallback onTap;

  const _PersonalVideoItem({
    required this.video,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey[900],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
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
                  size: 30,
                ),
              ),
              const SizedBox(width: 12),
              
              // Video details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (video.title?.isNotEmpty == true) ? video.title! : 'Untitled Video',
                      style: const TextStyle(
                        color: VineTheme.whiteText,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(DateTime.fromMillisecondsSinceEpoch(video.createdAt * 1000)),
                      style: const TextStyle(
                        color: VineTheme.secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow indicator
              const Icon(
                Icons.arrow_forward_ios,
                color: VineTheme.secondaryText,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}