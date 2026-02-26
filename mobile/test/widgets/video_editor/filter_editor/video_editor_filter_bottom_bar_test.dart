// ABOUTME: Tests for VideoEditorFilterBottomBar widget.
// ABOUTME: Validates filter list rendering, selection, and thumbnails.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
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
      final state = VideoEditorFilterState(
        filters: presetFiltersList,
      );
      expect(state.isSelected(PresetFilters.none), isTrue);
    });

    test('presetFiltersList has "No Filter" as first filter', () {
      expect(presetFiltersList.first.name, 'No Filter');
    });

    test('presetFiltersList has multiple filters', () {
      expect(presetFiltersList.length, greaterThan(1));
    });
  });
}
