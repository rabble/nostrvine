/// Headless video controller pool for efficient short-form video playback
///
/// This package provides a headless video controller pooling system optimized
/// for short-form video feeds (like TikTok/Vine). It manages video controllers
/// efficiently but does NOT provide UI - consumers render their own UI via
/// builder callbacks.
///
/// ## Features
///
/// - Singleton-based controller pool with ChangeNotifier
/// - Fixed pool size based on device memory tier
/// - LRU eviction with priority-based management
/// - Smart preloading (active + next + previous videos)
/// - Memory pressure handling
/// - Background/foreground lifecycle management
/// - Headless widgets with customizable UI via callbacks
///
/// ## Installation
///
/// ```yaml
/// dependencies:
///   pooled_video_player:
///     path: mobile/packages/pooled_video_player
/// ```
///
/// ## Quick Start
///
/// ### 1. Initialize the pool (in main.dart)
///
/// ```dart
/// Future<void> main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   // Determine pool size based on device memory
///   final tier = await DeviceMemoryUtil.getMemoryTier();
///   final poolSize = switch (tier) {
///     MemoryTier.low => 2,
///     MemoryTier.medium => 3,
///     MemoryTier.high => 4,
///   };
///
///   await VideoControllerPoolManager.initialize(poolSize: poolSize);
///
///   runApp(MyApp());
/// }
/// ```
///
/// ### 2. Implement PooledVideo in your models
///
/// ```dart
/// class MyVideo implements PooledVideo {
///   @override
///   String get id => videoId;
///
///   @override
///   String get videoUrl => playableUrl;
///
///   @override
///   String? get thumbnailUrl => thumbnail;
/// }
/// ```
///
/// ### 3. Use PooledVideoPlayer with your own UI
///
/// ```dart
/// PooledVideoPlayer(
///   video: myVideo,
///   autoPlay: true,
///   builder: (context, controller, child) {
///     if (controller == null || !controller.value.isInitialized) {
///       return CircularProgressIndicator(); // Your loading UI
///     }
///     return Stack(
///       children: [
///         VideoPlayer(controller), // from video_player package
///         // Your custom overlay, controls, etc.
///         MyCustomControls(controller: controller),
///       ],
///     );
///   },
/// )
/// ```
///
/// ### 4. Use PooledVideoFeed with custom items
///
/// ```dart
/// PooledVideoFeed(
///   videos: myVideos,
///   initialIndex: 0,
///   onActiveVideoChanged: (video, index) {
///     print('Now playing: ${video.id}');
///   },
///   itemBuilder: (context, video, index, isActive) {
///     return MyCustomVideoItem(
///       video: video,
///       isActive: isActive,
///     );
///   },
/// )
/// ```
///
/// ## Architecture
///
/// - **VideoControllerPoolManager**: Singleton managing the controller pool
/// - **PooledVideoPlayer**: Headless widget for single video playback
/// - **PooledVideoFeed**: Headless PageView-based feed with preloading
/// - **PooledVideo**: Interface your video models should implement
///
/// ## No BLoC Required
///
/// This package uses a singleton pattern with ChangeNotifier instead of BLoC.
/// Consumers can listen to pool state changes directly via the manager.
library;

export 'src/models/pooled_video.dart';
export 'src/services/video_controller_pool_manager.dart';
export 'src/utils/device_memory_util.dart';
export 'src/widgets/pooled_video_feed.dart';
export 'src/widgets/pooled_video_player.dart';
