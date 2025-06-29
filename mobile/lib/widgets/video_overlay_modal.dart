// ABOUTME: Modal overlay for viewing videos while preserving parent screen context
// ABOUTME: Allows video playback without losing navigation or header context

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/video_event.dart';
import '../services/video_manager_interface.dart';
import '../widgets/video_feed_item.dart';
import '../utils/unified_logger.dart';

/// Modal overlay for viewing videos while preserving the parent screen context
class VideoOverlayModal extends StatefulWidget {
  final VideoEvent startingVideo;
  final List<VideoEvent> videoList;
  final String contextTitle;
  final int? startingIndex;

  const VideoOverlayModal({
    super.key,
    required this.startingVideo,
    required this.videoList,
    required this.contextTitle,
    this.startingIndex,
  });

  @override
  State<VideoOverlayModal> createState() => _VideoOverlayModalState();
}

class _VideoOverlayModalState extends State<VideoOverlayModal> {
  late PageController _pageController;
  late int _currentIndex;
  IVideoManager? _videoManager;

  @override
  void initState() {
    super.initState();
    
    Log.debug('VideoOverlayModal.initState: Called with ${widget.videoList.length} videos', name: 'VideoOverlayModal', category: LogCategory.ui);
    Log.debug('VideoOverlayModal.initState: Starting video: ${widget.startingVideo.id.substring(0, 8)}...', name: 'VideoOverlayModal', category: LogCategory.ui);
    Log.debug('VideoOverlayModal.initState: Provided starting index: ${widget.startingIndex}', name: 'VideoOverlayModal', category: LogCategory.ui);
    
    // Find starting video index or use provided index
    _currentIndex = widget.startingIndex ?? 
        widget.videoList.indexWhere((video) => video.id == widget.startingVideo.id);
    
    Log.info('VideoOverlayModal.initState: Found index: $_currentIndex', name: 'VideoOverlayModal', category: LogCategory.ui);
    
    if (_currentIndex == -1) {
      Log.info('VideoOverlayModal.initState: Index not found, defaulting to 0', name: 'VideoOverlayModal', category: LogCategory.ui);
      _currentIndex = 0;
    }
    
    Log.debug('VideoOverlayModal.initState: Final current index: $_currentIndex', name: 'VideoOverlayModal', category: LogCategory.ui);
    
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
    Log.debug('VideoOverlayModal._initializeVideoManager: Starting initialization', name: 'VideoOverlayModal', category: LogCategory.ui);
    try {
      _videoManager = Provider.of<IVideoManager>(context, listen: false);
      Log.debug('VideoOverlayModal._initializeVideoManager: VideoManager obtained', name: 'VideoOverlayModal', category: LogCategory.ui);
      
      // Register all videos in the list with VideoManager
      Log.debug('VideoOverlayModal._initializeVideoManager: Registering ${widget.videoList.length} videos', name: 'VideoOverlayModal', category: LogCategory.ui);
      for (int i = 0; i < widget.videoList.length; i++) {
        final video = widget.videoList[i];
        Log.debug('VideoOverlayModal._initializeVideoManager: Registering video [$i]: ${video.id.substring(0, 8)}...', name: 'VideoOverlayModal', category: LogCategory.ui);
        await _videoManager!.addVideoEvent(video);
      }
      
      // Ensure the starting video is preloaded and ready
      if (_currentIndex < widget.videoList.length) {
        final currentVideo = widget.videoList[_currentIndex];
        Log.debug('VideoOverlayModal._initializeVideoManager: Preloading starting video at index $_currentIndex: ${currentVideo.id.substring(0, 8)}...', name: 'VideoOverlayModal', category: LogCategory.ui);
        _videoManager!.preloadVideo(currentVideo.id);
      } else {
        Log.error('VideoOverlayModal._initializeVideoManager: Current index $_currentIndex is out of bounds for ${widget.videoList.length} videos', name: 'VideoOverlayModal', category: LogCategory.ui);
      }
    } catch (e) {
      Log.error('VideoOverlayModal._initializeVideoManager: VideoManager not found: $e', name: 'VideoOverlayModal', category: LogCategory.ui);
    }
  }

  void _pauseAllVideos() {
    if (_videoManager != null) {
      try {
        _videoManager!.pauseAllVideos();
      } catch (e) {
        Log.error('Error pausing videos in overlay: $e', name: 'VideoOverlayModal', category: LogCategory.ui);
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
      
      Log.debug('VideoOverlayModal: Page changed to video $index: ${newVideo.id.substring(0, 8)}...', name: 'VideoOverlayModal', category: LogCategory.ui);
      
      // Ensure video is registered and preload it
      await _videoManager!.addVideoEvent(newVideo);
      _videoManager!.preloadVideo(newVideo.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    Log.debug('VideoOverlayModal: Building with ${widget.videoList.length} videos, current index: $_currentIndex', name: 'VideoOverlayModal', category: LogCategory.ui);
    Log.debug('VideoOverlayModal: Starting video ID: ${widget.startingVideo.id.substring(0, 8)}...', name: 'VideoOverlayModal', category: LogCategory.ui);
    Log.debug('VideoOverlayModal: Starting index from widget: ${widget.startingIndex}', name: 'VideoOverlayModal', category: LogCategory.ui);
    
    if (widget.videoList.isNotEmpty && _currentIndex < widget.videoList.length) {
      final currentVideo = widget.videoList[_currentIndex];
      Log.debug('VideoOverlayModal: Current video at index $_currentIndex: ${currentVideo.id.substring(0, 8)}... - ${currentVideo.title ?? "No title"}', name: 'VideoOverlayModal', category: LogCategory.ui);
    }
    
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
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No videos available',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Debug: List has ${widget.videoList.length} videos',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
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

                Log.debug('VideoOverlayModal: Building video at index $index (active: $isActive): ${video.id.substring(0, 8)}...', name: 'VideoOverlayModal', category: LogCategory.ui);

                return SizedBox(
                  width: double.infinity,
                  height: double.infinity,
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

/// Helper function to show video overlay modal
void showVideoOverlay({
  required BuildContext context,
  required VideoEvent startingVideo,
  required List<VideoEvent> videoList,
  required String contextTitle,
  int? startingIndex,
}) {
  Log.debug('showVideoOverlay: Called with:', name: 'VideoOverlayModal', category: LogCategory.ui);
  Log.debug('  - Context: $context', name: 'VideoOverlayModal', category: LogCategory.ui);
  Log.debug('  - Starting video: ${startingVideo.id.substring(0, 8)}... - ${startingVideo.title ?? "No title"}', name: 'VideoOverlayModal', category: LogCategory.ui);
  Log.debug('  - Video list: ${videoList.length} videos', name: 'VideoOverlayModal', category: LogCategory.ui);
  Log.debug('  - Context title: $contextTitle', name: 'VideoOverlayModal', category: LogCategory.ui);
  Log.debug('  - Starting index: $startingIndex', name: 'VideoOverlayModal', category: LogCategory.ui);
  
  if (videoList.isEmpty) {
    Log.error('showVideoOverlay: Cannot show overlay - video list is EMPTY', name: 'VideoOverlayModal', category: LogCategory.ui);
    return;
  }
  
  Log.debug('showVideoOverlay: Creating VideoOverlayModal and pushing route', name: 'VideoOverlayModal', category: LogCategory.ui);
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => VideoOverlayModal(
        startingVideo: startingVideo,
        videoList: videoList,
        contextTitle: contextTitle,
        startingIndex: startingIndex,
      ),
      fullscreenDialog: true,
    ),
  );
}