// ABOUTME: Compact video overlay modal that preserves explore page navigation
// ABOUTME: Less intrusive alternative to full-screen VideoOverlayModal for in-page video experience

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video_event.dart';
import '../services/video_manager_interface.dart';
import '../widgets/video_feed_item.dart';

/// Compact modal overlay for viewing videos while preserving parent navigation
/// 
/// This creates a less intrusive video experience that keeps the explore page
/// navigation visible and allows quick dismissal back to the explore content.
class VideoOverlayModalCompact extends StatefulWidget {
  final VideoEvent startingVideo;
  final List<VideoEvent> videoList;
  final String contextTitle;
  final int? startingIndex;

  const VideoOverlayModalCompact({
    super.key,
    required this.startingVideo,
    required this.videoList,
    required this.contextTitle,
    this.startingIndex,
  });

  @override
  State<VideoOverlayModalCompact> createState() => _VideoOverlayModalCompactState();
}

class _VideoOverlayModalCompactState extends State<VideoOverlayModalCompact> 
    with TickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  late AnimationController _slideController;
  late Animation<double> _slideAnimation;
  IVideoManager? _videoManager;

  @override
  void initState() {
    super.initState();
    
    debugPrint('🎬 VideoOverlayModalCompact: Initializing with ${widget.videoList.length} videos');
    
    // Find starting video index
    _currentIndex = widget.startingIndex ?? 
        widget.videoList.indexWhere((video) => video.id == widget.startingVideo.id);
    
    if (_currentIndex == -1) {
      _currentIndex = 0;
    }
    
    _pageController = PageController(initialPage: _currentIndex);
    
    // Setup slide animation for smooth entry
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    
    // Start entry animation
    _slideController.forward();
    
    // Initialize video manager
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVideoManager();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _slideController.dispose();
    _pauseAllVideos();
    super.dispose();
  }

  void _initializeVideoManager() async {
    try {
      _videoManager = Provider.of<IVideoManager>(context, listen: false);
      
      // Register all videos with VideoManager
      for (final video in widget.videoList) {
        await _videoManager!.addVideoEvent(video);
      }
      
      // Preload starting video
      if (_currentIndex < widget.videoList.length) {
        final currentVideo = widget.videoList[_currentIndex];
        _videoManager!.preloadVideo(currentVideo.id);
      }
    } catch (e) {
      debugPrint('❌ VideoOverlayModalCompact: VideoManager initialization failed: $e');
    }
  }

  void _pauseAllVideos() {
    if (_videoManager != null) {
      try {
        _videoManager!.pauseAllVideos();
      } catch (e) {
        debugPrint('Error pausing videos in compact overlay: $e');
      }
    }
  }

  void _onPageChanged(int index) async {
    setState(() {
      _currentIndex = index;
    });
    
    if (_videoManager != null && index < widget.videoList.length) {
      final newVideo = widget.videoList[index];
      await _videoManager!.addVideoEvent(newVideo);
      _videoManager!.preloadVideo(newVideo.id);
    }
  }

  void _dismiss() {
    _slideController.reverse().then((_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final modalHeight = screenHeight * 0.8; // 80% of screen height
    
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Semi-transparent background that shows explore page
            GestureDetector(
              onTap: _dismiss,
              child: Container(
                color: Colors.black.withValues(alpha: 0.6),
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            
            // Compact modal container
            Positioned(
              top: _slideAnimation.value * screenHeight + (screenHeight - modalHeight),
              left: 0,
              right: 0,
              height: modalHeight,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Compact header with dismiss indicator
                      _buildCompactHeader(),
                      
                      // Video content
                      Expanded(
                        child: _buildVideoContent(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompactHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white54,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Header content
          Row(
            children: [
              GestureDetector(
                onTap: _dismiss,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
              
              const SizedBox(width: 12),
              
              const Icon(
                Icons.explore,
                color: Colors.white,
                size: 18,
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
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_currentIndex + 1} of ${widget.videoList.length}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVideoContent() {
    if (widget.videoList.isEmpty) {
      return const Center(
        child: Text(
          'No videos available',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      );
    }

    return GestureDetector(
      onVerticalDragEnd: (details) {
        // Swipe down to dismiss
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          _dismiss();
        }
      },
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        itemCount: widget.videoList.length,
        itemBuilder: (context, index) {
          final video = widget.videoList[index];
          final isActive = index == _currentIndex;

          return ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
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

/// Helper function to show compact video overlay modal
void showCompactVideoOverlay({
  required BuildContext context,
  required VideoEvent startingVideo,
  required List<VideoEvent> videoList,
  required String contextTitle,
  int? startingIndex,
}) {
  debugPrint('🎬 showCompactVideoOverlay: ${videoList.length} videos, context: $contextTitle');
  
  if (videoList.isEmpty) {
    debugPrint('❌ Cannot show compact overlay - video list is empty');
    return;
  }
  
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss video overlay',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return VideoOverlayModalCompact(
        startingVideo: startingVideo,
        videoList: videoList,
        contextTitle: contextTitle,
        startingIndex: startingIndex,
      );
    },
  );
}