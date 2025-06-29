// ABOUTME: Debug screen to test video playback issues
// ABOUTME: Simple test of VideoFeedItem without feed updates

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/video_event.dart';
import '../widgets/video_feed_item.dart';
import '../services/video_manager_interface.dart';
import '../services/default_content_service.dart';
import '../theme/vine_theme.dart';
import '../utils/unified_logger.dart';

class DebugVideoTestScreen extends StatefulWidget {
  const DebugVideoTestScreen({super.key});

  @override
  State<DebugVideoTestScreen> createState() => _DebugVideoTestScreenState();
}

class _DebugVideoTestScreenState extends State<DebugVideoTestScreen> {
  late VideoEvent _testVideo;
  bool _isPlaying = false;
  
  @override
  void initState() {
    super.initState();
    _testVideo = DefaultContentService.createDefaultVideo();
    
    // Add video to manager
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final videoManager = context.read<IVideoManager>();
        await videoManager.addVideoEvent(_testVideo);
        Log.info('Added test video to manager', name: 'DebugVideoTest', category: LogCategory.ui);
      } catch (e) {
        Log.error('Failed to add test video: $e', name: 'DebugVideoTest', category: LogCategory.ui);
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        title: const Text('Debug Video Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Video URL: ${_testVideo.videoUrl}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            
            // Fixed size container for video
            Container(
              width: 300,
              height: 400,
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: VineTheme.vineGreen, width: 2),
              ),
              child: _isPlaying
                  ? VideoFeedItem(
                      video: _testVideo,
                      isActive: true,
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.play_circle_outline,
                            size: 64,
                            color: Colors.white54,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tap Play to test video',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ),
            ),
            
            const SizedBox(height: 20),
            
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isPlaying = !_isPlaying;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: Colors.white,
              ),
              child: Text(_isPlaying ? 'Stop' : 'Play'),
            ),
          ],
        ),
      ),
    );
  }
}