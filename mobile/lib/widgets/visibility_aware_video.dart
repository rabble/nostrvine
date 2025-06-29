// ABOUTME: Reusable visibility-aware video widget that ensures videos ONLY play when visible
// ABOUTME: Abstract base for all video widgets to inherit proper visibility behavior

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../services/video_visibility_manager.dart';
import '../utils/unified_logger.dart';

/// Mixin for widgets that need visibility-aware video playback
/// 
/// This ensures consistent visibility behavior across all video widgets
mixin VideoVisibilityMixin<T extends StatefulWidget> on State<T> {
  /// Unique key for this video widget
  String get videoId;
  
  /// Whether this widget is currently visible enough to play
  bool _isVisibleEnoughToPlay = false;
  
  /// Get current visibility status
  bool get isVisibleEnoughToPlay => _isVisibleEnoughToPlay;
  
  /// Called when visibility changes - override to handle play/pause
  void onVisibilityChanged(bool shouldPlay);
  
  /// Update visibility for this video
  void updateVisibility(double visibleFraction) {
    final visibilityManager = context.read<VideoVisibilityManager>();
    visibilityManager.updateVideoVisibility(videoId, visibleFraction);
    
    final shouldPlay = visibilityManager.shouldVideoPlay(videoId);
    if (shouldPlay != _isVisibleEnoughToPlay) {
      setState(() {
        _isVisibleEnoughToPlay = shouldPlay;
      });
      onVisibilityChanged(shouldPlay);
    }
  }
  
  @override
  void dispose() {
    // Clean up visibility tracking
    try {
      final visibilityManager = context.read<VideoVisibilityManager>();
      visibilityManager.removeVideo(videoId);
    } catch (e) {
      // Visibility manager might not be available
    }
    super.dispose();
  }
}

/// Base widget for visibility-aware video playback
/// 
/// Wrap any video widget with this to ensure it only plays when visible
class VisibilityAwareVideo extends StatefulWidget {
  final String videoId;
  final Widget child;
  final Function(VisibilityInfo)? onVisibilityChanged;
  
  const VisibilityAwareVideo({
    super.key,
    required this.videoId,
    required this.child,
    this.onVisibilityChanged,
  });
  
  @override
  State<VisibilityAwareVideo> createState() => _VisibilityAwareVideoState();
}

class _VisibilityAwareVideoState extends State<VisibilityAwareVideo> {
  bool _mounted = true;
  
  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key('video-visibility-${widget.videoId}'),
      onVisibilityChanged: (visibilityInfo) {
        // Guard against callbacks after disposal
        if (!_mounted) return;
        
        // Report to centralized manager
        try {
          final visibilityManager = context.read<VideoVisibilityManager>();
          visibilityManager.updateVideoVisibility(
            widget.videoId,
            visibilityInfo.visibleFraction,
          );
          
          Log.verbose(
            '👁️ Visibility: ${(visibilityInfo.visibleFraction * 100).toStringAsFixed(1)}% for ${widget.videoId.substring(0, 8)}',
            name: 'VisibilityAwareVideo',
            category: LogCategory.ui,
          );
        } catch (e) {
          // Context might not be valid anymore
          if (_mounted) {
            Log.error('Error updating visibility: $e', name: 'VisibilityAwareVideo');
          }
        }
        
        // Call custom handler if provided
        if (_mounted) {
          widget.onVisibilityChanged?.call(visibilityInfo);
        }
      },
      child: Consumer<VideoVisibilityManager>(
        builder: (context, visibilityManager, _) {
          final shouldPlay = visibilityManager.shouldVideoPlay(widget.videoId);
          final shouldAutoPlay = visibilityManager.shouldAutoPlay(widget.videoId);
          
          // Provide visibility context to child
          return _VisibilityContext(
            videoId: widget.videoId,
            shouldPlay: shouldPlay,
            shouldAutoPlay: shouldAutoPlay,
            child: widget.child,
          );
        },
      ),
    );
  }
}

/// Internal widget to provide visibility context
class _VisibilityContext extends InheritedWidget {
  final String videoId;
  final bool shouldPlay;
  final bool shouldAutoPlay;
  
  const _VisibilityContext({
    required this.videoId,
    required this.shouldPlay,
    required this.shouldAutoPlay,
    required super.child,
  });
  
  static _VisibilityContext? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_VisibilityContext>();
  }
  
  @override
  bool updateShouldNotify(_VisibilityContext oldWidget) {
    return shouldPlay != oldWidget.shouldPlay || shouldAutoPlay != oldWidget.shouldAutoPlay;
  }
}

/// Extension to easily access visibility context
extension VisibilityContextExtension on BuildContext {
  /// Check if the current video should be playing based on visibility
  bool get shouldVideoPlay {
    final context = _VisibilityContext.of(this);
    return context?.shouldPlay ?? false;
  }
  
  /// Check if the current video should auto-play when visible
  bool get shouldVideoAutoPlay {
    final context = _VisibilityContext.of(this);
    return context?.shouldAutoPlay ?? false;
  }
  
  /// Get the video ID from visibility context
  String? get visibilityVideoId {
    final context = _VisibilityContext.of(this);
    return context?.videoId;
  }
}