// ABOUTME: Tests for VideoEditorFilterBottomBar widget.
// ABOUTME: Validates filter list rendering, selection, and thumbnails.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/widgets/video_editor/filter_editor/video_editor_filter_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class MockVideoEditorFilterBloc
    extends MockBloc<VideoEditorFilterEvent, VideoEditorFilterState>
    implements VideoEditorFilterBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(VideoEditorFilterSelected(presetFiltersList.first));
  });

  group('VideoEditorFilterState selection', () {
    test('isSelected returns true for matching filter', () {
      final filter = presetFiltersList[1];
      final state = VideoEditorFilterState(
        filters: presetFiltersList,
        selectedFilter: filter,
      );
      expect(state.isSelected(filter), isTrue);
    });

    test('isSelected returns false for non-matching filter', () {
      final state = VideoEditorFilterState(
        filters: presetFiltersList,
        selectedFilter: presetFiltersList[1],
      );
      expect(state.isSelected(presetFiltersList[2]), isFalse);
    });

    test('isSelected returns true for None when selectedFilter is null', () {
      final state = VideoEditorFilterState(filters: presetFiltersList);
      expect(state.isSelected(PresetFilters.none), isTrue);
    });

    test('presetFiltersList has "No Filter" as first filter', () {
      expect(presetFiltersList.first.name, 'No Filter');
    });

    test('presetFiltersList has multiple filters', () {
      expect(presetFiltersList.length, greaterThan(1));
    });
  });

  group('VideoEditorFilterBottomBar empty clips', () {
    testWidgets('renders safely when no clips are available', (tester) async {
      final bodySizeNotifier = ValueNotifier(Size.zero);
      addTearDown(bodySizeNotifier.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: BlocProvider(
              create: (_) => VideoEditorFilterBloc(),
              child: VideoEditorScope(
                editorKey: GlobalKey(),
                removeAreaKey: GlobalKey(),
                onAddStickers: () {},
                onAdjustVolume: () {},
                onOpenClipsEditor: () {},
                onAddEditTextLayer: ([_]) async => null,
                originalClipAspectRatio: 9 / 16,
                bodySizeNotifier: bodySizeNotifier,
                fromLibrary: false,
                child: const Scaffold(
                  body: VideoEditorFilterBottomBar(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(ListView), findsNothing);
    });
  });
}
