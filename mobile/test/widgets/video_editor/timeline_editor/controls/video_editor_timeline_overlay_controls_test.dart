// ABOUTME: Widget tests for TimelineOverlayControls.
// ABOUTME: Verifies safe empty rendering when selection is missing or unknown.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_overlay_controls.dart';

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

void main() {
  group(TimelineOverlayControls, () {
    late _MockTimelineOverlayBloc overlayBloc;

    setUp(() {
      overlayBloc = _MockTimelineOverlayBloc();
      when(() => overlayBloc.stream).thenAnswer(
        (_) => const Stream<TimelineOverlayState>.empty(),
      );
    });

    Widget build() {
      return MaterialApp(
        home: Scaffold(
          body: BlocProvider<TimelineOverlayBloc>.value(
            value: overlayBloc,
            child: const TimelineOverlayControls(),
          ),
        ),
      );
    }

    testWidgets('renders empty when no item is selected', (tester) async {
      when(
        () => overlayBloc.state,
      ).thenReturn(const TimelineOverlayState());

      await tester.pumpWidget(build());

      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('renders empty when selected id is not in items', (
      tester,
    ) async {
      when(() => overlayBloc.state).thenReturn(
        const TimelineOverlayState(
          selectedItemId: 'missing-id',
        ),
      );

      await tester.pumpWidget(build());

      expect(find.byType(SizedBox), findsOneWidget);
    });
  });
}
