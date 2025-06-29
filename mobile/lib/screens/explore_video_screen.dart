// ABOUTME: Inline video player screen that preserves explore context and navigation
// ABOUTME: Displays videos within explore screen layout instead of full-screen modal

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/video_event.dart';
import '../services/video_manager_interface.dart';
import '../widgets/video_feed_item.dart';
import '../theme/vine_theme.dart';
import '../utils/unified_logger.dart';

/// Inline video player screen that maintains explore context
class ExploreVideoScreen extends StatefulWidget {
  final VideoEvent startingVideo;
  final List<VideoEvent> videoList;
  final String contextTitle;
  final int? startingIndex;

  const ExploreVideoScreen({
    super.key,
    required this.startingVideo,
    required this.videoList,
    required this.contextTitle,
    this.startingIndex,
  });

  @override
  State<ExploreVideoScreen> createState() => _ExploreVideoScreenState();
}

class _ExploreVideoScreenState extends State<ExploreVideoScreen> {
  late PageController _pageController;
  late int _currentIndex;
  IVideoManager? _videoManager;

  @override
  void initState() {
    super.initState();
    
    Log.debug('ExploreVideoScreen.initState: Called with ${widget.videoList.length} videos', name: 'ExploreVideoScreen', category: LogCategory.ui);
    
    // Find starting video index or use provided index
    _currentIndex = widget.startingIndex ?? 
        widget.videoList.indexWhere((video) => video.id == widget.startingVideo.id);
    
    if (_currentIndex == -1) {
      _currentIndex = 0;
    }
    
    _pageController = PageController(initialPage: _currentIndex);
    
    // Initialize video manager
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVideoManager();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pauseAllVideos();
    super.dispose();
  }

  void _initializeVideoManager() async {
    try {
      _videoManager = Provider.of<IVideoManager>(context, listen: false);
      
      // PRIORITY 1: Immediately register and preload the current video
      if (_currentIndex < widget.videoList.length) {
        final currentVideo = widget.videoList[_currentIndex];
        Log.debug('ExploreVideoScreen: Priority loading starting video: ${currentVideo.id.substring(0, 8)}...', name: 'ExploreVideoScreen', category: LogCategory.ui);
        
        // Add and preload the current video first
        await _videoManager!.addVideoEvent(currentVideo);
        _videoManager!.preloadVideo(currentVideo.id);
        
        // PRIORITY 2: Add adjacent videos for smooth scrolling
        // Add the next video if available
        if (_currentIndex + 1 < widget.videoList.length) {
          await _videoManager!.addVideoEvent(widget.videoList[_currentIndex + 1]);
        }
        
        // Add the previous video if available
        if (_currentIndex - 1 >= 0) {
          await _videoManager!.addVideoEvent(widget.videoList[_currentIndex - 1]);
        }
      }
      
      // PRIORITY 3: Register remaining videos in background without blocking
      // Use a deferred execution to avoid blocking the UI
      Future.microtask(() async {
        try {
          for (int i = 0; i < widget.videoList.length; i++) {
            // Skip already added videos
            if (i == _currentIndex || i == _currentIndex + 1 || i == _currentIndex - 1) {
              continue;
            }
            
            // Add remaining videos without blocking
            if (!mounted) return; // Check if widget is still mounted
            await _videoManager!.addVideoEvent(widget.videoList[i]);
            
            // Small delay to prevent blocking the UI thread
            if (i % 10 == 0) {
              await Future.delayed(const Duration(milliseconds: 1));
            }
          }
          
          Log.debug('ExploreVideoScreen: Background registration of ${widget.videoList.length} videos completed', name: 'ExploreVideoScreen', category: LogCategory.ui);
        } catch (e) {
          Log.error('ExploreVideoScreen: Error in background video registration: $e', name: 'ExploreVideoScreen', category: LogCategory.ui);
        }
      });
    } catch (e) {
      Log.error('ExploreVideoScreen: VideoManager not found: $e', name: 'ExploreVideoScreen', category: LogCategory.ui);
    }
  }

  void _pauseAllVideos() {
    if (_videoManager != null) {
      try {
        _videoManager!.pauseAllVideos();
      } catch (e) {
        Log.error('Error pausing videos in explore video screen: $e', name: 'ExploreVideoScreen', category: LogCategory.ui);
      }
    }
  }

  void _onPageChanged(int index) async {
    setState(() {
      _currentIndex = index;
    });
    
    // Manage video playback for the new current video
    if (_videoManager != null && index < widget.videoList.length) {
      final newVideo = widget.videoList[index];
      
      Log.debug('ExploreVideoScreen: Page changed to video $index: ${newVideo.id.substring(0, 8)}...', name: 'ExploreVideoScreen', category: LogCategory.ui);
      
      // Ensure video is registered and preload it with priority
      await _videoManager!.addVideoEvent(newVideo);
      _videoManager!.preloadVideo(newVideo.id);
      
      // Preload adjacent videos for smoother scrolling experience
      // Use fire-and-forget pattern to avoid blocking current video
      Future.microtask(() async {
        try {
          // Preload next video if available
          if (index + 1 < widget.videoList.length) {
            final nextVideo = widget.videoList[index + 1];
            await _videoManager!.addVideoEvent(nextVideo);
            _videoManager!.preloadVideo(nextVideo.id);
          }
          
          // Preload next 2 videos for ultra-smooth experience
          if (index + 2 < widget.videoList.length) {
            final nextNextVideo = widget.videoList[index + 2];
            await _videoManager!.addVideoEvent(nextNextVideo);
            // Don't preload controller yet, just register
          }
          
          // Register previous video for backward scrolling
          if (index - 1 >= 0) {
            final prevVideo = widget.videoList[index - 1];
            await _videoManager!.addVideoEvent(prevVideo);
          }
        } catch (e) {
          Log.error('ExploreVideoScreen: Error preloading adjacent videos: $e', name: 'ExploreVideoScreen', category: LogCategory.ui);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            const Icon(
              Icons.explore,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.contextTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_currentIndex + 1} of ${widget.videoList.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        centerTitle: false,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: widget.videoList.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No videos available',
                    style: TextStyle(color: VineTheme.primaryText, fontSize: 18),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Go back to explore more content',
                    style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
                  ),
                ],
              ),
            )
          : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              onPageChanged: _onPageChanged,
              itemCount: widget.videoList.length,
              itemBuilder: (context, index) {
                if (index < 0 || index >= widget.videoList.length) {
                  return const SizedBox.shrink();
                }

                final video = widget.videoList[index];
                final isActive = index == _currentIndex;

                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  color: Colors.black,
                  child: VideoFeedItem(
                    video: video,
                    isActive: isActive,
                  ),
                );
              },
            ),
    );
  }
}