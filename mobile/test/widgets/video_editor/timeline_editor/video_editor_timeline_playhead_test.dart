// ABOUTME: Widget tests for VideoEditorTimelinePlayhead.
// ABOUTME: Validates visibility animation and layout properties.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_playhead.dart';

class _MockVideoEditorMainBloc
    extends MockBloc<VideoEditorMainEvent, VideoEditorMainState>
    implements VideoEditorMainBloc {}

Widget _buildWidget({required bool isReordering}) {
  final bloc = _MockVideoEditorMainBloc();
  when(() => bloc.state).thenReturn(
    VideoEditorMainState(isReordering: isReordering),
  );
  when(() => bloc.stream).thenAnswer(
    (_) => Stream<VideoEditorMainState>.value(
      VideoEditorMainState(isReordering: isReordering),
    ),
  );

  return BlocProvider<VideoEditorMainBloc>.value(
    value: bloc,
    child: const Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: 400,
        height: 200,
        child: VideoEditorTimelinePlayhead(),
      ),
    ),
  );
}

void main() {
  group(VideoEditorTimelinePlayhead, () {
    group('renders', () {
      testWidgets('renders $VideoEditorTimelinePlayhead when visible', (
        tester,
      ) async {
        await tester.pumpWidget(_buildWidget(isReordering: false));

        expect(
          find.byType(VideoEditorTimelinePlayhead),
          findsOneWidget,
        );
      });

      testWidgets('renders playhead line with correct width', (tester) async {
        await tester.pumpWidget(_buildWidget(isReordering: false));

        final sizedBox = tester.widget<SizedBox>(
          find.byWidgetPredicate(
            (w) => w is SizedBox && w.width == TimelineConstants.playheadWidth,
          ),
        );
        expect(sizedBox.width, equals(TimelineConstants.playheadWidth));
      });

      testWidgets('renders with $VineTheme onSurface color', (tester) async {
        await tester.pumpWidget(_buildWidget(isReordering: false));

        final decoratedBox = tester.widget<DecoratedBox>(
          find.byType(DecoratedBox),
        );
        final decoration = decoratedBox.decoration as BoxDecoration;

        expect(
          decoration.color,
          equals(VineTheme.onSurface),
        );
      });
    });

    group('visibility', () {
      testWidgets('has full opacity when not reordering', (tester) async {
        await tester.pumpWidget(_buildWidget(isReordering: false));

        final animated = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animated.opacity, equals(1.0));
      });

      testWidgets('has zero opacity when reordering', (tester) async {
        await tester.pumpWidget(_buildWidget(isReordering: true));

        final animated = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animated.opacity, equals(0.0));
      });

      testWidgets('animates opacity over 200ms', (tester) async {
        await tester.pumpWidget(_buildWidget(isReordering: false));

        final animated = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(
          animated.duration,
          equals(const Duration(milliseconds: 200)),
        );
      });
    });

    group('interaction', () {
      testWidgets('ignores pointer events', (tester) async {
        await tester.pumpWidget(_buildWidget(isReordering: false));

        expect(find.byType(IgnorePointer), findsOneWidget);
      });
    });
  });
}
