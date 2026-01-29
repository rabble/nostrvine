// Re-export MediaKit for advanced usage (initialization is handled
// automatically by PlayerPoolManager.initialize())
export 'package:media_kit/media_kit.dart'
    show Media, MediaKit, Player, PlaylistMode;
export 'package:media_kit_video/media_kit_video.dart'
    show NoVideoControls, Video, VideoController;

// Constants
export 'src/constants/pool_constants.dart';

// Controllers - New Architecture
export 'src/controllers/memory_pressure_handler.dart'
    show MemoryPressureHandler;
export 'src/controllers/player_pool.dart' show PlayerPool, PooledPlayer;
export 'src/controllers/player_pool_manager.dart';
export 'src/controllers/video_feed_controller.dart';

// Models
export 'src/models/player_lease.dart';
export 'src/models/pool_status.dart';
export 'src/models/video_item.dart';
export 'src/models/video_load_error.dart';
export 'src/models/video_player_exceptions.dart';
export 'src/models/video_pool_config.dart';

// Utils
export 'src/utils/device_memory_util.dart';

// Widgets (headless with builder patterns)
export 'src/widgets/pooled_video_feed.dart';
export 'src/widgets/pooled_video_player.dart';
export 'src/widgets/video_pool_provider.dart';
