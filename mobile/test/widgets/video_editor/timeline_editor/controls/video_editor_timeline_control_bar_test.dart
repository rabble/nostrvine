// ABOUTME: Widget tests for TimelineControlsBar.
// ABOUTME: Verifies visibility logic for clip controls.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_clip_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_control_bar.dart';

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

class _MockTimelineOverlayBloc
    extends MockBloc<TimelineOverlayEvent, TimelineOverlayState>
    implements TimelineOverlayBloc {}

void main() {
  group(TimelineControlsBar, () {
    late _MockClipEditorBloc clipBloc;
    late _MockTimelineOverlayBloc overlayBloc;

    setUp(() {
      clipBloc = _MockClipEditorBloc();
      overlayBloc = _MockTimelineOverlayBloc();

      when(() => clipBloc.state).thenReturn(const ClipEditorState());
      when(
        () => clipBloc.stream,
      ).thenAnswer((_) => const Stream<ClipEditorState>.empty());

      when(() => overlayBloc.state).thenReturn(const TimelineOverlayState());
      when(
        () => overlayBloc.stream,
      ).thenAnswer((_) => const Stream<TimelineOverlayState>.empty());
    });

    Widget build({required bool isEditing}) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<ClipEditorBloc>.value(value: clipBloc),
                BlocProvider<TimelineOverlayBloc>.value(value: overlayBloc),
              ],
              child: TimelineControlsBar(
                isEditing: isEditing,
                playheadPosition: ValueNotifier(Duration.zero),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows no controls when not editing and no overlay selected', (
      tester,
    ) async {
      await tester.pumpWidget(build(isEditing: false));

      expect(find.byType(TimelineClipControls), findsNothing);
    });

    testWidgets('shows clip controls when editing is active', (tester) async {
      await tester.pumpWidget(build(isEditing: true));

      expect(find.byType(TimelineClipControls), findsOneWidget);
    });
  });
}
