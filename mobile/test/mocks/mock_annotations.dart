// ABOUTME: Mock annotations for generating test mocks with mockito
// ABOUTME: Generates mocks for core services and classes used in TDD video system rebuild

import 'package:mockito/annotations.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/foundation.dart';
import '../../lib/services/nostr_service_interface.dart';
import '../../lib/services/connection_status_service.dart';
import '../../lib/services/seen_videos_service.dart';
import '../../lib/services/user_profile_service.dart';
import '../../lib/providers/video_feed_provider.dart';

/// Generate mocks for all core services used in the video system
/// 
/// Run `flutter packages pub run build_runner build` to generate mock classes
@GenerateMocks([
  // Core Flutter classes
  VideoPlayerController,
  ChangeNotifier,
  
  // Nostr services
  INostrService,
  
  // App services
  ConnectionStatusService,
  SeenVideosService,
  UserProfileService,
  VideoFeedProvider,
])
void main() {}