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

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'assigns new row when overlapping same-type item',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          items: [layerItem], // row 0, 0–5s
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemAdded(
            TimelineOverlayItem(
              id: 'layer-2',
              type: TimelineOverlayType.layer,
              startTime: Duration(seconds: 2),
              duration: Duration(seconds: 3),
              label: 'Overlap',
            ),
          ),
        ),
        expect: () => [
          const TimelineOverlayState(
            items: [
              layerItem,
              TimelineOverlayItem(
                id: 'layer-2',
                type: TimelineOverlayType.layer,
                startTime: Duration(seconds: 2),
                duration: Duration(seconds: 3),
                row: 1, // pushed to row 1
                label: 'Overlap',
              ),
            ],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'keeps row 0 when no overlap with same-type items',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          items: [layerItem], // row 0, 0–5s
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemAdded(
            TimelineOverlayItem(
              id: 'layer-2',
              type: TimelineOverlayType.layer,
              startTime: Duration(seconds: 6),
              duration: Duration(seconds: 2),
              label: 'NoOverlap',
            ),
          ),
        ),
        expect: () => [
          const TimelineOverlayState(
            items: [
              layerItem,
              TimelineOverlayItem(
                id: 'layer-2',
                type: TimelineOverlayType.layer,
                startTime: Duration(seconds: 6),
                duration: Duration(seconds: 2),
                label: 'NoOverlap',
              ),
            ],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'shifts existing items down when inserting overlapping item',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          items: [
            // Row 0: 0–5s
            layerItem,
            // Row 1: 0–3s
            TimelineOverlayItem(
              id: 'layer-existing',
              type: TimelineOverlayType.layer,
              startTime: Duration.zero,
              duration: Duration(seconds: 3),
              row: 1,
              label: 'Existing',
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemAdded(
            TimelineOverlayItem(
              id: 'layer-new',
              type: TimelineOverlayType.layer,
              startTime: Duration(seconds: 1),
              duration: Duration(seconds: 2),
              label: 'New',
            ),
          ),
        ),
        expect: () => [
          const TimelineOverlayState(
            items: [
              layerItem, // stays at row 0
              // Was row 1, shifted to row 2
              TimelineOverlayItem(
                id: 'layer-existing',
                type: TimelineOverlayType.layer,
                startTime: Duration.zero,
                duration: Duration(seconds: 3),
                row: 2,
                label: 'Existing',
              ),
              // Inserted at row 1
              TimelineOverlayItem(
                id: 'layer-new',
                type: TimelineOverlayType.layer,
                startTime: Duration(seconds: 1),
                duration: Duration(seconds: 2),
                row: 1,
                label: 'New',
              ),
            ],
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

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'resolves overlap when moved to occupied row',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          items: [
            TimelineOverlayItem(
              id: 'l-0',
              type: TimelineOverlayType.layer,
              startTime: Duration.zero,
              duration: Duration(seconds: 5),
            ),
            TimelineOverlayItem(
              id: 'l-1',
              type: TimelineOverlayType.layer,
              startTime: Duration(seconds: 6),
              duration: Duration(seconds: 3),
              row: 1,
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemMoved(
            itemId: 'l-1',
            startTime: Duration(seconds: 2), // now overlaps with l-0
            row: 0,
          ),
        ),
        expect: () => [
          const TimelineOverlayState(
            items: [
              TimelineOverlayItem(
                id: 'l-0',
                type: TimelineOverlayType.layer,
                startTime: Duration.zero,
                duration: Duration(seconds: 5),
              ),
              TimelineOverlayItem(
                id: 'l-1',
                type: TimelineOverlayType.layer,
                startTime: Duration(seconds: 2),
                duration: Duration(seconds: 3),
                row: 1, // pushed back to row 1
              ),
            ],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'insertAbove keeps moved item at target row and shifts others',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          items: [
            TimelineOverlayItem(
              id: 'l-0',
              type: TimelineOverlayType.layer,
              startTime: Duration.zero,
              duration: Duration(seconds: 5),
            ),
            TimelineOverlayItem(
              id: 'l-1',
              type: TimelineOverlayType.layer,
              startTime: Duration(seconds: 6),
              duration: Duration(seconds: 3),
              row: 1,
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemMoved(
            itemId: 'l-1',
            startTime: Duration(seconds: 2), // overlaps with l-0
            row: 0,
            insertAbove: true,
          ),
        ),
        expect: () => [
          const TimelineOverlayState(
            items: [
              TimelineOverlayItem(
                id: 'l-0',
                type: TimelineOverlayType.layer,
                startTime: Duration.zero,
                duration: Duration(seconds: 5),
                row: 1, // shifted down
              ),
              TimelineOverlayItem(
                id: 'l-1',
                type: TimelineOverlayType.layer,
                startTime: Duration(seconds: 2),
                duration: Duration(seconds: 3),
                row: 0, // stays at target row
              ),
            ],
          ),
        ],
      );
    });

    group('$TimelineOverlayItemTrimmed', () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'updates trim start, end, and shifts startTime when isStart',
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
                startTime: const Duration(seconds: 1),
                trimStart: const Duration(seconds: 1),
                trimEnd: const Duration(seconds: 2),
              ),
            ],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'updates trim end without shifting startTime when not isStart',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(items: [layerItem]),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemTrimmed(
            itemId: 'layer-1',
            trimStart: Duration.zero,
            trimEnd: Duration(seconds: 2),
            isStart: false,
          ),
        ),
        expect: () => [
          TimelineOverlayState(
            items: [
              layerItem.copyWith(
                trimEnd: const Duration(seconds: 2),
              ),
            ],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'extends left with explicit startTime and duration',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            layerItem.copyWith(
              startTime: const Duration(seconds: 2),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemTrimmed(
            itemId: 'layer-1',
            trimStart: Duration.zero,
            trimEnd: Duration.zero,
            isStart: true,
            startTime: Duration(seconds: 1),
            duration: Duration(seconds: 6),
          ),
        ),
        expect: () => [
          TimelineOverlayState(
            items: [
              layerItem.copyWith(
                startTime: const Duration(seconds: 1),
                duration: const Duration(seconds: 6),
              ),
            ],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'extends right with explicit duration',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(items: [layerItem]),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemTrimmed(
            itemId: 'layer-1',
            trimStart: Duration.zero,
            trimEnd: Duration.zero,
            isStart: false,
            duration: Duration(seconds: 8),
          ),
        ),
        expect: () => [
          TimelineOverlayState(
            items: [
              layerItem.copyWith(
                duration: const Duration(seconds: 8),
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

    group('$TimelineOverlayTotalDurationChanged', () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'clamps items that extend past new total duration',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            layerItem.copyWith(
              startTime: const Duration(seconds: 2),
              duration: const Duration(seconds: 10),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayTotalDurationChanged(Duration(seconds: 8)),
        ),
        expect: () => [
          TimelineOverlayState(
            items: [
              layerItem.copyWith(
                startTime: const Duration(seconds: 2),
                duration: const Duration(seconds: 6),
              ),
            ],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'removes items with zero visible duration after clamp',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            layerItem.copyWith(
              startTime: const Duration(seconds: 9),
              duration: const Duration(seconds: 5),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayTotalDurationChanged(Duration(seconds: 8)),
        ),
        expect: () => [
          const TimelineOverlayState(),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'does not emit when items already within bounds',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(items: [layerItem]),
        act: (bloc) => bloc.add(
          const TimelineOverlayTotalDurationChanged(Duration(seconds: 10)),
        ),
        expect: () => <TimelineOverlayState>[],
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
