import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

// ============================================
// MOCK CLASSES
// ============================================

/// Mock for media_kit Player class.
class MockPlayer extends Mock implements Player {}

/// Mock for media_kit VideoController class.
class MockVideoController extends Mock implements VideoController {}

/// Mock for PlayerPool.
class MockPlayerPool extends Mock implements PlayerPool {}

/// Mock for VideoFeedController.
class MockVideoFeedController extends Mock implements VideoFeedController {}

/// Mock for PooledPlayer.
class MockPooledPlayer extends Mock implements PooledPlayer {}

/// Mock for PlayerState.
class MockPlayerState extends Mock implements PlayerState {}

/// Mock for PlayerStream.
class MockPlayerStream extends Mock implements PlayerStream {}

// ============================================
// FAKE CLASSES (for registerFallbackValue)
// ============================================

/// Fake implementation of Media for fallback registration.
class FakeMedia extends Fake implements Media {}

/// Fake implementation of Duration for fallback registration.
class FakeDuration extends Fake implements Duration {}

/// Fake implementation of VideoItem for fallback registration.
class FakeVideoItem extends Fake implements VideoItem {}

/// Fake implementation of BuildContext for fallback registration.
class FakeBuildContext extends Fake implements BuildContext {}

// ============================================
// SETUP FUNCTION
// ============================================

/// Sets up mocktail fallback values. Call this in setUpAll().
void setUpMocktail() {
  registerFallbackValue(FakeMedia());
  registerFallbackValue(Duration.zero);
  registerFallbackValue(
    const VideoItem(id: 'fake', url: 'https://example.com/fake.mp4'),
  );
  registerFallbackValue(PlaylistMode.single);
}
