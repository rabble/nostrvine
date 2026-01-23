import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';
import 'package:video_player/video_player.dart';

class MockVideoPlayerController extends Mock implements VideoPlayerController {}

class MockVideoPlayerValue extends Mock implements VideoPlayerValue {}

Future<VideoPlayerController?> createMockController(
  String videoUrl, {
  File? cachedFile,
}) async {
  final controller = MockVideoPlayerController();
  final value = MockVideoPlayerValue();

  when(() => value.isInitialized).thenReturn(true);
  when(() => value.isPlaying).thenReturn(false);
  when(() => controller.value).thenReturn(value);
  when(controller.dispose).thenAnswer((_) async {});
  when(controller.pause).thenAnswer((_) async {});
  when(controller.play).thenAnswer((_) async {});
  when(() => controller.setLooping(any())).thenAnswer((_) async {});

  return controller;
}

void main() {
  tearDown(() async {
    await VideoControllerPoolManager.reset();
  });

  group('VideoPoolProvider', () {
    testWidgets('provides pool to descendants via of()', (tester) async {
      await VideoControllerPoolManager.initialize(
        poolSize: 3,
        controllerFactory: createMockController,
      );

      VideoControllerPoolManager? capturedPool;

      await tester.pumpWidget(
        MaterialApp(
          home: VideoPoolProvider(
            pool: VideoControllerPoolManager.instance,
            child: Builder(
              builder: (context) {
                capturedPool = VideoPoolProvider.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(capturedPool, isNotNull);
      expect(capturedPool, equals(VideoControllerPoolManager.instance));
    });

    testWidgets('of() falls back to singleton when no provider', (
      tester,
    ) async {
      await VideoControllerPoolManager.initialize(
        poolSize: 3,
        controllerFactory: createMockController,
      );

      VideoControllerPoolManager? capturedPool;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedPool = VideoPoolProvider.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(capturedPool, isNotNull);
      expect(capturedPool, equals(VideoControllerPoolManager.instance));
    });

    testWidgets('of() throws when no provider and singleton not initialized', (
      tester,
    ) async {
      // Don't initialize the singleton

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(
                () => VideoPoolProvider.of(context),
                throwsStateError,
              );
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('maybeOf() returns pool from provider', (tester) async {
      await VideoControllerPoolManager.initialize(
        poolSize: 3,
        controllerFactory: createMockController,
      );

      VideoControllerPoolManager? capturedPool;

      await tester.pumpWidget(
        MaterialApp(
          home: VideoPoolProvider(
            pool: VideoControllerPoolManager.instance,
            child: Builder(
              builder: (context) {
                capturedPool = VideoPoolProvider.maybeOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(capturedPool, isNotNull);
      expect(capturedPool, equals(VideoControllerPoolManager.instance));
    });

    testWidgets('maybeOf() falls back to singleton when no provider', (
      tester,
    ) async {
      await VideoControllerPoolManager.initialize(
        poolSize: 3,
        controllerFactory: createMockController,
      );

      VideoControllerPoolManager? capturedPool;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedPool = VideoPoolProvider.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(capturedPool, isNotNull);
      expect(capturedPool, equals(VideoControllerPoolManager.instance));
    });

    testWidgets('maybeOf() returns null when no provider and not initialized', (
      tester,
    ) async {
      // Don't initialize the singleton

      VideoControllerPoolManager? capturedPool;
      var builderCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              builderCalled = true;
              capturedPool = VideoPoolProvider.maybeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(builderCalled, isTrue);
      expect(capturedPool, isNull);
    });

    testWidgets('updateShouldNotify returns true when pool changes', (
      tester,
    ) async {
      await VideoControllerPoolManager.initialize(
        poolSize: 2,
        controllerFactory: createMockController,
      );

      final pool1 = VideoControllerPoolManager.instance;

      await VideoControllerPoolManager.initialize(
        poolSize: 4,
        controllerFactory: createMockController,
      );

      final pool2 = VideoControllerPoolManager.instance;

      expect(pool1, isNot(equals(pool2)));

      final provider1 = VideoPoolProvider(pool: pool1, child: const SizedBox());
      final provider2 = VideoPoolProvider(pool: pool2, child: const SizedBox());

      expect(provider2.updateShouldNotify(provider1), isTrue);
    });

    testWidgets('updateShouldNotify returns false when pool is same', (
      tester,
    ) async {
      await VideoControllerPoolManager.initialize(
        poolSize: 3,
        controllerFactory: createMockController,
      );

      final pool = VideoControllerPoolManager.instance;

      final provider1 = VideoPoolProvider(pool: pool, child: const SizedBox());
      final provider2 = VideoPoolProvider(pool: pool, child: const SizedBox());

      expect(provider2.updateShouldNotify(provider1), isFalse);
    });
  });
}
