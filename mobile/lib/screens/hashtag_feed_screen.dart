// ABOUTME: Screen displaying videos filtered by a specific hashtag
// ABOUTME: Allows users to explore all videos with a particular hashtag

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/vine_theme.dart';
import '../services/video_event_service.dart';
import '../services/hashtag_service.dart';
import '../widgets/video_feed_item.dart';
import 'explore_video_screen.dart';

class HashtagFeedScreen extends StatefulWidget {
  final String hashtag;
  
  const HashtagFeedScreen({super.key, required this.hashtag});

  @override
  State<HashtagFeedScreen> createState() => _HashtagFeedScreenState();
}

class _HashtagFeedScreenState extends State<HashtagFeedScreen> {
  @override
  void initState() {
    super.initState();
    // Subscribe to videos with this hashtag
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hashtagService = context.read<HashtagService>();
      hashtagService.subscribeToHashtagVideos([widget.hashtag]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        elevation: 0,
        title: Text(
          '#${widget.hashtag}',
          style: const TextStyle(
            color: VineTheme.whiteText,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer2<VideoEventService, HashtagService>(
        builder: (context, videoService, hashtagService, child) {
          final videos = hashtagService.getVideosByHashtags([widget.hashtag]);
          final stats = hashtagService.getHashtagStats(widget.hashtag);
          
          if (videoService.isLoading && videos.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            );
          }
          
          if (videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.tag,
                    size: 64,
                    color: VineTheme.secondaryText,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No videos found for #${widget.hashtag}',
                    style: const TextStyle(
                      color: VineTheme.primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Be the first to post a video with this hashtag!',
                    style: TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }
          
          return Column(
            children: [
              // Hashtag info header
              Container(
                color: VineTheme.cardBackground,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.trending_up,
                          color: VineTheme.vineGreen,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${videos.length} videos',
                          style: const TextStyle(
                            color: VineTheme.primaryText,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (stats != null) ...[
                          const Spacer(),
                          Text(
                            'by ${stats.authorCount} viners',
                            style: const TextStyle(
                              color: VineTheme.secondaryText,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (stats != null && stats.recentVideoCount > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${stats.recentVideoCount} new in last 24 hours',
                        style: const TextStyle(
                          color: VineTheme.secondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(color: VineTheme.secondaryText, height: 1),
              
              // Video list
              Expanded(
                child: ListView.builder(
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    return GestureDetector(
                      onTap: () {
                        // Navigate to inline video player for this hashtag
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => ExploreVideoScreen(
                              startingVideo: video,
                              videoList: videos,
                              contextTitle: "#${widget.hashtag}",
                              startingIndex: index,
                            ),
                          ),
                        );
                      },
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height,
                        width: double.infinity,
                        child: VideoFeedItem(
                          video: video,
                          isActive: false, // Never active in list view
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}