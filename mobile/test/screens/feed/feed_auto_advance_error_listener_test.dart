// ABOUTME: Tests FeedAutoAdvancePastErrorListener firing rules: it should fire
// ABOUTME: onSkipBrokenVideo exactly once when the active item's playback
// ABOUTME: status goes non-ready, and only while Auto is effectively active.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/screens/feed/feed_auto_advance_error_listener.dart';

class _MockPlaybackStatusCubit extends MockCubit<VideoPlaybackStatusState>
    implements VideoPlaybackStatusCubit {}

Widget _host({
  required VideoPlaybackStatusCubit cubit,
  required String videoId,
  required bool isActive,
  required bool isAutoAdvanceActive,
  required VoidCallback onSkip,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: BlocProvider<VideoPlaybackStatusCubit>.value(
      value: cubit,
      child: FeedAutoAdvancePastErrorListener(
        videoId: videoId,
        isActive: isActive,
        isAutoAdvanceActive: isAutoAdvanceActive,
        onSkipBrokenVideo: onSkip,
        child: const SizedBox.shrink(),
      ),
    ),
  );
}

void main() {
  group(FeedAutoAdvancePastErrorListener, () {
    late _MockPlaybackStatusCubit cubit;
    late int skipCount;

    setUp(() {
      cubit = _MockPlaybackStatusCubit();
      when(() => cubit.state).thenReturn(VideoPlaybackStatusState());
      whenListen(
        cubit,
        const Stream<VideoPlaybackStatusState>.empty(),
        initialState: VideoPlaybackStatusState(),
      );
      skipCount = 0;
    });

    testWidgets(
      'fires onSkipBrokenVideo when status becomes non-ready for the active item',
      (tester) async {
        final states = <VideoPlaybackStatusState>[VideoPlaybackStatusState()];
        final updated = VideoPlaybackStatusState().withStatus(
          'video-1',
          PlaybackStatus.generic,
        );
        when(() => cubit.state).thenReturn(states.last);
        whenListen(
          cubit,
          Stream<VideoPlaybackStatusState>.fromIterable([updated]),
          initialState: states.last,
        );

        await tester.pumpWidget(
          _host(
            cubit: cubit,
            videoId: 'video-1',
            isActive: true,
            isAutoAdvanceActive: true,
            onSkip: () => skipCount++,
          ),
        );

        await tester.pump(); // deliver stream event
        await tester.pump(); // run post-frame callback

        expect(skipCount, equals(1));
      },
    );

    testWidgets('does not fire when Auto is inactive', (tester) async {
      final updated = VideoPlaybackStatusState().withStatus(
        'video-1',
        PlaybackStatus.generic,
      );
      whenListen(
        cubit,
        Stream<VideoPlaybackStatusState>.fromIterable([updated]),
        initialState: VideoPlaybackStatusState(),
      );

      await tester.pumpWidget(
        _host(
          cubit: cubit,
          videoId: 'video-1',
          isActive: true,
          isAutoAdvanceActive: false,
          onSkip: () => skipCount++,
        ),
      );

      await tester.pump();
      await tester.pump();
      expect(skipCount, equals(0));
    });

    testWidgets('does not fire when the item is not active', (tester) async {
      final updated = VideoPlaybackStatusState().withStatus(
        'video-1',
        PlaybackStatus.generic,
      );
      whenListen(
        cubit,
        Stream<VideoPlaybackStatusState>.fromIterable([updated]),
        initialState: VideoPlaybackStatusState(),
      );

      await tester.pumpWidget(
        _host(
          cubit: cubit,
          videoId: 'video-1',
          isActive: false,
          isAutoAdvanceActive: true,
          onSkip: () => skipCount++,
        ),
      );

      await tester.pump();
      await tester.pump();
      expect(skipCount, equals(0));
    });

    testWidgets('only fires once per broken streak', (tester) async {
      final generic = VideoPlaybackStatusState().withStatus(
        'video-1',
        PlaybackStatus.generic,
      );
      final notFound = VideoPlaybackStatusState().withStatus(
        'video-1',
        PlaybackStatus.notFound,
      );
      whenListen(
        cubit,
        Stream<VideoPlaybackStatusState>.fromIterable([generic, notFound]),
        initialState: VideoPlaybackStatusState(),
      );

      await tester.pumpWidget(
        _host(
          cubit: cubit,
          videoId: 'video-1',
          isActive: true,
          isAutoAdvanceActive: true,
          onSkip: () => skipCount++,
        ),
      );

      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(skipCount, equals(1));
    });

    testWidgets('fires when the user swipes onto an already-errored video', (
      tester,
    ) async {
      final errored = VideoPlaybackStatusState().withStatus(
        'video-1',
        PlaybackStatus.generic,
      );
      when(() => cubit.state).thenReturn(errored);
      whenListen(
        cubit,
        const Stream<VideoPlaybackStatusState>.empty(),
        initialState: errored,
      );

      await tester.pumpWidget(
        _host(
          cubit: cubit,
          videoId: 'video-1',
          isActive: false,
          isAutoAdvanceActive: true,
          onSkip: () => skipCount++,
        ),
      );
      await tester.pump();
      expect(skipCount, equals(0));

      // User swipes onto the broken item → isActive flips true.
      await tester.pumpWidget(
        _host(
          cubit: cubit,
          videoId: 'video-1',
          isActive: true,
          isAutoAdvanceActive: true,
          onSkip: () => skipCount++,
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(skipCount, equals(1));
    });

    testWidgets(
      'resets guard when the video id changes and fires again for a new error',
      (tester) async {
        final firstError = VideoPlaybackStatusState().withStatus(
          'video-1',
          PlaybackStatus.generic,
        );
        final secondError = firstError.withStatus(
          'video-2',
          PlaybackStatus.generic,
        );
        when(() => cubit.state).thenReturn(firstError);
        whenListen(
          cubit,
          Stream<VideoPlaybackStatusState>.fromIterable([secondError]),
          initialState: firstError,
        );

        await tester.pumpWidget(
          _host(
            cubit: cubit,
            videoId: 'video-1',
            isActive: true,
            isAutoAdvanceActive: true,
            onSkip: () => skipCount++,
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(skipCount, equals(1));

        // The item recycles to a new video, and that one fails too.
        await tester.pumpWidget(
          _host(
            cubit: cubit,
            videoId: 'video-2',
            isActive: true,
            isAutoAdvanceActive: true,
            onSkip: () => skipCount++,
          ),
        );
        await tester.pump();
        await tester.pump();
        expect(skipCount, equals(2));
      },
    );
  });
}
