import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';
import 'package:video_player/video_player.dart';

class MockVideoPlayerController extends Mock implements VideoPlayerController {}

class MockVideoPlayerValue extends Mock implements VideoPlayerValue {}

class MockDeviceMemoryUtil extends Mock implements DeviceMemoryUtil {}

void main() {
  late int controllerCreationCount;
  late Map<String, MockVideoPlayerController> mockControllers;

  Future<VideoPlayerController?> createMockController(
    String videoUrl, {
    File? cachedFile,
  }) async {
    controllerCreationCount++;
    final controller = MockVideoPlayerController();
    final value = MockVideoPlayerValue();

    when(() => value.isInitialized).thenReturn(true);
    when(() => value.isPlaying).thenReturn(false);
    when(() => controller.value).thenReturn(value);
    when(controller.dispose).thenAnswer((_) async {});
    when(controller.pause).thenAnswer((_) async {});
    when(controller.play).thenAnswer((_) async {});
    when(() => controller.setLooping(any())).thenAnswer((_) async {});

    mockControllers[videoUrl] = controller;
    return controller;
  }

  setUp(() {
    controllerCreationCount = 0;
    mockControllers = {};
  });

  tearDown(() async {
    await VideoControllerPoolManager.reset();
  });

  group('VideoControllerPoolManager', () {
    group('initialization', () {
      test('throws StateError when accessed before initialization', () {
        expect(
          () => VideoControllerPoolManager.instance,
          throwsStateError,
        );
      });

      test('isInitialized returns false before initialization', () {
        expect(VideoControllerPoolManager.isInitialized, isFalse);
      });

      test('initializes successfully with given pool size', () async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );

        expect(VideoControllerPoolManager.isInitialized, isTrue);
        expect(VideoControllerPoolManager.instance.poolSize, 3);
      });

      test('disposes and recreates on re-initialization', () async {
        await VideoControllerPoolManager.initialize(
          poolSize: 2,
          controllerFactory: createMockController,
        );

        final firstInstance = VideoControllerPoolManager.instance;

        await VideoControllerPoolManager.initialize(
          poolSize: 4,
          controllerFactory: createMockController,
        );

        final secondInstance = VideoControllerPoolManager.instance;
        expect(secondInstance.poolSize, 4);
        expect(firstInstance, isNot(same(secondInstance)));
      });

      group('dependency injection', () {
        test('uses injected memory classifier for auto-detection', () async {
          final mockClassifier = MockDeviceMemoryUtil();
          when(
            mockClassifier.getMemoryTier,
          ).thenAnswer((_) async => MemoryTier.high);

          await VideoControllerPoolManager.initialize(
            controllerFactory: createMockController,
            memoryClassifier: mockClassifier,
          );

          expect(
            VideoControllerPoolManager.instance.poolSize,
            MemoryTierConfig.highMemoryPoolSize,
          );
          verify(mockClassifier.getMemoryTier).called(1);
        });

        test('auto-detects high memory tier', () async {
          final mockClassifier = MockDeviceMemoryUtil();
          when(
            mockClassifier.getMemoryTier,
          ).thenAnswer((_) async => MemoryTier.high);

          await VideoControllerPoolManager.initialize(
            controllerFactory: createMockController,
            memoryClassifier: mockClassifier,
          );

          expect(
            VideoControllerPoolManager.instance.poolSize,
            MemoryTierConfig.highMemoryPoolSize,
          );
        });

        test('auto-detects medium memory tier', () async {
          final mockClassifier = MockDeviceMemoryUtil();
          when(
            mockClassifier.getMemoryTier,
          ).thenAnswer((_) async => MemoryTier.medium);

          await VideoControllerPoolManager.initialize(
            controllerFactory: createMockController,
            memoryClassifier: mockClassifier,
          );

          expect(
            VideoControllerPoolManager.instance.poolSize,
            MemoryTierConfig.mediumMemoryPoolSize,
          );
        });

        test('auto-detects low memory tier', () async {
          final mockClassifier = MockDeviceMemoryUtil();
          when(
            mockClassifier.getMemoryTier,
          ).thenAnswer((_) async => MemoryTier.low);

          await VideoControllerPoolManager.initialize(
            controllerFactory: createMockController,
            memoryClassifier: mockClassifier,
          );

          expect(
            VideoControllerPoolManager.instance.poolSize,
            MemoryTierConfig.lowMemoryPoolSize,
          );
        });

        test('explicit poolSize overrides auto-detection', () async {
          final mockClassifier = MockDeviceMemoryUtil();
          // Classifier would suggest high tier (pool size 4)
          when(
            mockClassifier.getMemoryTier,
          ).thenAnswer((_) async => MemoryTier.high);

          await VideoControllerPoolManager.initialize(
            poolSize: 2, // But we explicitly set pool size to 2
            controllerFactory: createMockController,
            memoryClassifier: mockClassifier,
          );

          expect(VideoControllerPoolManager.instance.poolSize, 2);
          // Classifier should not be called when poolSize is explicit
          verifyNever(mockClassifier.getMemoryTier);
        });

        test('uses default classifier when none provided', () async {
          // This should use DeviceMemoryUtilImpl internally
          // We can't test the exact value since it depends on the test device
          await VideoControllerPoolManager.initialize(
            controllerFactory: createMockController,
          );

          expect(VideoControllerPoolManager.isInitialized, isTrue);
          // Pool size should be one of the valid tier sizes
          final poolSize = VideoControllerPoolManager.instance.poolSize;
          expect(
            [
              MemoryTierConfig.lowMemoryPoolSize,
              MemoryTierConfig.mediumMemoryPoolSize,
              MemoryTierConfig.highMemoryPoolSize,
            ],
            contains(poolSize),
          );
        });
      });
    });

    group('controller acquisition', () {
      setUp(() async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );
      });

      test('acquires new controller when pool is empty', () async {
        final pooled = await VideoControllerPoolManager.instance
            .acquireController(
              videoId: 'video1',
              videoUrl: 'https://example.com/video1.mp4',
            );

        expect(pooled, isNotNull);
        expect(pooled!.videoId, 'video1');
        expect(controllerCreationCount, 1);
      });

      test('reuses existing controller from pool', () async {
        final manager = VideoControllerPoolManager.instance;

        await manager.acquireController(
          videoId: 'video1',
          videoUrl: 'https://example.com/video1.mp4',
        );

        final second = await manager.acquireController(
          videoId: 'video1',
          videoUrl: 'https://example.com/video1.mp4',
        );

        expect(second, isNotNull);
        expect(controllerCreationCount, 1);
      });

      test('getController returns existing controller synchronously', () async {
        final manager = VideoControllerPoolManager.instance;

        await manager.acquireController(
          videoId: 'video1',
          videoUrl: 'https://example.com/video1.mp4',
        );

        final controller = manager.getController('video1');
        expect(controller, isNotNull);

        final nonExistent = manager.getController('video99');
        expect(nonExistent, isNull);
      });

      test('assignedControllers returns unmodifiable map', () async {
        final manager = VideoControllerPoolManager.instance;

        await manager.acquireController(
          videoId: 'video1',
          videoUrl: 'https://example.com/video1.mp4',
        );

        final assigned = manager.assignedControllers;
        expect(assigned.length, 1);
        expect(assigned.containsKey('video1'), isTrue);
      });
    });

    group('pool management', () {
      setUp(() async {
        await VideoControllerPoolManager.initialize(
          poolSize: 2,
          controllerFactory: createMockController,
        );
      });

      test('returns null when eviction fails after max attempts', () async {
        // Use pool of size 1 to make it easier to test
        await VideoControllerPoolManager.reset();
        await VideoControllerPoolManager.initialize(
          poolSize: 1,
          controllerFactory: createMockController,
        );

        final manager = VideoControllerPoolManager.instance;

        // Fill the pool with an active video (cannot be evicted)
        await manager.acquireController(
          videoId: 'video1',
          videoUrl: 'https://example.com/video1.mp4',
        );
        manager.setActiveVideo('video1', index: 0);

        // Pool is full (1 slot) with active video that cannot be evicted
        final result = await manager.acquireController(
          videoId: 'video2',
          videoUrl: 'https://example.com/video2.mp4',
        );

        // Should return null because eviction fails (active video protected)
        expect(result, isNull);
      });

      test('evicts LRU controller when pool is full', () async {
        final manager = VideoControllerPoolManager.instance;

        await manager.acquireController(
          videoId: 'video1',
          videoUrl: 'https://example.com/video1.mp4',
        );
        await manager.acquireController(
          videoId: 'video2',
          videoUrl: 'https://example.com/video2.mp4',
        );

        expect(manager.assignedControllers.length, 2);

        await manager.acquireController(
          videoId: 'video3',
          videoUrl: 'https://example.com/video3.mp4',
        );

        expect(manager.assignedControllers.length, 2);
        expect(manager.assignedControllers.containsKey('video1'), isFalse);
        expect(manager.assignedControllers.containsKey('video2'), isTrue);
        expect(manager.assignedControllers.containsKey('video3'), isTrue);
      });

      test('does not evict active video', () async {
        final manager = VideoControllerPoolManager.instance;

        await manager.acquireController(
          videoId: 'video1',
          videoUrl: 'https://example.com/video1.mp4',
        );
        manager.setActiveVideo('video1', index: 0);

        await manager.acquireController(
          videoId: 'video2',
          videoUrl: 'https://example.com/video2.mp4',
        );

        await manager.acquireController(
          videoId: 'video3',
          videoUrl: 'https://example.com/video3.mp4',
        );

        expect(manager.assignedControllers.containsKey('video1'), isTrue);
        expect(manager.assignedControllers.containsKey('video2'), isFalse);
        expect(manager.assignedControllers.containsKey('video3'), isTrue);
      });

      test(
        'protects prewarm videos but evicts them if no alternatives',
        () async {
          final manager = VideoControllerPoolManager.instance;

          await manager.acquireController(
            videoId: 'video1',
            videoUrl: 'https://example.com/video1.mp4',
          );
          manager.registerVideoIndex('video1', 0);

          await manager.acquireController(
            videoId: 'video2',
            videoUrl: 'https://example.com/video2.mp4',
          );
          manager
            ..registerVideoIndex('video2', 1)
            ..setActiveVideo('video1', index: 0)
            ..setPrewarmVideos(['video2'], currentIndex: 0);

          final result = await manager.acquireController(
            videoId: 'video3',
            videoUrl: 'https://example.com/video3.mp4',
          );

          expect(result, isNotNull);
          expect(manager.assignedControllers.containsKey('video1'), isTrue);
          expect(manager.assignedControllers.containsKey('video2'), isFalse);
          expect(manager.assignedControllers.containsKey('video3'), isTrue);
        },
      );
    });

    group('distance-aware eviction', () {
      setUp(() async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );
      });

      test('evicts video furthest from current scroll position', () async {
        final manager = VideoControllerPoolManager.instance;

        // Add 3 videos to fill the pool (size 3)
        await manager.acquireController(
          videoId: 'video0',
          videoUrl: 'https://example.com/video0.mp4',
        );
        manager.registerVideoIndex('video0', 0);

        await manager.acquireController(
          videoId: 'video5',
          videoUrl: 'https://example.com/video5.mp4',
        );
        manager.registerVideoIndex('video5', 5);

        await manager.acquireController(
          videoId: 'video2',
          videoUrl: 'https://example.com/video2.mp4',
        );
        manager
          ..registerVideoIndex('video2', 2)
          // Set active video at index 2
          ..setActiveVideo('video2', index: 2);

        // Add video3 - should evict video5 (distance 3) not video0 (distance 2)
        await manager.acquireController(
          videoId: 'video3',
          videoUrl: 'https://example.com/video3.mp4',
        );
        manager.registerVideoIndex('video3', 3);

        // video5 at index 5 is furthest from current position 2 (distance 3)
        expect(manager.assignedControllers.containsKey('video5'), isFalse);
        // video0 at index 0 is closer (distance 2) so it should remain
        expect(manager.assignedControllers.containsKey('video0'), isTrue);
        // video2 is active, protected
        expect(manager.assignedControllers.containsKey('video2'), isTrue);
        // video3 was just added
        expect(manager.assignedControllers.containsKey('video3'), isTrue);
      });
    });

    group('listener notifications', () {
      setUp(() async {
        await VideoControllerPoolManager.initialize(
          poolSize: 2,
          controllerFactory: createMockController,
        );
      });

      test('notifies listeners on pool changes', () async {
        final manager = VideoControllerPoolManager.instance;
        var notificationCount = 0;

        final unsubscribe = manager.addPoolChangeListener(() {
          notificationCount++;
        });

        await manager.acquireController(
          videoId: 'video1',
          videoUrl: 'https://example.com/video1.mp4',
        );
        expect(notificationCount, 1);

        manager.setActiveVideo('video1', index: 0);
        expect(notificationCount, 2);

        manager.setPrewarmVideos(['video2'], currentIndex: 0);
        expect(notificationCount, 3);

        unsubscribe();

        manager.setActiveVideo('video1', index: 1);
        expect(notificationCount, 3);
      });
    });

    group('active video management', () {
      setUp(() async {
        await VideoControllerPoolManager.initialize(
          poolSize: 2,
          controllerFactory: createMockController,
        );
      });

      test('sets and gets active video correctly', () async {
        final manager = VideoControllerPoolManager.instance;

        expect(manager.activeVideoId, isNull);

        manager.setActiveVideo('video1', index: 0);
        expect(manager.activeVideoId, 'video1');
      });

      test('does not notify if same video and index', () async {
        final manager = VideoControllerPoolManager.instance;
        var notificationCount = 0;

        manager
          ..addPoolChangeListener(() => notificationCount++)
          ..setActiveVideo('video1', index: 0);
        expect(notificationCount, 1);

        manager.setActiveVideo('video1', index: 0);
        expect(notificationCount, 1);

        manager.setActiveVideo('video1', index: 1);
        expect(notificationCount, 2);
      });
    });

    group('prewarm video management', () {
      setUp(() async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );
      });

      test('limits prewarm videos to poolSize - 1', () async {
        final manager = VideoControllerPoolManager.instance
          ..setPrewarmVideos(['v1', 'v2', 'v3', 'v4', 'v5']);

        expect(manager.prewarmVideoIds.length, 2);
        expect(manager.prewarmVideoIds.contains('v1'), isTrue);
        expect(manager.prewarmVideoIds.contains('v2'), isTrue);
        expect(manager.prewarmVideoIds.contains('v3'), isFalse);
      });

      test('clears previous prewarm videos', () async {
        final manager = VideoControllerPoolManager.instance
          ..setPrewarmVideos(['v1', 'v2']);
        expect(manager.prewarmVideoIds.length, 2);

        manager.setPrewarmVideos(['v3']);
        expect(manager.prewarmVideoIds.length, 1);
        expect(manager.prewarmVideoIds.contains('v3'), isTrue);
        expect(manager.prewarmVideoIds.contains('v1'), isFalse);
      });
    });

    group('memory pressure handling', () {
      setUp(() async {
        await VideoControllerPoolManager.initialize(
          poolSize: 4,
          controllerFactory: createMockController,
        );
      });

      test('releases 50% of controllers on memory pressure', () async {
        final manager = VideoControllerPoolManager.instance;

        await manager.acquireController(
          videoId: 'video1',
          videoUrl: 'https://example.com/video1.mp4',
        );
        await manager.acquireController(
          videoId: 'video2',
          videoUrl: 'https://example.com/video2.mp4',
        );
        await manager.acquireController(
          videoId: 'video3',
          videoUrl: 'https://example.com/video3.mp4',
        );
        await manager.acquireController(
          videoId: 'video4',
          videoUrl: 'https://example.com/video4.mp4',
        );

        expect(manager.assignedControllers.length, 4);

        await manager.handleMemoryPressure();

        expect(manager.assignedControllers.length, 2);
      });

      test('does not release active video under memory pressure', () async {
        final manager = VideoControllerPoolManager.instance;

        await manager.acquireController(
          videoId: 'video1',
          videoUrl: 'https://example.com/video1.mp4',
        );
        await manager.acquireController(
          videoId: 'video2',
          videoUrl: 'https://example.com/video2.mp4',
        );

        manager.setActiveVideo('video1');

        await manager.handleMemoryPressure();

        expect(manager.assignedControllers.containsKey('video1'), isTrue);
      });
    });

    group('pool clearing', () {
      setUp(() async {
        await VideoControllerPoolManager.initialize(
          poolSize: 3,
          controllerFactory: createMockController,
        );
      });

      test('clears all controllers and resets state', () async {
        final manager = VideoControllerPoolManager.instance;

        await manager.acquireController(
          videoId: 'video1',
          videoUrl: 'https://example.com/video1.mp4',
        );
        await manager.acquireController(
          videoId: 'video2',
          videoUrl: 'https://example.com/video2.mp4',
        );

        manager
          ..setActiveVideo('video1', index: 0)
          ..setPrewarmVideos(['video2'], currentIndex: 0);

        await manager.clearPool();

        expect(manager.assignedControllers.isEmpty, isTrue);
        expect(manager.activeVideoId, isNull);
        expect(manager.prewarmVideoIds.isEmpty, isTrue);
      });
    });

    group('controller release', () {
      setUp(() async {
        await VideoControllerPoolManager.initialize(
          poolSize: 2,
          controllerFactory: createMockController,
        );
      });

      test('keeps controller in pool after release', () async {
        final manager = VideoControllerPoolManager.instance;

        await manager.acquireController(
          videoId: 'video1',
          videoUrl: 'https://example.com/video1.mp4',
        );

        manager.releaseController('video1');

        expect(manager.assignedControllers.containsKey('video1'), isTrue);
      });

      test('removes from prewarm set after release', () async {
        final manager = VideoControllerPoolManager.instance;

        await manager.acquireController(
          videoId: 'video1',
          videoUrl: 'https://example.com/video1.mp4',
        );
        manager.setPrewarmVideos(['video1']);

        expect(manager.prewarmVideoIds.contains('video1'), isTrue);

        manager.releaseController('video1');

        expect(manager.prewarmVideoIds.contains('video1'), isFalse);
      });
    });

    group('video index registration', () {
      setUp(() async {
        await VideoControllerPoolManager.initialize(
          poolSize: 2,
          controllerFactory: createMockController,
        );
      });

      test('registers video indices for distance calculation', () async {
        final manager = VideoControllerPoolManager.instance
          ..registerVideoIndex('video1', 0)
          ..registerVideoIndex('video2', 5);

        await manager.acquireController(
          videoId: 'video1',
          videoUrl: 'https://example.com/video1.mp4',
        );
        await manager.acquireController(
          videoId: 'video2',
          videoUrl: 'https://example.com/video2.mp4',
        );

        manager.setActiveVideo('video1', index: 0);

        await manager.acquireController(
          videoId: 'video3',
          videoUrl: 'https://example.com/video3.mp4',
        );

        expect(manager.assignedControllers.containsKey('video2'), isFalse);
      });
    });

    group('concurrent initialization limit', () {
      test('queues requests beyond max concurrent', () async {
        await VideoControllerPoolManager.initialize(
          poolSize: 10,
          controllerFactory: (videoUrl, {cachedFile}) async {
            await Future<void>.delayed(const Duration(milliseconds: 50));
            return createMockController(videoUrl, cachedFile: cachedFile);
          },
        );

        final manager = VideoControllerPoolManager.instance;
        final futures = <Future<PooledController?>>[];

        for (var i = 0; i < 8; i++) {
          futures.add(
            manager.acquireController(
              videoId: 'video$i',
              videoUrl: 'https://example.com/video$i.mp4',
            ),
          );
        }

        final results = await Future.wait(futures);

        expect(results.where((r) => r != null).length, 8);
        expect(manager.assignedControllers.length, 8);
      });
    });

    group('acquisition cancellation', () {
      test('cancelAcquisition marks video as cancelled', () async {
        await VideoControllerPoolManager.initialize(
          poolSize: 4,
          controllerFactory: (videoUrl, {cachedFile}) async {
            // Slow controller creation to allow cancellation
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return createMockController(videoUrl, cachedFile: cachedFile);
          },
        );

        final manager = VideoControllerPoolManager.instance;

        // Start acquisition
        final future = manager.acquireController(
          videoId: 'video1',
          videoUrl: 'https://example.com/video1.mp4',
        );

        // Wait a bit then cancel
        await Future<void>.delayed(const Duration(milliseconds: 10));
        manager.cancelAcquisition('video1');

        // Acquisition should return null
        final result = await future;
        expect(result, isNull);
        expect(manager.assignedControllers.containsKey('video1'), isFalse);
      });

      test('inFlightVideoIds tracks in-progress acquisitions', () async {
        await VideoControllerPoolManager.initialize(
          poolSize: 4,
          controllerFactory: (videoUrl, {cachedFile}) async {
            await Future<void>.delayed(const Duration(milliseconds: 100));
            return createMockController(videoUrl, cachedFile: cachedFile);
          },
        );

        final manager = VideoControllerPoolManager.instance;

        expect(manager.inFlightVideoIds, isEmpty);

        // Start acquisition without awaiting
        unawaited(
          manager.acquireController(
            videoId: 'video1',
            videoUrl: 'https://example.com/video1.mp4',
          ),
        );

        // Should be tracked as in-flight
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(manager.inFlightVideoIds.contains('video1'), isTrue);
      });

      test('cancelDistantInFlightRequests cancels far videos', () async {
        await VideoControllerPoolManager.initialize(
          poolSize: 10,
          controllerFactory: (videoUrl, {cachedFile}) async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return createMockController(videoUrl, cachedFile: cachedFile);
          },
        );

        final manager = VideoControllerPoolManager.instance
          ..registerVideoIndex('video0', 0)
          ..registerVideoIndex('video10', 10)
          ..registerVideoIndex('video2', 2);

        // Start acquisitions
        final futures = [
          manager.acquireController(
            videoId: 'video0',
            videoUrl: 'https://example.com/video0.mp4',
          ),
          manager.acquireController(
            videoId: 'video10',
            videoUrl: 'https://example.com/video10.mp4',
          ),
          manager.acquireController(
            videoId: 'video2',
            videoUrl: 'https://example.com/video2.mp4',
          ),
        ];

        // Wait for requests to start
        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Cancel distant requests from index 1 (video10 is far)
        manager.cancelDistantInFlightRequests(1);

        final results = await Future.wait(futures);

        // video0 (distance 1) and video2 (distance 1) should succeed
        // video10 (distance 9) should be cancelled
        expect(results[0], isNotNull); // video0
        expect(results[1], isNull); // video10 - cancelled
        expect(results[2], isNotNull); // video2
      });

      test('fast scroll triggers automatic cancellation', () async {
        await VideoControllerPoolManager.initialize(
          poolSize: 10,
          controllerFactory: (videoUrl, {cachedFile}) async {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            return createMockController(videoUrl, cachedFile: cachedFile);
          },
        );

        final manager = VideoControllerPoolManager.instance
          ..registerVideoIndex('video0', 0)
          ..registerVideoIndex('video15', 15)
          ..setActiveVideo('video0', index: 0);

        final future = manager.acquireController(
          videoId: 'video15',
          videoUrl: 'https://example.com/video15.mp4',
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));

        // Fast scroll from 0 to 5 (jump of 5)
        // This should trigger cancellation of video15 (distance 10 from 5)
        manager.setActiveVideo('video5', index: 5);

        final result = await future;

        // video15 should be cancelled because it's far from index 5
        expect(result, isNull);
      });
    });
  });

  group('PooledController', () {
    test('toString returns formatted string', () async {
      await VideoControllerPoolManager.initialize(
        poolSize: 2,
        controllerFactory: createMockController,
      );

      final pooled = await VideoControllerPoolManager.instance
          .acquireController(
            videoId: 'test-video',
            videoUrl: 'https://example.com/video.mp4',
          );

      expect(pooled, isNotNull);
      expect(pooled!.toString(), 'PooledController(videoId: test-video)');
    });
  });

  group('edge cases', () {
    test('eviction disposes playing controller', () async {
      await VideoControllerPoolManager.initialize(
        poolSize: 2,
        controllerFactory: (videoUrl, {cachedFile}) async {
          final controller = MockVideoPlayerController();
          final value = MockVideoPlayerValue();

          when(() => value.isInitialized).thenReturn(true);
          // Mark as playing so pause() is called during eviction
          when(() => value.isPlaying).thenReturn(true);
          when(() => controller.value).thenReturn(value);
          when(controller.dispose).thenAnswer((_) async {});
          when(controller.pause).thenAnswer((_) async {});
          when(controller.play).thenAnswer((_) async {});
          when(() => controller.setLooping(any())).thenAnswer((_) async {});

          return controller;
        },
      );

      final manager = VideoControllerPoolManager.instance;

      // Fill pool
      final pooled1 = await manager.acquireController(
        videoId: 'video1',
        videoUrl: 'https://example.com/video1.mp4',
      );
      await manager.acquireController(
        videoId: 'video2',
        videoUrl: 'https://example.com/video2.mp4',
      );

      // Evict video1 by adding video3
      await manager.acquireController(
        videoId: 'video3',
        videoUrl: 'https://example.com/video3.mp4',
      );

      // Verify pause was called during eviction (because isPlaying was true)
      verify(pooled1!.controller.pause).called(1);
    });

    test('_getSortedByPriority skips active video', () async {
      await VideoControllerPoolManager.initialize(
        poolSize: 4,
        controllerFactory: createMockController,
      );

      final manager = VideoControllerPoolManager.instance;

      // Add videos
      await manager.acquireController(
        videoId: 'video1',
        videoUrl: 'https://example.com/video1.mp4',
      );
      await manager.acquireController(
        videoId: 'video2',
        videoUrl: 'https://example.com/video2.mp4',
      );
      await manager.acquireController(
        videoId: 'video3',
        videoUrl: 'https://example.com/video3.mp4',
      );

      // Set video2 as active
      manager.setActiveVideo('video2', index: 1);

      // Trigger memory pressure which uses _getSortedByPriority
      await manager.handleMemoryPressure();

      // Active video should still be in pool
      expect(manager.assignedControllers.containsKey('video2'), isTrue);
    });

    test('_getSortedByPriority puts prewarmed videos last', () async {
      await VideoControllerPoolManager.initialize(
        poolSize: 4,
        controllerFactory: createMockController,
      );

      final manager = VideoControllerPoolManager.instance;

      // Add 4 videos
      await manager.acquireController(
        videoId: 'video1',
        videoUrl: 'https://example.com/video1.mp4',
      );
      await manager.acquireController(
        videoId: 'video2',
        videoUrl: 'https://example.com/video2.mp4',
      );
      await manager.acquireController(
        videoId: 'video3',
        videoUrl: 'https://example.com/video3.mp4',
      );
      await manager.acquireController(
        videoId: 'video4',
        videoUrl: 'https://example.com/video4.mp4',
      );

      // Set video1 as active, video2 and video3 as prewarmed
      manager
        ..setActiveVideo('video1', index: 0)
        ..setPrewarmVideos(['video2', 'video3']);

      // Now trigger memory pressure - it should release video4 first (cached),
      // then prewarmed videos (video2, video3) last
      await manager.handleMemoryPressure();

      // Active video should still be in pool
      expect(manager.assignedControllers.containsKey('video1'), isTrue);

      // At least one prewarmed should remain since memory pressure
      // releases up to 50% of the pool
      expect(
        manager.assignedControllers.containsKey('video2') ||
            manager.assignedControllers.containsKey('video3'),
        isTrue,
      );
    });

    test('handles getCachedFile callback', () async {
      await VideoControllerPoolManager.initialize(
        poolSize: 2,
        controllerFactory: createMockController,
      );

      var getCachedFileCalled = false;

      await VideoControllerPoolManager.instance.acquireController(
        videoId: 'video1',
        videoUrl: 'https://example.com/video1.mp4',
        getCachedFile: (videoId) {
          getCachedFileCalled = true;
          return null; // Return null (no cached file)
        },
      );

      expect(getCachedFileCalled, isTrue);
    });
  });
}
