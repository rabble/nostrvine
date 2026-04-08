// ABOUTME: Tests for TimelineOverlayBloc.
// ABOUTME: Covers add, remove, move, trim, select, drag, collapse, and
// ABOUTME: row compaction logic.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/models/timeline_overlay_item.dart';

void main() {
  group(TimelineOverlayBloc, () {
    const layerItem = TimelineOverlayItem(
      id: 'layer-1',
      type: TimelineOverlayType.layer,
      startTime: Duration.zero,
      duration: Duration(seconds: 5),
      label: 'Text',
    );

    const filterItem = TimelineOverlayItem(
      id: 'filter-1',
      type: TimelineOverlayType.filter,
      startTime: Duration(seconds: 2),
      duration: Duration(seconds: 3),
      label: 'Blur',
    );

    const soundItem = TimelineOverlayItem(
      id: 'sound-1',
      type: TimelineOverlayType.sound,
      startTime: Duration(seconds: 1),
      duration: Duration(seconds: 4),
      label: 'Beat',
    );

    group('initial state', () {
      test('has empty items and no selection', () {
        final bloc = TimelineOverlayBloc();
        addTearDown(bloc.close);

        expect(bloc.state, equals(const TimelineOverlayState()));
        expect(bloc.state.items, isEmpty);
        expect(bloc.state.selectedItemId, isNull);
        expect(bloc.state.draggingItemId, isNull);
        expect(bloc.state.collapsedTypes, isEmpty);
      });
    });

    group('$TimelineOverlayItemAdded', () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'emits state with added item',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(const TimelineOverlayItemAdded(layerItem)),
        expect: () => [
          const TimelineOverlayState(items: [layerItem]),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'appends items of different types',
        build: TimelineOverlayBloc.new,
        act: (bloc) {
          bloc
            ..add(const TimelineOverlayItemAdded(layerItem))
            ..add(const TimelineOverlayItemAdded(filterItem))
            ..add(const TimelineOverlayItemAdded(soundItem));
        },
        expect: () => [
          const TimelineOverlayState(items: [layerItem]),
          const TimelineOverlayState(items: [layerItem, filterItem]),
          const TimelineOverlayState(
            items: [layerItem, filterItem, soundItem],
          ),
        ],
      );
    });

    group('$TimelineOverlayItemRemoved', () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'removes item by id',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          items: [layerItem, filterItem],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemRemoved('layer-1'),
        ),
        expect: () => [
          const TimelineOverlayState(items: [filterItem]),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'clears selection when removed item was selected',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          items: [layerItem],
          selectedItemId: 'layer-1',
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemRemoved('layer-1'),
        ),
        expect: () => [
          const TimelineOverlayState(),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'clears dragging when removed item was being dragged',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          items: [layerItem],
          draggingItemId: 'layer-1',
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemRemoved('layer-1'),
        ),
        expect: () => [
          const TimelineOverlayState(),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'compacts rows after removal',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          items: [
            TimelineOverlayItem(
              id: 'l-0',
              type: TimelineOverlayType.layer,
              startTime: Duration.zero,
              duration: Duration(seconds: 3),
              row: 0,
            ),
            TimelineOverlayItem(
              id: 'l-1',
              type: TimelineOverlayType.layer,
              startTime: Duration.zero,
              duration: Duration(seconds: 3),
              row: 1,
            ),
            TimelineOverlayItem(
              id: 'l-2',
              type: TimelineOverlayType.layer,
              startTime: Duration.zero,
              duration: Duration(seconds: 3),
              row: 2,
            ),
          ],
        ),
        act: (bloc) => bloc.add(const TimelineOverlayItemRemoved('l-1')),
        expect: () => [
          const TimelineOverlayState(
            items: [
              TimelineOverlayItem(
                id: 'l-0',
                type: TimelineOverlayType.layer,
                startTime: Duration.zero,
                duration: Duration(seconds: 3),
              ),
              TimelineOverlayItem(
                id: 'l-2',
                type: TimelineOverlayType.layer,
                startTime: Duration.zero,
                duration: Duration(seconds: 3),
                row: 1,
              ),
            ],
          ),
        ],
      );
    });

    group('$TimelineOverlayItemMoved', () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'updates start time',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(items: [layerItem]),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemMoved(
            itemId: 'layer-1',
            startTime: Duration(seconds: 3),
          ),
        ),
        expect: () => [
          TimelineOverlayState(
            items: [layerItem.copyWith(startTime: const Duration(seconds: 3))],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'updates row',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(items: [layerItem]),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemMoved(
            itemId: 'layer-1',
            row: 2,
          ),
        ),
        expect: () => [
          TimelineOverlayState(
            items: [layerItem.copyWith(row: 2)],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'updates both start time and row',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(items: [layerItem]),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemMoved(
            itemId: 'layer-1',
            startTime: Duration(seconds: 1),
            row: 1,
          ),
        ),
        expect: () => [
          TimelineOverlayState(
            items: [
              layerItem.copyWith(
                startTime: const Duration(seconds: 1),
                row: 1,
              ),
            ],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'does not change other items',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          items: [layerItem, filterItem],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemMoved(
            itemId: 'layer-1',
            row: 3,
          ),
        ),
        expect: () => [
          TimelineOverlayState(
            items: [layerItem.copyWith(row: 3), filterItem],
          ),
        ],
      );
    });

    group('$TimelineOverlayItemTrimmed', () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'updates trim start and end',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(items: [layerItem]),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemTrimmed(
            itemId: 'layer-1',
            trimStart: Duration(seconds: 1),
            trimEnd: Duration(seconds: 2),
            isStart: true,
          ),
        ),
        expect: () => [
          TimelineOverlayState(
            items: [
              layerItem.copyWith(
                trimStart: const Duration(seconds: 1),
                trimEnd: const Duration(seconds: 2),
              ),
            ],
          ),
        ],
      );
    });

    group('$TimelineOverlayItemSelected', () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'selects item by id',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(items: [layerItem]),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemSelected('layer-1'),
        ),
        expect: () => [
          const TimelineOverlayState(
            items: [layerItem],
            selectedItemId: 'layer-1',
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'clears selection with null',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          items: [layerItem],
          selectedItemId: 'layer-1',
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemSelected(null),
        ),
        expect: () => [
          const TimelineOverlayState(items: [layerItem]),
        ],
      );
    });

    group('$TimelineOverlayDragStarted', () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'sets dragging item id',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(items: [layerItem]),
        act: (bloc) => bloc.add(
          const TimelineOverlayDragStarted('layer-1'),
        ),
        expect: () => [
          const TimelineOverlayState(
            items: [layerItem],
            draggingItemId: 'layer-1',
          ),
        ],
      );
    });

    group('$TimelineOverlayDragEnded', () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'clears dragging id and compacts rows',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          items: [
            TimelineOverlayItem(
              id: 'l-0',
              type: TimelineOverlayType.layer,
              startTime: Duration.zero,
              duration: Duration(seconds: 3),
            ),
            TimelineOverlayItem(
              id: 'l-2',
              type: TimelineOverlayType.layer,
              startTime: Duration.zero,
              duration: Duration(seconds: 3),
              row: 2,
            ),
          ],
          draggingItemId: 'l-2',
        ),
        act: (bloc) => bloc.add(const TimelineOverlayDragEnded()),
        expect: () => [
          const TimelineOverlayState(
            items: [
              TimelineOverlayItem(
                id: 'l-0',
                type: TimelineOverlayType.layer,
                startTime: Duration.zero,
                duration: Duration(seconds: 3),
              ),
              TimelineOverlayItem(
                id: 'l-2',
                type: TimelineOverlayType.layer,
                startTime: Duration.zero,
                duration: Duration(seconds: 3),
                row: 1,
              ),
            ],
          ),
        ],
      );
    });

    group('$TimelineOverlayCollapseToggled', () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'adds type to collapsed set',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          const TimelineOverlayCollapseToggled(TimelineOverlayType.layer),
        ),
        expect: () => [
          const TimelineOverlayState(
            collapsedTypes: {TimelineOverlayType.layer},
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'removes type from collapsed set when toggled again',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          collapsedTypes: {TimelineOverlayType.layer},
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayCollapseToggled(TimelineOverlayType.layer),
        ),
        expect: () => [
          const TimelineOverlayState(),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'supports multiple collapsed types',
        build: TimelineOverlayBloc.new,
        act: (bloc) {
          bloc
            ..add(
              const TimelineOverlayCollapseToggled(TimelineOverlayType.layer),
            )
            ..add(
              const TimelineOverlayCollapseToggled(TimelineOverlayType.sound),
            );
        },
        expect: () => [
          const TimelineOverlayState(
            collapsedTypes: {TimelineOverlayType.layer},
          ),
          const TimelineOverlayState(
            collapsedTypes: {
              TimelineOverlayType.layer,
              TimelineOverlayType.sound,
            },
          ),
        ],
      );
    });
  });

  group(TimelineOverlayState, () {
    const items = [
      TimelineOverlayItem(
        id: 'l-0',
        type: TimelineOverlayType.layer,
        startTime: Duration(seconds: 5),
        duration: Duration(seconds: 3),
      ),
      TimelineOverlayItem(
        id: 'l-1',
        type: TimelineOverlayType.layer,
        startTime: Duration(seconds: 1),
        duration: Duration(seconds: 2),
        row: 1,
      ),
      TimelineOverlayItem(
        id: 'f-0',
        type: TimelineOverlayType.filter,
        startTime: Duration.zero,
        duration: Duration(seconds: 4),
      ),
    ];

    group('hasItemsOfType', () {
      test('returns true when items of type exist', () {
        const state = TimelineOverlayState(items: items);
        expect(state.hasItemsOfType(TimelineOverlayType.layer), isTrue);
        expect(state.hasItemsOfType(TimelineOverlayType.filter), isTrue);
      });

      test('returns false when no items of type exist', () {
        const state = TimelineOverlayState(items: items);
        expect(state.hasItemsOfType(TimelineOverlayType.sound), isFalse);
      });
    });

    group('itemsOfType', () {
      test('returns items sorted by row then start time', () {
        const state = TimelineOverlayState(items: items);
        final layers = state.itemsOfType(TimelineOverlayType.layer);
        expect(layers, hasLength(2));
        expect(layers.first.id, equals('l-0'));
        expect(layers.last.id, equals('l-1'));
      });

      test('returns empty list for missing type', () {
        const state = TimelineOverlayState(items: items);
        expect(
          state.itemsOfType(TimelineOverlayType.sound),
          isEmpty,
        );
      });
    });

    group('rowCountForType', () {
      test('returns correct row count', () {
        const state = TimelineOverlayState(items: items);
        expect(state.rowCountForType(TimelineOverlayType.layer), equals(2));
        expect(state.rowCountForType(TimelineOverlayType.filter), equals(1));
      });

      test('returns 0 for missing type', () {
        const state = TimelineOverlayState(items: items);
        expect(state.rowCountForType(TimelineOverlayType.sound), equals(0));
      });
    });

    group('isTypeCollapsed', () {
      test('returns true when type is in collapsed set', () {
        const state = TimelineOverlayState(
          collapsedTypes: {TimelineOverlayType.layer},
        );
        expect(
          state.isTypeCollapsed(TimelineOverlayType.layer),
          isTrue,
        );
      });

      test('returns false when type is not in collapsed set', () {
        const state = TimelineOverlayState();
        expect(
          state.isTypeCollapsed(TimelineOverlayType.layer),
          isFalse,
        );
      });
    });
  });

  group(TimelineOverlayItem, () {
    group('trimmedDuration', () {
      test('returns duration minus trim', () {
        const item = TimelineOverlayItem(
          id: 'test',
          type: TimelineOverlayType.layer,
          startTime: Duration.zero,
          duration: Duration(seconds: 10),
          trimStart: Duration(seconds: 2),
          trimEnd: Duration(seconds: 3),
        );
        expect(
          item.trimmedDuration,
          equals(const Duration(seconds: 5)),
        );
      });

      test('clamps to zero when over-trimmed', () {
        const item = TimelineOverlayItem(
          id: 'test',
          type: TimelineOverlayType.layer,
          startTime: Duration.zero,
          duration: Duration(seconds: 3),
          trimStart: Duration(seconds: 2),
          trimEnd: Duration(seconds: 2),
        );
        expect(item.trimmedDuration, equals(Duration.zero));
      });
    });

    group('endTime', () {
      test('returns startTime + trimmedDuration', () {
        const item = TimelineOverlayItem(
          id: 'test',
          type: TimelineOverlayType.layer,
          startTime: Duration(seconds: 5),
          duration: Duration(seconds: 10),
          trimStart: Duration(seconds: 1),
          trimEnd: Duration(seconds: 2),
        );
        expect(
          item.endTime,
          equals(const Duration(seconds: 12)),
        );
      });
    });

    group('copyWith', () {
      test('copies with new values', () {
        const item = TimelineOverlayItem(
          id: 'test',
          type: TimelineOverlayType.layer,
          startTime: Duration.zero,
          duration: Duration(seconds: 5),
        );

        final copied = item.copyWith(
          startTime: const Duration(seconds: 2),
          row: 3,
          label: 'Updated',
        );

        expect(copied.id, equals('test'));
        expect(copied.type, equals(TimelineOverlayType.layer));
        expect(copied.startTime, equals(const Duration(seconds: 2)));
        expect(copied.duration, equals(const Duration(seconds: 5)));
        expect(copied.row, equals(3));
        expect(copied.label, equals('Updated'));
      });
    });
  });
}
