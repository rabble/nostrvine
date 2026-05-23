// ABOUTME: Lifecycle tests for VideoMetricsTracker view analytics
// ABOUTME: Verifies video_player finalization, short-view filtering, and video changes

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
import 'package:openvine/widgets/video_metrics_tracker.dart';
import 'package:video_player/video_player.dart';

import '../helpers/web_video_player_test_doubles.dart';

class _MockAuthService extends Mock implements AuthService {}

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
  group(VideoMetricsTracker, () {
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
      await tester.pumpWidget(
        _buildTracker(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: _initializedController(isPlaying: false),
          video: _video,
          clock: () => now,
        ),
      );

      expect(
        analyticsService.events.map((event) => event.eventType),
        contains('view_start'),
      );
    });

    testWidgets('dispose after one second sends one view_end', (tester) async {
      await tester.pumpWidget(
        _buildTracker(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: _initializedController(isPlaying: true),
          video: _video,
          clock: () => now,
        ),
      );

      now = now.add(const Duration(milliseconds: 1200));
      await tester.pumpWidget(const SizedBox.shrink());

      final viewEndEvents = _viewEndEvents(analyticsService);
      expect(viewEndEvents, hasLength(1));
      expect(viewEndEvents.single.video.id, equals('video_id'));
      expect(viewEndEvents.single.userId, equals('viewer_pubkey'));
      expect(
        viewEndEvents.single.watchDuration,
        const Duration(milliseconds: 1200),
      );
      expect(viewEndEvents.single.totalDuration, const Duration(seconds: 5));
      expect(viewEndEvents.single.trafficSource, ViewTrafficSource.home);
      expect(seenVideosService.records.single.videoId, equals('video_id'));
    });

    testWidgets('dispose under one second omits view_end', (tester) async {
      await tester.pumpWidget(
        _buildTracker(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: _initializedController(isPlaying: true),
          video: _video,
          clock: () => now,
        ),
      );

      now = now.add(const Duration(milliseconds: 900));
      await tester.pumpWidget(const SizedBox.shrink());

      expect(_viewEndEvents(analyticsService), isEmpty);
      expect(seenVideosService.records, isEmpty);
    });

    testWidgets('controller becoming null finalizes once', (tester) async {
      final controller = ValueNotifier<FakeVideoPlayerController?>(
        _initializedController(isPlaying: true),
      );

      await tester.pumpWidget(
        _buildControllerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller,
          clock: () => now,
        ),
      );

      now = now.add(const Duration(milliseconds: 1200));
      controller.value = null;
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());

      final viewEndEvents = _viewEndEvents(analyticsService);
      expect(viewEndEvents, hasLength(1));
      expect(
        viewEndEvents.single.watchDuration,
        const Duration(milliseconds: 1200),
      );
      expect(viewEndEvents.single.totalDuration, const Duration(seconds: 5));
      expect(seenVideosService.records, hasLength(1));

      controller.dispose();
    });

    testWidgets('controller becoming non-null starts tracking', (tester) async {
      final controller = ValueNotifier<FakeVideoPlayerController?>(null);

      await tester.pumpWidget(
        _buildControllerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller,
          clock: () => now,
        ),
      );

      expect(analyticsService.events, isEmpty);

      controller.value = _initializedController(isPlaying: true);
      await tester.pump();

      expect(
        analyticsService.events.where(
          (event) => event.eventType == 'view_start',
        ),
        hasLength(1),
      );

      now = now.add(const Duration(milliseconds: 1300));
      await tester.pumpWidget(const SizedBox.shrink());

      expect(_viewEndEvents(analyticsService), hasLength(1));
      controller.dispose();
    });

    testWidgets('same video active inactive active creates separate sessions', (
      tester,
    ) async {
      final firstController = _initializedController(isPlaying: true);
      final secondController = _initializedController(isPlaying: true);
      final controller = ValueNotifier<FakeVideoPlayerController?>(
        firstController,
      );

      await tester.pumpWidget(
        _buildControllerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller,
          clock: () => now,
        ),
      );

      now = now.add(const Duration(milliseconds: 1200));
      controller.value = null;
      await tester.pump();
      controller.value = secondController;
      await tester.pump();
      now = now.add(const Duration(milliseconds: 1400));
      await tester.pumpWidget(const SizedBox.shrink());

      expect(
        analyticsService.events.where(
          (event) => event.eventType == 'view_start',
        ),
        hasLength(2),
      );
      expect(
        _viewEndEvents(analyticsService).map((event) => event.watchDuration),
        [
          const Duration(milliseconds: 1200),
          const Duration(milliseconds: 1400),
        ],
      );

      controller.dispose();
    });

    testWidgets('video id change finalizes old video and starts new one', (
      tester,
    ) async {
      final video = ValueNotifier(_video);
      final controller = _initializedController(isPlaying: true);

      await tester.pumpWidget(
        _buildTrackerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          controller: controller,
          video: video,
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

      video.dispose();
    });
  });
}

Widget _buildTracker({
  required AuthService authService,
  required AnalyticsService analyticsService,
  required SeenVideosService seenVideosService,
  required FakeVideoPlayerController controller,
  required VideoEvent video,
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
      child: VideoMetricsTracker(
        video: video,
        controller: controller,
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
  required FakeVideoPlayerController controller,
  required ValueNotifier<VideoEvent> video,
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
        builder: (context, currentVideo, _) => VideoMetricsTracker(
          video: currentVideo,
          controller: controller,
          trafficSource: ViewTrafficSource.home,
          clock: clock,
          child: const SizedBox.shrink(),
        ),
      ),
    ),
  );
}

Widget _buildControllerHarness({
  required AuthService authService,
  required AnalyticsService analyticsService,
  required SeenVideosService seenVideosService,
  required ValueNotifier<FakeVideoPlayerController?> controller,
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
      child: ValueListenableBuilder<FakeVideoPlayerController?>(
        valueListenable: controller,
        builder: (context, currentController, _) => VideoMetricsTracker(
          video: _video,
          controller: currentController,
          trafficSource: ViewTrafficSource.home,
          clock: clock,
          child: const SizedBox.shrink(),
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

FakeVideoPlayerController _initializedController({required bool isPlaying}) {
  return FakeVideoPlayerController(
    initialValue: VideoPlayerValue(
      duration: const Duration(seconds: 5),
      size: const Size(1080, 1920),
      isInitialized: true,
      isPlaying: isPlaying,
    ),
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
