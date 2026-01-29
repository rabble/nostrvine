import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart' show PlayerState, PlayerStream;
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

class MockDeviceMemoryUtil extends Mock implements DeviceMemoryUtil {}

class MockPlayerPool extends Mock implements PlayerPool {}

class MockPlayer extends Mock implements Player {}

class MockVideoController extends Mock implements VideoController {}

class MockPlayerStream extends Mock implements PlayerStream {}

class MockPlayerState extends Mock implements PlayerState {}

class FakePooledPlayer extends Fake implements PooledPlayer {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakePooledPlayer());
    registerFallbackValue(Media('https://example.com/video.mp4'));
    registerFallbackValue(PlaylistMode.single);
  });

  group('VideoPoolProvider', () {
    late MockDeviceMemoryUtil mockMemoryClassifier;
    late List<VideoItem> testVideos;

    // Factory that returns a mock PlayerPool to avoid MediaKit initialization
    PlayerPool mockPlayerPoolFactory(VideoPoolConfig config) {
      final mockPool = MockPlayerPool();
      final mockPlayer = MockPlayer();
      final mockVideoController = MockVideoController();
      final mockPooledPlayer = PooledPlayer(
        player: mockPlayer,
        videoController: mockVideoController,
      );

      // Stub MockPlayer methods that are called during preloading
      when(
        () => mockPlayer.open(any(), play: any(named: 'play')),
      ).thenAnswer((_) async {});
      when(() => mockPlayer.setPlaylistMode(any())).thenAnswer((_) async {});
      when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});
      when(mockPlayer.play).thenAnswer((_) async {});
      when(mockPlayer.pause).thenAnswer((_) async {});
      when(mockPlayer.stop).thenAnswer((_) async {});

      // Stub stream and state properties accessed during preloading
      final mockStream = MockPlayerStream();
      final mockState = MockPlayerState();
      when(() => mockStream.buffering).thenAnswer((_) => Stream.value(false));
      when(() => mockState.buffering).thenReturn(false);
      when(() => mockPlayer.stream).thenReturn(mockStream);
      when(() => mockPlayer.state).thenReturn(mockState);

      when(() => mockPool.prewarm(any())).thenAnswer((_) async {});
      when(mockPool.dispose).thenAnswer((_) async {});
      when(() => mockPool.shrinkTo(any())).thenAnswer((_) async {});
      when(mockPool.acquire).thenAnswer((_) async => mockPooledPlayer);
      when(() => mockPool.release(any())).thenAnswer((_) async {});
      when(() => mockPool.maxPoolSize).thenReturn(3);
      when(() => mockPool.availableCount).thenReturn(0);
      when(() => mockPool.inUseCount).thenReturn(0);
      return mockPool;
    }

    setUp(() {
      mockMemoryClassifier = MockDeviceMemoryUtil();
      testVideos = [
        const VideoItem(id: '1', url: 'https://example.com/video1.mp4'),
        const VideoItem(id: '2', url: 'https://example.com/video2.mp4'),
      ];
    });

    tearDown(() async {
      // Always reset the singleton after each test
      if (PlayerPoolManager.isInitialized) {
        await PlayerPoolManager.reset();
      }
    });

    group('feedOf', () {
      testWidgets('returns feed controller from provider when available', (
        tester,
      ) async {
        when(
          () => mockMemoryClassifier.getMemoryTier(),
        ).thenAnswer((_) async => MemoryTier.medium);

        await PlayerPoolManager.initialize(
          memoryClassifier: mockMemoryClassifier,
          playerPoolFactory: mockPlayerPoolFactory,
          skipMediaKitInit: true,
        );

        final feedController = VideoFeedController(
          feedId: 'test-feed',
          videos: testVideos,
        );
        addTearDown(feedController.dispose);

        late VideoFeedController retrievedController;

        await tester.pumpWidget(
          VideoPoolProvider(
            feedController: feedController,
            child: Builder(
              builder: (context) {
                retrievedController = VideoPoolProvider.feedOf(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(retrievedController, same(feedController));
      });

      testWidgets('throws StateError when no provider with feed controller', (
        tester,
      ) async {
        when(
          () => mockMemoryClassifier.getMemoryTier(),
        ).thenAnswer((_) async => MemoryTier.medium);

        await PlayerPoolManager.initialize(
          memoryClassifier: mockMemoryClassifier,
          playerPoolFactory: mockPlayerPoolFactory,
          skipMediaKitInit: true,
        );

        await tester.pumpWidget(
          VideoPoolProvider(
            child: Builder(
              builder: (context) {
                expect(
                  () => VideoPoolProvider.feedOf(context),
                  throwsA(isA<StateError>()),
                );
                return const SizedBox();
              },
            ),
          ),
        );
      });

      testWidgets('throws StateError when no provider in tree', (
        tester,
      ) async {
        await tester.pumpWidget(
          Builder(
            builder: (context) {
              expect(
                () => VideoPoolProvider.feedOf(context),
                throwsA(isA<StateError>()),
              );
              return const SizedBox();
            },
          ),
        );
      });
    });

    group('maybeFeedOf', () {
      testWidgets('returns feed controller from provider when available', (
        tester,
      ) async {
        when(
          () => mockMemoryClassifier.getMemoryTier(),
        ).thenAnswer((_) async => MemoryTier.medium);

        await PlayerPoolManager.initialize(
          memoryClassifier: mockMemoryClassifier,
          playerPoolFactory: mockPlayerPoolFactory,
          skipMediaKitInit: true,
        );

        final feedController = VideoFeedController(
          feedId: 'test-feed',
          videos: testVideos,
        );
        addTearDown(feedController.dispose);

        VideoFeedController? retrievedController;

        await tester.pumpWidget(
          VideoPoolProvider(
            feedController: feedController,
            child: Builder(
              builder: (context) {
                retrievedController = VideoPoolProvider.maybeFeedOf(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(retrievedController, same(feedController));
      });

      testWidgets('returns null when provider has no feed controller', (
        tester,
      ) async {
        when(
          () => mockMemoryClassifier.getMemoryTier(),
        ).thenAnswer((_) async => MemoryTier.medium);

        await PlayerPoolManager.initialize(
          memoryClassifier: mockMemoryClassifier,
          playerPoolFactory: mockPlayerPoolFactory,
          skipMediaKitInit: true,
        );

        VideoFeedController? retrievedController;

        await tester.pumpWidget(
          VideoPoolProvider(
            child: Builder(
              builder: (context) {
                retrievedController = VideoPoolProvider.maybeFeedOf(context);
                return const SizedBox();
              },
            ),
          ),
        );

        expect(retrievedController, isNull);
      });

      testWidgets('returns null when no provider in tree', (tester) async {
        VideoFeedController? retrievedController;

        await tester.pumpWidget(
          Builder(
            builder: (context) {
              retrievedController = VideoPoolProvider.maybeFeedOf(context);
              return const SizedBox();
            },
          ),
        );

        expect(retrievedController, isNull);
      });
    });

    group('poolManager', () {
      testWidgets('returns PlayerPoolManager singleton', (tester) async {
        when(
          () => mockMemoryClassifier.getMemoryTier(),
        ).thenAnswer((_) async => MemoryTier.medium);

        await PlayerPoolManager.initialize(
          memoryClassifier: mockMemoryClassifier,
          playerPoolFactory: mockPlayerPoolFactory,
          skipMediaKitInit: true,
        );

        expect(VideoPoolProvider.poolManager, same(PlayerPoolManager.instance));
      });

      testWidgets('maybePoolManager returns null when not initialized', (
        tester,
      ) async {
        expect(VideoPoolProvider.maybePoolManager(), isNull);
      });

      testWidgets('maybePoolManager returns manager when initialized', (
        tester,
      ) async {
        when(
          () => mockMemoryClassifier.getMemoryTier(),
        ).thenAnswer((_) async => MemoryTier.medium);

        await PlayerPoolManager.initialize(
          memoryClassifier: mockMemoryClassifier,
          playerPoolFactory: mockPlayerPoolFactory,
          skipMediaKitInit: true,
        );

        expect(
          VideoPoolProvider.maybePoolManager(),
          same(PlayerPoolManager.instance),
        );
      });
    });

    group('updateShouldNotify', () {
      testWidgets('notifies when feed controller changes', (tester) async {
        when(
          () => mockMemoryClassifier.getMemoryTier(),
        ).thenAnswer((_) async => MemoryTier.medium);

        await PlayerPoolManager.initialize(
          memoryClassifier: mockMemoryClassifier,
          playerPoolFactory: mockPlayerPoolFactory,
          skipMediaKitInit: true,
        );

        final controller1 = VideoFeedController(
          feedId: 'test-feed-1',
          videos: testVideos,
        );
        addTearDown(controller1.dispose);

        final controller2 = VideoFeedController(
          feedId: 'test-feed-2',
          videos: testVideos,
        );
        addTearDown(controller2.dispose);

        final oldWidget = VideoPoolProvider(
          feedController: controller1,
          child: const SizedBox(),
        );

        final newWidget = VideoPoolProvider(
          feedController: controller2,
          child: const SizedBox(),
        );

        expect(newWidget.updateShouldNotify(oldWidget), isTrue);
      });

      testWidgets('does not notify when feed controller is same', (
        tester,
      ) async {
        when(
          () => mockMemoryClassifier.getMemoryTier(),
        ).thenAnswer((_) async => MemoryTier.medium);

        await PlayerPoolManager.initialize(
          memoryClassifier: mockMemoryClassifier,
          playerPoolFactory: mockPlayerPoolFactory,
          skipMediaKitInit: true,
        );

        final feedController = VideoFeedController(
          feedId: 'test-feed',
          videos: testVideos,
        );
        addTearDown(feedController.dispose);

        final oldWidget = VideoPoolProvider(
          feedController: feedController,
          child: const SizedBox(),
        );

        final newWidget = VideoPoolProvider(
          feedController: feedController,
          child: const SizedBox(),
        );

        expect(newWidget.updateShouldNotify(oldWidget), isFalse);
      });
    });
  });
}
