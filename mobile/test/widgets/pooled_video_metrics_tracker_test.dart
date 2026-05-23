// ABOUTME: Lifecycle tests for PooledVideoMetricsTracker view analytics
// ABOUTME: Verifies active/inactive finalization, dispose behavior, and duplicate prevention

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/seen_videos_service.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/widgets/pooled_video_metrics_tracker.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockPlayer extends Mock implements Player {}

class _MockPlayerStream extends Mock implements PlayerStream {}

class _MockPlayerState extends Mock implements PlayerState {}

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
  group(PooledVideoMetricsTracker, () {
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
          player: _stubPlayer(isPlaying: false),
          isActive: true,
          clock: () => now,
        ),
      );

      expect(
        analyticsService.events.map((event) => event.eventType),
        contains('view_start'),
      );
    });

    testWidgets('active to inactive after one second sends one view_end', (
      tester,
    ) async {
      final isActive = ValueNotifier(true);
      final video = ValueNotifier(_video);
      final player = _stubPlayer(isPlaying: true);

      await tester.pumpWidget(
        _buildTrackerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          player: player,
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
      expect(seenVideosService.records, hasLength(1));
      expect(seenVideosService.records.single.videoId, equals('video_id'));

      isActive.dispose();
      video.dispose();
    });

    testWidgets('active to inactive under one second omits view_end', (
      tester,
    ) async {
      final isActive = ValueNotifier(true);
      final video = ValueNotifier(_video);
      final player = _stubPlayer(isPlaying: true);

      await tester.pumpWidget(
        _buildTrackerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          player: player,
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
    });

    testWidgets('dispose after one second sends one view_end', (tester) async {
      final player = _stubPlayer(isPlaying: true);

      await tester.pumpWidget(
        _buildTracker(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          player: player,
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
    });

    testWidgets('inactive then dispose does not duplicate view_end', (
      tester,
    ) async {
      final isActive = ValueNotifier(true);
      final video = ValueNotifier(_video);
      final player = _stubPlayer(isPlaying: true);

      await tester.pumpWidget(
        _buildTrackerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          player: player,
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
    });

    testWidgets('video id change finalizes old video and starts new one', (
      tester,
    ) async {
      final isActive = ValueNotifier(true);
      final video = ValueNotifier(_video);
      final player = _stubPlayer(isPlaying: true);

      await tester.pumpWidget(
        _buildTrackerHarness(
          authService: authService,
          analyticsService: analyticsService,
          seenVideosService: seenVideosService,
          player: player,
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
    });
  });
}

Widget _buildTracker({
  required AuthService authService,
  required AnalyticsService analyticsService,
  required SeenVideosService seenVideosService,
  required Player player,
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
      child: PooledVideoMetricsTracker(
        video: _video,
        player: player,
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
  required Player player,
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
          builder: (context, active, _) => PooledVideoMetricsTracker(
            video: currentVideo,
            player: player,
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

Player _stubPlayer({
  required bool isPlaying,
  Duration duration = const Duration(seconds: 5),
}) {
  final player = _MockPlayer();
  final stream = _MockPlayerStream();
  final state = _MockPlayerState();

  when(() => player.stream).thenReturn(stream);
  when(() => player.state).thenReturn(state);
  when(() => stream.playing).thenAnswer((_) => const Stream<bool>.empty());
  when(() => stream.position).thenAnswer((_) => const Stream<Duration>.empty());
  when(() => state.duration).thenReturn(duration);
  when(() => state.playing).thenReturn(isPlaying);

  return player;
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
