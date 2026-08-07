import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_stop_motion_budget.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_progress_bar.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderStopMotionBudget, () {
    late _MockVideoRecorderBloc recorderBloc;
    late AppLocalizations l10n;

    setUp(() {
      recorderBloc = _MockVideoRecorderBloc();
      l10n = lookupAppLocalizations(const Locale('en'));
    });

    Widget buildWidget({required int capturedFrames}) {
      when(() => recorderBloc.state).thenReturn(
        VideoRecorderBlocState(
          recorderMode: .stopMotion,
          stopMotionFrames: [
            for (var i = 0; i < capturedFrames; i++) 'frame_$i.jpg',
          ],
        ),
      );

      return BlocProvider<VideoRecorderBloc>.value(
        value: recorderBloc,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // Renders a Flexible for the top bar's center slot, so it needs a
          // Row around it.
          home: Scaffold(
            body: Row(children: [VideoRecorderStopMotionBudget()]),
          ),
        ),
      );
    }

    /// The rendered count. The label is in the tree twice — once visible, once
    /// as the invisible spacer that drops the bar onto the buttons' center
    /// line — so this reads it off the bar rather than counting Text widgets.
    String renderedLabel(WidgetTester tester) => tester
        .widget<VideoRecorderProgressBar>(
          find.byType(VideoRecorderProgressBar),
        )
        .label;

    testWidgets('shows the full budget before the first still', (tester) async {
      await tester.pumpWidget(buildWidget(capturedFrames: 0));

      expect(
        renderedLabel(tester),
        l10n.videoRecorderStopMotionShotsLeft(
          StopMotionFrameOps.maxCaptureFrames,
        ),
      );
      expect(find.text(renderedLabel(tester)), findsWidgets);
    });

    testWidgets('counts the remaining stills down as frames are captured', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget(capturedFrames: 5));

      expect(
        renderedLabel(tester),
        l10n.videoRecorderStopMotionShotsLeft(
          StopMotionFrameOps.maxCaptureFrames - 5,
        ),
      );
    });

    testWidgets('puts the bar itself on the center line the row aligns to', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget(capturedFrames: 5));

      // The bar is the only Container in the subtree carrying a decoration;
      // the three segments are plain `Container(color:)`.
      final barRect = tester.getRect(
        find.byWidgetPredicate((w) => w is Container && w.decoration != null),
      );
      final groupRect = tester.getRect(
        find.byType(VideoRecorderStopMotionBudget),
      );

      // A Row centers its children, so the group's center is what lands on the
      // close/next buttons' center line — the bar has to sit on it, not the
      // count above it.
      expect(barRect.center.dy, moreOrLessEquals(groupRect.center.dy));
    });

    testWidgets('fills the bar in proportion to the stills captured', (
      tester,
    ) async {
      await tester.pumpWidget(buildWidget(capturedFrames: 5));

      final bar = tester.widget<VideoRecorderProgressBar>(
        find.byType(VideoRecorderProgressBar),
      );
      expect(bar.filled, 5);
      expect(bar.remaining, StopMotionFrameOps.maxCaptureFrames - 5);
      expect(bar.overflow, 0);
    });

    testWidgets('shows the overflow segment once the budget is blown', (
      tester,
    ) async {
      final over = StopMotionFrameOps.maxCaptureFrames + 3;
      await tester.pumpWidget(buildWidget(capturedFrames: over));

      final bar = tester.widget<VideoRecorderProgressBar>(
        find.byType(VideoRecorderProgressBar),
      );
      expect(bar.filled, StopMotionFrameOps.maxCaptureFrames);
      expect(bar.remaining, 0);
      expect(bar.overflow, 3);
      expect(bar.label, l10n.videoRecorderStopMotionShotsLeft(0));
    });
  });
}
