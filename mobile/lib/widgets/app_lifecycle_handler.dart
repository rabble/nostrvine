// ABOUTME: App lifecycle handler that pauses all videos when app goes to background
// ABOUTME: Ensures videos never play when app is not visible

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/video_visibility_manager.dart';
import '../utils/unified_logger.dart';

/// Handles app lifecycle events for video playback
class AppLifecycleHandler extends StatefulWidget {
  final Widget child;
  
  const AppLifecycleHandler({
    super.key,
    required this.child,
  });
  
  @override
  State<AppLifecycleHandler> createState() => _AppLifecycleHandlerState();
}

class _AppLifecycleHandlerState extends State<AppLifecycleHandler> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    final visibilityManager = context.read<VideoVisibilityManager>();
    
    switch (state) {
      case AppLifecycleState.resumed:
        Log.info('📱 App resumed - enabling visibility-based playback', 
            name: 'AppLifecycleHandler', category: LogCategory.system);
        visibilityManager.resumeVisibilityBasedPlayback();
        break;
        
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        Log.info('📱 App backgrounded - pausing all videos', 
            name: 'AppLifecycleHandler', category: LogCategory.system);
        visibilityManager.pauseAllVideos();
        break;
        
      case AppLifecycleState.detached:
        // App is being terminated
        break;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}