// ABOUTME: Lifecycle tests for DivineVideoMetricsTracker view analytics
// ABOUTME: Verifies native player active/inactive, dispose, and video changes

import 'dart:async';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/widgets/divine_video_metrics_tracker.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockDivineVideoPlayerController extends Mock
    implements DivineVideoPlayerController {}

class _RecordingAnalyticsService extends AnalyticsService {
  final events = <_TrackedAnalyticsEvent>[];

  @override
  Future<void> trackDetailedVideoViewWithUser(
    VideoEvent video, {
    required String? userId,
    required String source,
    required String eventType,
    Duration? watchDuration,
    Duration? totalDuration,
    int? loopCount,
    bool? completedVideo,
    ViewTrafficSource trafficSource = ViewTrafficSource.unknown,
    String? sourceDetail,
  }) async {
    events.add(
      _TrackedAnalyticsEvent(
        video: video,
        userId: userId,
        source: source,
        eventType: eventType,
        watchDuration: watchDuration,
        totalDuration: totalDuration,
        loopCount: loopCount,
        completedVideo: completedVideo,
        trafficSource: trafficSource,
        sourceDetail: sourceDetail,
      ),
    );
  }
}

class _RecordingSeenVideosService extends SeenVideosService {
  final records = <_SeenVideoRecord>[];

  @override
  Future<void> recordVideoView(
    String videoId, {
    int? loopCount,
    Duration? watchDuration,
  }) async {
    records.add(
      _SeenVideoRecord(
        videoId: videoId,
        loopCount: loopCount,
        watchDuration: watchDuration,
      ),
    );
  }
}

class _TrackedAnalyticsEvent {
  const _TrackedAnalyticsEvent({
    required this.video,
    required this.userId,
    required this.source,
    required this.eventType,
    required this.watchDuration,
    required this.totalDuration,
    required this.loopCount,
    required this.completedVideo,
    required this.trafficSource,
    required this.sourceDetail,
  });

  final VideoEvent video;
  final String? userId;
  final String source;
  final String eventType;
  final Duration? watchDuration;
  final Duration? totalDuration;
  final int? loopCount;
  final bool? completedVideo;
  final ViewTrafficSource trafficSource;
  final String? sourceDetail;
}

class _SeenVideoRecord {
  const _SeenVideoRecord({
    required this.videoId,
    required this.loopCount,
    required this.watchDuration,
  });

  final String videoId;
  final int? loopCount;
  final Duration? watchDuration;
}

void main() {
  group(DivineVideoMetricsTracker, () {
    late _MockAuthService authService;
    late _RecordingAnalyticsService analyticsService;
    late _RecordingSeenVideosService seenVideosService;
    late DateTime now;

    setUp(() {
      authService = _MockAuthService();
      analyticsService = _RecordingAnalyticsService();
      seenVideosService = _RecordingSeenVideosService();
      now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

      when(() => authService.currentPublicKeyHex).thenReturn('viewer_pubkey');
    });

    testWidgets('active tracker sends view_start', (tester) async {
      final controller = _stubController(isPlaying: false);

      await tester.pumpWidget(
        _buildTracker(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          isActive: true,
          clock: () => now,
        ),
      );

      expect(
        analyticsService.events.map((event) => event.eventType),
        contains('view_start'),
      );

      await controller.close();
    });

    testWidgets('active to inactive after one second sends one view_end', (
      tester,
    ) async {
      final isActive = ValueNotifier(true);
      final video = ValueNotifier(_video);
      final controller = _stubController(isPlaying: true);

      await tester.pumpWidget(
        _buildTrackerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          video: video,
          isActive: isActive,
          clock: () => now,
        ),
      );

      now = now.add(const Duration(milliseconds: 1100));
      isActive.value = false;
      await tester.pump();

      final viewEndEvents = _viewEndEvents(analyticsService);
      expect(viewEndEvents, hasLength(1));
      expect(viewEndEvents.single.video.id, equals('video_id'));
      expect(viewEndEvents.single.userId, equals('viewer_pubkey'));
      expect(
        viewEndEvents.single.watchDuration,
        const Duration(milliseconds: 1100),
      );
      expect(viewEndEvents.single.totalDuration, const Duration(seconds: 5));
      expect(viewEndEvents.single.trafficSource, ViewTrafficSource.home);
      expect(seenVideosService.records.single.videoId, equals('video_id'));

      isActive.dispose();
      video.dispose();
      await controller.close();
    });

    testWidgets('active to inactive under one second omits view_end', (
      tester,
    ) async {
      final isActive = ValueNotifier(true);
      final video = ValueNotifier(_video);
      final controller = _stubController(isPlaying: true);

      await tester.pumpWidget(
        _buildTrackerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          video: video,
          isActive: isActive,
          clock: () => now,
        ),
      );

      now = now.add(const Duration(milliseconds: 900));
      isActive.value = false;
      await tester.pump();

      expect(_viewEndEvents(analyticsService), isEmpty);
      expect(seenVideosService.records, isEmpty);

      isActive.dispose();
      video.dispose();
      await controller.close();
    });

    testWidgets('dispose after one second sends one view_end', (tester) async {
      final controller = _stubController(isPlaying: true);

      await tester.pumpWidget(
        _buildTracker(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          isActive: true,
          clock: () => now,
        ),
      );

      now = now.add(const Duration(milliseconds: 1200));
      await tester.pumpWidget(const SizedBox.shrink());

      final viewEndEvents = _viewEndEvents(analyticsService);
      expect(viewEndEvents, hasLength(1));
      expect(
        viewEndEvents.single.watchDuration,
        const Duration(milliseconds: 1200),
      );
      expect(seenVideosService.records, hasLength(1));

      await controller.close();
    });

    testWidgets('inactive then dispose does not duplicate view_end', (
      tester,
    ) async {
      final isActive = ValueNotifier(true);
      final video = ValueNotifier(_video);
      final controller = _stubController(isPlaying: true);

      await tester.pumpWidget(
        _buildTrackerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          video: video,
          isActive: isActive,
          clock: () => now,
        ),
      );

      now = now.add(const Duration(milliseconds: 1100));
      isActive.value = false;
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());

      expect(_viewEndEvents(analyticsService), hasLength(1));
      expect(seenVideosService.records, hasLength(1));

      isActive.dispose();
      video.dispose();
      await controller.close();
    });

    testWidgets('video id change finalizes old video and starts new one', (
      tester,
    ) async {
      final isActive = ValueNotifier(true);
      final video = ValueNotifier(_video);
      final controller = _stubController(isPlaying: true);

      await tester.pumpWidget(
        _buildTrackerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller.controller,
          video: video,
          isActive: isActive,
          clock: () => now,
        ),
      );

      now = now.add(const Duration(milliseconds: 1300));
      video.value = _secondVideo;
      await tester.pump();

      final viewEndEvents = _viewEndEvents(analyticsService);
      expect(viewEndEvents, hasLength(1));
      expect(viewEndEvents.single.video.id, equals('video_id'));
      expect(
        analyticsService.events.where(
          (event) => event.eventType == 'view_start',
        ),
        hasLength(2),
      );
      expect(seenVideosService.records.single.videoId, equals('video_id'));

      isActive.dispose();
      video.dispose();
      await controller.close();
    });
  });
}

Widget _buildTracker({
  required AuthService authService,
  required AnalyticsService analyticsService,
  required SeenVideosService seenVideosService,
  required DivineVideoPlayerController controller,
  required bool isActive,
  required DateTime Function() clock,
}) {
  return ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(authService),
      analyticsServiceProvider.overrideWithValue(analyticsService),
      seenVideosServiceProvider.overrideWithValue(seenVideosService),
    ],
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: DivineVideoMetricsTracker(
        video: _video,
        controller: controller,
        isActive: isActive,
        trafficSource: ViewTrafficSource.home,
        clock: clock,
        child: const SizedBox.shrink(),
      ),
    ),
  );
}

Widget _buildTrackerHarness({
  required AuthService authService,
  required AnalyticsService analyticsService,
  required SeenVideosService seenVideosService,
  required DivineVideoPlayerController controller,
  required ValueListenable<VideoEvent> video,
  required ValueListenable<bool> isActive,
  required DateTime Function() clock,
}) {
  return ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(authService),
      analyticsServiceProvider.overrideWithValue(analyticsService),
      seenVideosServiceProvider.overrideWithValue(seenVideosService),
    ],
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: ValueListenableBuilder<VideoEvent>(
        valueListenable: video,
        builder: (context, currentVideo, _) => ValueListenableBuilder<bool>(
          valueListenable: isActive,
          builder: (context, active, _) => DivineVideoMetricsTracker(
            video: currentVideo,
            controller: controller,
            isActive: active,
            trafficSource: ViewTrafficSource.home,
            clock: clock,
            child: const SizedBox.shrink(),
          ),
        ),
      ),
    ),
  );
}

List<_TrackedAnalyticsEvent> _viewEndEvents(
  _RecordingAnalyticsService analyticsService,
) => analyticsService.events
    .where((event) => event.eventType == 'view_end')
    .toList();

({DivineVideoPlayerController controller, Future<void> Function() close})
_stubController({
  required bool isPlaying,
  Duration duration = const Duration(seconds: 5),
}) {
  final controller = _MockDivineVideoPlayerController();
  final stateController = StreamController<DivineVideoPlayerState>.broadcast();
  var state = DivineVideoPlayerState(
    status: isPlaying ? PlaybackStatus.playing : PlaybackStatus.ready,
    duration: duration,
    isFirstFrameRendered: true,
  );

  when(() => controller.isInitialized).thenReturn(true);
  when(() => controller.state).thenAnswer((_) => state);
  when(() => controller.stateStream).thenAnswer((_) => stateController.stream);

  return (
    controller: controller,
    close: () async {
      await stateController.close();
      state = const DivineVideoPlayerState();
    },
  );
}

final _video = VideoEvent(
  id: 'video_id',
  pubkey: 'creator_pubkey',
  createdAt: 1700000000,
  content: 'test video',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
);

final _secondVideo = VideoEvent(
  id: 'second_video_id',
  pubkey: 'creator_pubkey',
  createdAt: 1700000001,
  content: 'second test video',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1700000001000),
);
