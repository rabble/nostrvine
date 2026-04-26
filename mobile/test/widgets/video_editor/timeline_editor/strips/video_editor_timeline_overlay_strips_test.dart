// ABOUTME: Widget tests for TimelineOverlayStrips.
// ABOUTME: Verifies strip rendering from overlay bloc state.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_strip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_strips.dart';

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

void main() {
  group(TimelineOverlayStrips, () {
    late _MockTimelineOverlayBloc overlayBloc;

    setUp(() {
      overlayBloc = _MockTimelineOverlayBloc();
      when(
        () => overlayBloc.stream,
      ).thenAnswer((_) => const Stream<TimelineOverlayState>.empty());
    });

    Widget build() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<TimelineOverlayBloc>.value(
            value: overlayBloc,
            child: TimelineOverlayStrips(
              totalWidth: 600,
              pixelsPerSecond: 80,
              totalDuration: const Duration(seconds: 10),
              clipEdgesMs: const [0, 3000, 7000],
              playheadPosition: ValueNotifier(Duration.zero),
            ),
          ),
        ),
      );
    }

    testWidgets('renders no strip when overlay items are empty', (
      tester,
    ) async {
      when(() => overlayBloc.state).thenReturn(const TimelineOverlayState());

      await tester.pumpWidget(build());

      expect(find.byType(TimelineOverlayStrip), findsNothing);
    });

    testWidgets('renders one strip per overlay type with items', (
      tester,
    ) async {
      when(() => overlayBloc.state).thenReturn(
        const TimelineOverlayState(
          items: [
            TimelineOverlayItem(
              id: 'sound',
              type: TimelineOverlayType.sound,
              startTime: Duration.zero,
              endTime: Duration(seconds: 1),
            ),
            TimelineOverlayItem(
              id: 'filter',
              type: TimelineOverlayType.filter,
              startTime: Duration(seconds: 1),
              endTime: Duration(seconds: 2),
            ),
            TimelineOverlayItem(
              id: 'layer',
              type: TimelineOverlayType.layer,
              startTime: Duration(seconds: 2),
              endTime: Duration(seconds: 3),
            ),
          ],
        ),
      );

      await tester.pumpWidget(build());

      expect(find.byType(TimelineOverlayStrip), findsNWidgets(3));
    });
  });
}
