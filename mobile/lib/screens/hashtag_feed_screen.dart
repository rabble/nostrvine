// ABOUTME: Screen displaying videos filtered by a specific hashtag
// ABOUTME: Allows users to explore all videos with a particular hashtag

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/vine_theme.dart';
import '../services/video_event_service.dart';
import '../widgets/video_feed_item.dart';

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
      final videoService = context.read<VideoEventService>();
      videoService.subscribeToHashtagVideos([widget.hashtag]);
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
      body: Consumer<VideoEventService>(
        builder: (context, videoService, child) {
          final videos = videoService.getVideoEventsByHashtags([widget.hashtag]);
          
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
                child: Row(
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
                    return VideoFeedItem(
                      video: video,
                      isActive: index == 0, // Only first video is active
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