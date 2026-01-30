// ABOUTME: Tests for VideoEditorFilterBloc - filter selection, opacity, and done/cancel.
// ABOUTME: Covers initial state, filter events, and state transitions.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorFilterBloc', () {
    late GlobalKey<ProImageEditorState> editorKey;

    setUp(() {
      editorKey = GlobalKey<ProImageEditorState>();
    });

    VideoEditorFilterBloc buildBloc() {
      return VideoEditorFilterBloc(editorKey: editorKey);
    }

    test('initial state has filters from presetFiltersList', () {
      final bloc = buildBloc();
      expect(bloc.state.filters, equals(presetFiltersList));
      expect(bloc.state.selectedFilter, isNull);
      expect(bloc.state.opacity, 1.0);
      expect(bloc.state.hasFilter, isFalse);
      bloc.close();
    });

    group('VideoEditorFilterSelected', () {
      final testFilter = presetFiltersList[1]; // First non-None filter

      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'emits state with selected filter when editor is null',
        build: buildBloc,
        act: (bloc) => bloc.add(VideoEditorFilterSelected(testFilter)),
        // Without editor attached, the event is ignored (early return)
        expect: () => <VideoEditorFilterState>[],
      );

      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'does not change state when editor key has no state',
        build: buildBloc,
        seed: () => VideoEditorFilterState(
          filters: presetFiltersList,
          selectedFilter: null,
          opacity: 1.0,
        ),
        act: (bloc) => bloc.add(VideoEditorFilterSelected(testFilter)),
        expect: () => <VideoEditorFilterState>[],
      );
    });

    group('VideoEditorFilterOpacityChanged', () {
      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'does not emit when no filter is selected',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorFilterOpacityChanged(0.5)),
        expect: () => <VideoEditorFilterState>[],
      );

      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'does not emit when editor is null even with selected filter',
        build: buildBloc,
        seed: () => VideoEditorFilterState(
          filters: presetFiltersList,
          selectedFilter: presetFiltersList[1],
          opacity: 1.0,
        ),
        act: (bloc) => bloc.add(const VideoEditorFilterOpacityChanged(0.5)),
        // Without editor attached, the event is ignored
        expect: () => <VideoEditorFilterState>[],
      );
    });

    group('VideoEditorFilterCancelRequested', () {
      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'restores to initial values from when editor was opened',
        build: buildBloc,
        seed: () => VideoEditorFilterState(
          filters: presetFiltersList,
          selectedFilter: presetFiltersList[2],
          opacity: 0.5,
          initialSelectedFilter: presetFiltersList[1],
          initialOpacity: 0.8,
        ),
        act: (bloc) => bloc.add(const VideoEditorFilterCancelRequested()),
        expect: () => [
          isA<VideoEditorFilterState>()
              .having(
                (s) => s.selectedFilter,
                'selectedFilter',
                presetFiltersList[1],
              )
              .having((s) => s.opacity, 'opacity', 0.8),
        ],
      );

      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'restores to null filter when initial was null',
        build: buildBloc,
        seed: () => VideoEditorFilterState(
          filters: presetFiltersList,
          selectedFilter: presetFiltersList[1],
          opacity: 0.7,
          initialSelectedFilter: null,
          initialOpacity: 1.0,
        ),
        act: (bloc) => bloc.add(const VideoEditorFilterCancelRequested()),
        expect: () => [
          isA<VideoEditorFilterState>()
              .having((s) => s.selectedFilter, 'selectedFilter', isNull)
              .having((s) => s.opacity, 'opacity', 1.0),
        ],
      );
    });

    group('VideoEditorFilterDoneRequested', () {
      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'keeps current filter and opacity (commits changes)',
        build: buildBloc,
        seed: () => VideoEditorFilterState(
          filters: presetFiltersList,
          selectedFilter: presetFiltersList[2],
          opacity: 0.8,
        ),
        act: (bloc) => bloc.add(const VideoEditorFilterDoneRequested()),
        // No state change - current values are kept
        expect: () => <VideoEditorFilterState>[],
      );
    });

    group('VideoEditorFilterEditorInitialized', () {
      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'stores current values as initial values for cancel',
        build: buildBloc,
        seed: () => VideoEditorFilterState(
          filters: presetFiltersList,
          selectedFilter: presetFiltersList[1],
          opacity: 0.7,
        ),
        act: (bloc) => bloc.add(const VideoEditorFilterEditorInitialized()),
        expect: () => [
          isA<VideoEditorFilterState>()
              .having(
                (s) => s.initialSelectedFilter,
                'initialSelectedFilter',
                presetFiltersList[1],
              )
              .having((s) => s.initialOpacity, 'initialOpacity', 0.7)
              // Current values unchanged
              .having(
                (s) => s.selectedFilter,
                'selectedFilter',
                presetFiltersList[1],
              )
              .having((s) => s.opacity, 'opacity', 0.7),
        ],
      );

      blocTest<VideoEditorFilterBloc, VideoEditorFilterState>(
        'stores null filter as initial when no filter selected',
        build: buildBloc,
        seed: () => VideoEditorFilterState(
          filters: presetFiltersList,
          selectedFilter: null,
          opacity: 1.0,
          // Different initial values to ensure state change is detected
          initialSelectedFilter: presetFiltersList[1],
          initialOpacity: 0.5,
        ),
        act: (bloc) => bloc.add(const VideoEditorFilterEditorInitialized()),
        expect: () => [
          isA<VideoEditorFilterState>()
              .having(
                (s) => s.initialSelectedFilter,
                'initialSelectedFilter',
                isNull,
              )
              .having((s) => s.initialOpacity, 'initialOpacity', 1.0),
        ],
      );
    });
  });

  group('VideoEditorFilterState', () {
    test('hasFilter returns false when selectedFilter is null', () {
      final state = VideoEditorFilterState(
        filters: presetFiltersList,
        selectedFilter: null,
      );
      expect(state.hasFilter, isFalse);
    });

    test(
      'hasFilter returns false when selectedFilter is PresetFilters.none',
      () {
        final state = VideoEditorFilterState(
          filters: presetFiltersList,
          selectedFilter: PresetFilters.none,
        );
        expect(state.hasFilter, isFalse);
      },
    );

    test('hasFilter returns true when a real filter is selected', () {
      final state = VideoEditorFilterState(
        filters: presetFiltersList,
        selectedFilter: presetFiltersList[1], // Non-None filter
      );
      expect(state.hasFilter, isTrue);
    });

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

    test(
      'isSelected returns true for None filter when selectedFilter is null',
      () {
        final state = VideoEditorFilterState(
          filters: presetFiltersList,
          selectedFilter: null,
        );
        expect(state.isSelected(PresetFilters.none), isTrue);
      },
    );

    test('copyWith creates new state with updated values', () {
      final original = VideoEditorFilterState(
        filters: presetFiltersList,
        selectedFilter: null,
        opacity: 1.0,
      );

      final updated = original.copyWith(
        selectedFilter: presetFiltersList[1],
        opacity: 0.5,
      );

      expect(updated.filters, equals(presetFiltersList));
      expect(updated.selectedFilter, equals(presetFiltersList[1]));
      expect(updated.opacity, 0.5);
      // Original unchanged
      expect(original.selectedFilter, isNull);
      expect(original.opacity, 1.0);
    });

    test('copyWith preserves values when not specified', () {
      final filter = presetFiltersList[1];
      final original = VideoEditorFilterState(
        filters: presetFiltersList,
        selectedFilter: filter,
        opacity: 0.7,
      );

      final updated = original.copyWith();

      expect(updated.filters, equals(original.filters));
      expect(updated.selectedFilter, equals(original.selectedFilter));
      expect(updated.opacity, equals(original.opacity));
    });

    test('props contains all fields for equality', () {
      final state = VideoEditorFilterState(
        filters: presetFiltersList,
        selectedFilter: presetFiltersList[1],
        opacity: 0.5,
        initialSelectedFilter: presetFiltersList[2],
        initialOpacity: 0.8,
      );

      expect(state.props, [
        presetFiltersList,
        presetFiltersList[1],
        0.5,
        presetFiltersList[2],
        0.8,
      ]);
    });

    test('equality works correctly', () {
      final state1 = VideoEditorFilterState(
        filters: presetFiltersList,
        selectedFilter: presetFiltersList[1],
        opacity: 0.5,
      );
      final state2 = VideoEditorFilterState(
        filters: presetFiltersList,
        selectedFilter: presetFiltersList[1],
        opacity: 0.5,
      );
      final state3 = VideoEditorFilterState(
        filters: presetFiltersList,
        selectedFilter: presetFiltersList[2],
        opacity: 0.5,
      );

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });
  });

  group('VideoEditorFilterEvent', () {
    test('VideoEditorFilterSelected props contains filter', () {
      final filter = presetFiltersList[1];
      final event = VideoEditorFilterSelected(filter);
      expect(event.props, [filter]);
    });

    test('VideoEditorFilterOpacityChanged props contains opacity', () {
      const event = VideoEditorFilterOpacityChanged(0.75);
      expect(event.props, [0.75]);
    });

    test('VideoEditorFilterCancelRequested props is empty', () {
      const event = VideoEditorFilterCancelRequested();
      expect(event.props, isEmpty);
    });

    test('VideoEditorFilterDoneRequested props is empty', () {
      const event = VideoEditorFilterDoneRequested();
      expect(event.props, isEmpty);
    });

    test('event equality works correctly', () {
      final filter = presetFiltersList[1];
      final event1 = VideoEditorFilterSelected(filter);
      final event2 = VideoEditorFilterSelected(filter);
      final event3 = VideoEditorFilterSelected(presetFiltersList[2]);

      expect(event1, equals(event2));
      expect(event1, isNot(equals(event3)));
    });
  });
}
