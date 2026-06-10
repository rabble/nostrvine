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
  String? anchorClipId,
}) {
  return AudioEvent(
    id: id,
    pubkey: 'pubkey-$id',
    createdAt: 1704067200,
    title: title,
    startTime: start,
    endTime: end,
    anchorClipId: anchorClipId,
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
      expect(bloc.state.timelineMarkers, isEmpty);
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
                audioSource: AudioSource.custom,
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
        'maxDuration equals track duration when longer than VideoEditorConstants.maxDuration',
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
              ).copyWith(
                duration: 10.0,
              ), // 10s > VideoEditorConstants.maxDuration (6.3s)
            ],
            totalVideoDuration: const Duration(seconds: 12),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>().having(
            (s) => s.items.first.maxDuration,
            'maxDuration',
            const Duration(seconds: 10),
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'maxDuration subtracts startOffset from track duration',
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
              ).copyWith(
                duration: 8.0,
                startOffset: const Duration(seconds: 2),
              ),
            ],
            totalVideoDuration: const Duration(seconds: 12),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>().having(
            (s) => s.items.first.maxDuration,
            'maxDuration',
            const Duration(seconds: 6), // 8000ms - 2000ms
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

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'bumps player revision for undo-restored volume without history revision',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          audioTracks: [
            _audioEvent(
              id: 'sound-1',
              start: const Duration(seconds: 1),
              end: const Duration(seconds: 4),
            ).copyWith(volume: 0.25),
          ],
        ),
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            audioTracks: [
              _audioEvent(
                id: 'sound-1',
                start: const Duration(seconds: 1),
                end: const Duration(seconds: 4),
              ),
            ],
            totalVideoDuration: const Duration(seconds: 12),
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>()
              .having(
                (s) => s.audioTracksPlayerRevision,
                'audioTracksPlayerRevision',
                1,
              )
              .having((s) => s.audioTracksRevision, 'audioTracksRevision', 0)
              .having((s) => s.audioTracks.first.volume, 'volume', 1.0),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'emits when only an audio anchor is cleared',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: const [
            TimelineOverlayItem(
              id: 'sound-1',
              type: TimelineOverlayType.sound,
              startTime: Duration(seconds: 1),
              endTime: Duration(seconds: 4),
              label: 'Sound',
              maxDuration: VideoEditorConstants.maxDuration,
              audioSource: AudioSource.custom,
            ),
          ],
          audioTracks: [
            _audioEvent(
              id: 'sound-1',
              start: const Duration(seconds: 1),
              end: const Duration(seconds: 4),
              anchorClipId: 'clip-1',
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          TimelineOverlayItemsUpdate(
            layers: const <Layer>[],
            filters: const <FilterState>[],
            audioTracks: [
              _audioEvent(
                id: 'sound-1',
                start: const Duration(seconds: 1),
                end: const Duration(seconds: 4),
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
                label: 'Sound',
                maxDuration: VideoEditorConstants.maxDuration,
                audioSource: AudioSource.custom,
              ),
            ],
            audioTracks: [
              _audioEvent(
                id: 'sound-1',
                start: const Duration(seconds: 1),
                end: const Duration(seconds: 4),
              ),
            ],
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'restores markers without bumping marker history revision',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          timelineMarkers: [Duration(seconds: 1)],
          timelineMarkersRevision: 2,
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayItemsUpdate(
            layers: <Layer>[],
            filters: <FilterState>[],
            audioTracks: [],
            totalVideoDuration: Duration(seconds: 8),
            timelineMarkers: [Duration(seconds: 2)],
          ),
        ),
        expect: () => const [
          TimelineOverlayState(
            timelineMarkers: [Duration(seconds: 2)],
            timelineMarkersRevision: 2,
          ),
        ],
      );
    });

    group(TimelineOverlayAudioVolumeChanged, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'clamps volume and bumps history revision',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          audioTracks: [
            _audioEvent(
              id: 'sound-1',
              start: const Duration(seconds: 1),
              end: const Duration(seconds: 4),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayAudioVolumeChanged(
            trackId: 'sound-1',
            volume: -1.0,
          ),
        ),
        expect: () => [
          isA<TimelineOverlayState>()
              .having((s) => s.audioTracks.first.volume, 'volume', 0.0)
              .having((s) => s.audioTracksRevision, 'audioTracksRevision', 1)
              .having(
                (s) => s.audioTracksPlayerRevision,
                'audioTracksPlayerRevision',
                0,
              ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'is no-op for unknown track id',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          audioTracks: [
            _audioEvent(
              id: 'sound-1',
              start: const Duration(seconds: 1),
              end: const Duration(seconds: 4),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayAudioVolumeChanged(
            trackId: 'missing',
            volume: 0.5,
          ),
        ),
        expect: () => <TimelineOverlayState>[],
      );
    });

    group(TimelineOverlayAllAudioVolumeChanged, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'clamps below 0 to 0 on every custom track and bumps history revision',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          audioTracks: [
            _audioEvent(
              id: 'sound-1',
              start: const Duration(seconds: 1),
              end: const Duration(seconds: 4),
            ),
            _audioEvent(
              id: 'sound-2',
              start: const Duration(seconds: 5),
              end: const Duration(seconds: 8),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayAllAudioVolumeChanged(volume: -1.0),
        ),
        expect: () => [
          isA<TimelineOverlayState>()
              .having(
                (s) => s.audioTracks.map((t) => t.volume).toList(),
                'audio volumes',
                [0.0, 0.0],
              )
              .having((s) => s.audioTracksRevision, 'audioTracksRevision', 1)
              .having(
                (s) => s.audioTracksPlayerRevision,
                'audioTracksPlayerRevision',
                0,
              ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'preserves original-sound tracks (id starts with `video_`) and '
        'only mutes custom tracks',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          audioTracks: [
            _audioEvent(
              id: 'video_clip-a',
              start: Duration.zero,
              end: const Duration(seconds: 3),
            ),
            _audioEvent(
              id: 'sound-1',
              start: const Duration(seconds: 1),
              end: const Duration(seconds: 4),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayAllAudioVolumeChanged(volume: 0.0),
        ),
        expect: () => [
          isA<TimelineOverlayState>()
              .having(
                (s) => s.audioTracks
                    .firstWhere((t) => t.id == 'video_clip-a')
                    .volume,
                'original-sound volume',
                1.0,
              )
              .having(
                (s) =>
                    s.audioTracks.firstWhere((t) => t.id == 'sound-1').volume,
                'custom track volume',
                0.0,
              ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'is no-op when there are no audio tracks',
        build: TimelineOverlayBloc.new,
        seed: TimelineOverlayState.new,
        act: (bloc) => bloc.add(
          const TimelineOverlayAllAudioVolumeChanged(volume: 0.0),
        ),
        expect: () => <TimelineOverlayState>[],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'is no-op when only original-sound tracks are present',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          audioTracks: [
            _audioEvent(
              id: 'video_clip-a',
              start: Duration.zero,
              end: const Duration(seconds: 3),
            ),
            _audioEvent(
              id: 'video_clip-b',
              start: const Duration(seconds: 3),
              end: const Duration(seconds: 6),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayAllAudioVolumeChanged(volume: 0.0),
        ),
        expect: () => <TimelineOverlayState>[],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'is no-op when every custom track is already at the clamped '
        'target volume',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          audioTracks: [
            _audioEvent(
              id: 'sound-1',
              start: const Duration(seconds: 1),
              end: const Duration(seconds: 4),
            ),
            _audioEvent(
              id: 'sound-2',
              start: const Duration(seconds: 5),
              end: const Duration(seconds: 8),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayAllAudioVolumeChanged(volume: 2.0),
        ),
        expect: () => <TimelineOverlayState>[],
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

    group(TimelineOverlayAnchoredAudioRebased, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'moves matching sound items to follow the rebased tracks, leaving '
        'other items untouched',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'b-audio',
              type: TimelineOverlayType.sound,
              start: const Duration(seconds: 10),
              end: const Duration(seconds: 20),
            ),
            _item(
              id: 'overlay',
              type: TimelineOverlayType.layer,
              start: const Duration(seconds: 1),
              end: const Duration(seconds: 5),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          TimelineOverlayAnchoredAudioRebased([
            _audioEvent(
              id: 'b-audio',
              start: const Duration(seconds: 7),
              end: const Duration(seconds: 17),
            ),
          ]),
        ),
        verify: (bloc) {
          final sound = bloc.state.items.firstWhere((i) => i.id == 'b-audio');
          expect(sound.startTime, const Duration(seconds: 7));
          expect(sound.endTime, const Duration(seconds: 17));
          final layer = bloc.state.items.firstWhere((i) => i.id == 'overlay');
          expect(layer.startTime, const Duration(seconds: 1));
          expect(layer.endTime, const Duration(seconds: 5));
        },
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'does not change source audioTracks (visual-only live update)',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'b-audio',
              type: TimelineOverlayType.sound,
              start: const Duration(seconds: 10),
              end: const Duration(seconds: 20),
            ),
          ],
          audioTracks: [
            _audioEvent(
              id: 'b-audio',
              start: const Duration(seconds: 10),
              end: const Duration(seconds: 20),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          TimelineOverlayAnchoredAudioRebased([
            _audioEvent(
              id: 'b-audio',
              start: const Duration(seconds: 7),
              end: const Duration(seconds: 17),
            ),
          ]),
        ),
        verify: (bloc) {
          // The persisted source track keeps its old position — only the
          // visual item moved. The native player / history reconcile on
          // release, not during the live drag.
          expect(
            bloc.state.audioTracks.single.startTime,
            const Duration(seconds: 10),
          );
        },
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'emits nothing when the rebased positions already match',
        build: TimelineOverlayBloc.new,
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'b-audio',
              type: TimelineOverlayType.sound,
              start: const Duration(seconds: 10),
              end: const Duration(seconds: 20),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          TimelineOverlayAnchoredAudioRebased([
            _audioEvent(
              id: 'b-audio',
              start: const Duration(seconds: 10),
              end: const Duration(seconds: 20),
            ),
          ]),
        ),
        expect: () => const <TimelineOverlayState>[],
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

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'keeps a sound item that ends before the total (L-Cut overhang '
        'survives the shrink)',
        build: TimelineOverlayBloc.new,
        // Anchored audio ending at 20 s stays put after a clip right-trim
        // shrinks the total to 27 s — its tail must keep overhanging into
        // the next clip rather than being clamped away or removed. A trailing
        // layer that does exceed the total forces an emission so the handler
        // definitely runs.
        seed: () => TimelineOverlayState(
          items: [
            _item(
              id: 'b-audio',
              type: TimelineOverlayType.sound,
              start: const Duration(seconds: 10),
              end: const Duration(seconds: 20),
            ),
            _item(
              id: 'tail-layer',
              type: TimelineOverlayType.layer,
              start: const Duration(seconds: 25),
              end: const Duration(seconds: 30),
            ),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayTotalDurationChanged(Duration(seconds: 27)),
        ),
        verify: (bloc) {
          final sound = bloc.state.items.firstWhere((i) => i.id == 'b-audio');
          expect(sound.startTime, const Duration(seconds: 10));
          expect(sound.endTime, const Duration(seconds: 20));
          final layer = bloc.state.items.firstWhere(
            (i) => i.id == 'tail-layer',
          );
          expect(layer.endTime, const Duration(seconds: 27));
        },
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'clamps markers to the provided total duration',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          timelineMarkers: [
            Duration(seconds: 2),
            Duration(seconds: 8),
          ],
        ),
        act: (bloc) => bloc.add(
          const TimelineOverlayTotalDurationChanged(Duration(seconds: 5)),
        ),
        expect: () => const [
          TimelineOverlayState(
            timelineMarkers: [Duration(seconds: 2), Duration(seconds: 5)],
          ),
        ],
      );
    });

    group(TimelineMarkerAdded, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'adds a marker at the playhead position',
        build: TimelineOverlayBloc.new,
        act: (bloc) => bloc.add(
          const TimelineMarkerAdded(
            position: Duration(milliseconds: 1200),
            totalDuration: Duration(seconds: 5),
          ),
        ),
        expect: () => const [
          TimelineOverlayState(
            timelineMarkers: [Duration(milliseconds: 1200)],
            timelineMarkersRevision: 1,
          ),
        ],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'does not remove an existing marker near the playhead position',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          timelineMarkers: [Duration(milliseconds: 1200)],
        ),
        act: (bloc) => bloc.add(
          const TimelineMarkerAdded(
            position: Duration(milliseconds: 1230),
            totalDuration: Duration(seconds: 5),
          ),
        ),
        expect: () => <TimelineOverlayState>[],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'sorts markers and clamps new marker to total duration',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          timelineMarkers: [Duration(seconds: 2)],
        ),
        act: (bloc) => bloc.add(
          const TimelineMarkerAdded(
            position: Duration(seconds: 8),
            totalDuration: Duration(seconds: 5),
          ),
        ),
        expect: () => const [
          TimelineOverlayState(
            timelineMarkers: [Duration(seconds: 2), Duration(seconds: 5)],
            timelineMarkersRevision: 1,
          ),
        ],
      );
    });

    group(TimelineMarkerRemoved, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'removes an existing marker near the requested position',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          timelineMarkers: [Duration(milliseconds: 1200)],
        ),
        act: (bloc) => bloc.add(
          const TimelineMarkerRemoved(Duration(milliseconds: 1230)),
        ),
        expect: () => const [TimelineOverlayState(timelineMarkersRevision: 1)],
      );

      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'does not emit when no marker is near the requested position',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          timelineMarkers: [Duration(milliseconds: 1200)],
        ),
        act: (bloc) => bloc.add(
          const TimelineMarkerRemoved(Duration(milliseconds: 1500)),
        ),
        expect: () => <TimelineOverlayState>[],
      );
    });

    group(TimelineMarkersRebased, () {
      blocTest<TimelineOverlayBloc, TimelineOverlayState>(
        'replaces markers without bumping the history revision',
        build: TimelineOverlayBloc.new,
        seed: () => const TimelineOverlayState(
          timelineMarkers: [Duration(seconds: 1)],
          timelineMarkersRevision: 4,
        ),
        act: (bloc) => bloc.add(
          const TimelineMarkersRebased([
            Duration(seconds: 5),
            Duration(seconds: 2),
            Duration(seconds: 2),
          ]),
        ),
        expect: () => const [
          TimelineOverlayState(
            timelineMarkers: [Duration(seconds: 2), Duration(seconds: 5)],
            timelineMarkersRevision: 4,
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
