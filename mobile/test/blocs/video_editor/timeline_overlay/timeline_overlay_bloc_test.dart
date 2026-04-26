// ABOUTME: Tests for TimelineOverlayBloc.
// ABOUTME: Covers update, move, trim, select, drag, trim, collapse,
// ABOUTME: and state helpers for the current event/state API.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

TimelineOverlayItem _item({
  required String id,
  required TimelineOverlayType type,
  required Duration start,
  required Duration end,
  int row = 0,
  String label = '',
}) {
  return TimelineOverlayItem(
    id: id,
    type: type,
    startTime: start,
    endTime: end,
    row: row,
    label: label,
  );
}

AudioEvent _audioEvent({
  required String id,
  required Duration start,
  required Duration end,
  String title = 'Sound',
}) {
  return AudioEvent(
    id: id,
    pubkey: 'pubkey-$id',
    createdAt: 1704067200,
    title: title,
    startTime: start,
    endTime: end,
  );
}

void main() {
  group(TimelineOverlayBloc, () {
    test('initial state is empty', () {
      final bloc = TimelineOverlayBloc();
      addTearDown(bloc.close);

      expect(bloc.state, equals(const TimelineOverlayState()));
      expect(bloc.state.items, isEmpty);
      expect(bloc.state.selectedItemId, isNull);
      expect(bloc.state.draggingItemId, isNull);
      expect(bloc.state.trimmingItemId, isNull);
      expect(bloc.state.collapsedTypes, isEmpty);
    });

    group(TimelineOverlayItemsUpdate, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'maps audio tracks into sound overlay items',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            audioTracks: [
              _audioEvent(
                id: 'sound-1',
                start: const Duration(seconds: 1),
                end: const Duration(seconds: 4),
                title: 'Beat',
              ),
            ],
            totalVideoDuration: const Duration(seconds: 12),
          ),
        ),
        expect: () => [
          TimelineOverlayState(
            items: const [
              TimelineOverlayItem(
                id: 'sound-1',
                type: TimelineOverlayType.sound,
                startTime: Duration(seconds: 1),
                endTime: Duration(seconds: 4),
                label: 'Beat',
                maxDuration: VideoEditorConstants.maxDuration,
              ),
            ],
            audioTracks: [
              _audioEvent(
                id: 'sound-1',
                start: const Duration(seconds: 1),
                end: const Duration(seconds: 4),
                title: 'Beat',
              ),
            ],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'clears selection when not trimming',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(selectedItemId: 'sound-1'),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemsUpdate(
            layers: <Layer>[],
            filters: <FilterState>[],
            audioTracks: [],
            totalVideoDuration: Duration(seconds: 8),
          ),
        ),
        expect: () => [const TimelineOverlayState()],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'emits no change while trim gesture keeps current selection',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          selectedItemId: 'sound-1',
          trimmingItemId: 'sound-1',
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemsUpdate(
            layers: <Layer>[],
            filters: <FilterState>[],
            audioTracks: [],
            totalVideoDuration: Duration(seconds: 8),
          ),
        ),
        expect: () => const [TimelineOverlayState(trimmingItemId: 'sound-1')],
      );
    });

    group(TimelineOverlayItemMoved, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'shifts startTime and endTime by same delta',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'layer-1',
              type: TimelineOverlayType.layer,
              start: const Duration(seconds: 1),
              end: const Duration(seconds: 5),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemMoved(
            itemId: 'layer-1',
            startTime: Duration(seconds: 3),
          ),
        ),
        expect: () => [
          TimelineOverlayState(
            items: [
              _item(
                id: 'layer-1',
                type: TimelineOverlayType.layer,
                start: const Duration(seconds: 3),
                end: const Duration(seconds: 7),
              ),
            ],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'does not emit when item id does not exist',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'layer-1',
              type: TimelineOverlayType.layer,
              start: Duration.zero,
              end: const Duration(seconds: 2),
            ),
          ],
        ),
        act: (bloc) =>
            bloc.add(const TimelineOverlayItemMoved(itemId: 'missing')),
        expect: () => <TimelineOverlayState>[],
      );
    });

    group(TimelineOverlayItemTrimmed, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'updates start/end and reassigns rows for changed type',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'a',
              type: TimelineOverlayType.layer,
              start: Duration.zero,
              end: const Duration(seconds: 2),
            ),
            _item(
              id: 'b',
              type: TimelineOverlayType.layer,
              start: const Duration(seconds: 3),
              end: const Duration(seconds: 5),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemTrimmed(
            itemId: 'a',
            isStart: false,
            startTime: Duration.zero,
            endTime: Duration(seconds: 4),
          ),
        ),
        expect: () => [
          TimelineOverlayState(
            items: [
              _item(
                id: 'a',
                type: TimelineOverlayType.layer,
                start: Duration.zero,
                end: const Duration(seconds: 4),
              ),
              _item(
                id: 'b',
                type: TimelineOverlayType.layer,
                start: const Duration(seconds: 3),
                end: const Duration(seconds: 5),
                row: 1,
              ),
            ],
            trimPosition: const Duration(seconds: 4),
          ),
        ],
      );
    });

    group('selection and gestures', () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'select and clear selected item',
        build: TimelineOverlayBloc.new,
        act: (bloc) {
          bloc
            ..add(const TimelineOverlayItemSelected('x'))
            ..add(const TimelineOverlayItemSelected(null));
        },
        expect: () => [
          const TimelineOverlayState(selectedItemId: 'x'),
          const TimelineOverlayState(),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'start and end drag compacts rows and clears dragging id',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'l-0',
              type: TimelineOverlayType.layer,
              start: Duration.zero,
              end: const Duration(seconds: 3),
            ),
            _item(
              id: 'l-2',
              type: TimelineOverlayType.layer,
              start: Duration.zero,
              end: const Duration(seconds: 3),
              row: 2,
            ),
          ],
        ),
        act: (bloc) {
          bloc
            ..add(const TimelineOverlayDragStarted('l-2'))
            ..add(const TimelineOverlayDragEnded());
        },
        expect: () => [
          TimelineOverlayState(
            items: [
              _item(
                id: 'l-0',
                type: TimelineOverlayType.layer,
                start: Duration.zero,
                end: const Duration(seconds: 3),
              ),
              _item(
                id: 'l-2',
                type: TimelineOverlayType.layer,
                start: Duration.zero,
                end: const Duration(seconds: 3),
                row: 2,
              ),
            ],
            draggingItemId: 'l-2',
          ),
          TimelineOverlayState(
            items: [
              _item(
                id: 'l-0',
                type: TimelineOverlayType.layer,
                start: Duration.zero,
                end: const Duration(seconds: 3),
              ),
              _item(
                id: 'l-2',
                type: TimelineOverlayType.layer,
                start: Duration.zero,
                end: const Duration(seconds: 3),
                row: 1,
              ),
            ],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'start and end trim clears trimming id',
        build: TimelineOverlayBloc.new,
        act: (bloc) {
          bloc
            ..add(const TimelineOverlayTrimStarted('x'))
            ..add(const TimelineOverlayTrimEnded());
        },
        expect: () => [
          const TimelineOverlayState(trimmingItemId: 'x'),
          const TimelineOverlayState(),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'TimelineOverlayDragMoved sets dragPosition while dragging',
        build: TimelineOverlayBloc.new,
        act: (bloc) {
          bloc
            ..add(const TimelineOverlayDragStarted('x'))
            ..add(
              const TimelineOverlayDragMoved(Duration(milliseconds: 750)),
            );
        },
        expect: () => [
          const TimelineOverlayState(draggingItemId: 'x'),
          const TimelineOverlayState(
            draggingItemId: 'x',
            dragPosition: Duration(milliseconds: 750),
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'TimelineOverlayDragMoved is ignored when no drag is active',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          const TimelineOverlayDragMoved(Duration(milliseconds: 500)),
        ),
        expect: () => <TimelineOverlayState>[],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'TimelineOverlayDragEnded clears dragPosition',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          draggingItemId: 'x',
          dragPosition: Duration(milliseconds: 500),
        ),
        act: (bloc) => bloc.add(const TimelineOverlayDragEnded()),
        expect: () => [
          isA<TimelineOverlayState>()
              .having((s) => s.draggingItemId, 'draggingItemId', isNull)
              .having((s) => s.dragPosition, 'dragPosition', isNull),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'TimelineOverlayItemTrimmed exposes trimPosition for the dragged handle',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'a',
              type: TimelineOverlayType.layer,
              start: Duration.zero,
              end: const Duration(seconds: 2),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemTrimmed(
            itemId: 'a',
            isStart: false,
            endTime: Duration(seconds: 4),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>().having(
            (s) => s.trimPosition,
            'trimPosition',
            const Duration(seconds: 4),
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'TimelineOverlayTrimEnded clears trimPosition',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          trimmingItemId: 'x',
          trimPosition: Duration(seconds: 1),
        ),
        act: (bloc) => bloc.add(const TimelineOverlayTrimEnded()),
        expect: () => [
          isA<TimelineOverlayState>()
              .having((s) => s.trimmingItemId, 'trimmingItemId', isNull)
              .having((s) => s.trimPosition, 'trimPosition', isNull),
        ],
      );
    });

    group(TimelineOverlayCollapseToggled, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'toggles collapsed type on and off',
        build: TimelineOverlayBloc.new,
        act: (bloc) {
          bloc
            ..add(
              const TimelineOverlayCollapseToggled(TimelineOverlayType.layer),
            )
            ..add(
              const TimelineOverlayCollapseToggled(TimelineOverlayType.layer),
            );
        },
        expect: () => [
          const TimelineOverlayState(
            collapsedTypes: {TimelineOverlayType.layer},
          ),
          const TimelineOverlayState(),
        ],
      );
    });

    group(TimelineOverlayTotalDurationChanged, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'clamps item end time to the provided total duration',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'layer-1',
              type: TimelineOverlayType.layer,
              start: const Duration(seconds: 2),
              end: const Duration(seconds: 10),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayTotalDurationChanged(Duration(seconds: 5)),
        ),
        expect: () => [
          TimelineOverlayState(
            items: [
              _item(
                id: 'layer-1',
                type: TimelineOverlayType.layer,
                start: const Duration(seconds: 2),
                end: const Duration(seconds: 5),
              ),
            ],
          ),
        ],
      );
    });
  });

  group(TimelineOverlayState, () {
    test('copyWith clear flags reset selected/dragging/trimming ids', () {
      const state = TimelineOverlayState(
        selectedItemId: 'selected',
        draggingItemId: 'dragging',
        trimmingItemId: 'trimming',
      );

      final cleared = state.copyWith(
        clearSelectedItemId: true,
        clearDraggingItemId: true,
        clearTrimmingItemId: true,
      );

      expect(cleared.selectedItemId, isNull);
      expect(cleared.draggingItemId, isNull);
      expect(cleared.trimmingItemId, isNull);
    });

    test('copyWith clear flags reset dragPosition and trimPosition', () {
      const state = TimelineOverlayState(
        dragPosition: Duration(milliseconds: 500),
        trimPosition: Duration(seconds: 2),
      );

      final cleared = state.copyWith(
        clearDragPosition: true,
        clearTrimPosition: true,
      );

      expect(cleared.dragPosition, isNull);
      expect(cleared.trimPosition, isNull);
    });
  });

  group(TimelineOverlayItem, () {
    test('duration getter equals endTime - startTime', () {
      const item = TimelineOverlayItem(
        id: 'x',
        type: TimelineOverlayType.layer,
        startTime: Duration(seconds: 2),
        endTime: Duration(seconds: 7),
      );

      expect(item.duration, equals(const Duration(seconds: 5)));
      expect(item.durationInSeconds, equals(5));
      expect(item.startTimeInSeconds, equals(2));
    });
  });
}
