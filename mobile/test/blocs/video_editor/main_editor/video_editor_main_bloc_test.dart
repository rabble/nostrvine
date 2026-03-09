// ABOUTME: Tests for VideoEditorMainBloc - main editor state management.
// ABOUTME: Covers all 13 event handlers, state transitions, and edge cases.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

void main() {
  group(VideoEditorMainBloc, () {
    VideoEditorMainBloc buildBloc() => VideoEditorMainBloc();

    test('initial state has correct defaults', () {
      final bloc = buildBloc();
      expect(bloc.state.canUndo, isFalse);
      expect(bloc.state.canRedo, isFalse);
      expect(bloc.state.openSubEditor, isNull);
      expect(bloc.state.isSubEditorOpen, isFalse);
      expect(bloc.state.isLayerInteractionActive, isFalse);
      expect(bloc.state.isLayerOverRemoveArea, isFalse);
      expect(bloc.state.layers, isEmpty);
      expect(bloc.state.isPlaying, isFalse);
      expect(bloc.state.isPlayerReady, isFalse);
      expect(bloc.state.isExternalPauseRequested, isFalse);
      expect(bloc.state.playbackRestartCounter, equals(0));
      expect(bloc.state.playbackToggleCounter, equals(0));
      bloc.close();
    });

    group(VideoEditorMainCapabilitiesChanged, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with updated canUndo and canRedo',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoEditorMainCapabilitiesChanged(
            canUndo: true,
            canRedo: true,
          ),
        ),
        expect: () => [
          isA<VideoEditorMainState>()
              .having((s) => s.canUndo, 'canUndo', isTrue)
              .having((s) => s.canRedo, 'canRedo', isTrue),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with updated layers when provided',
        build: buildBloc,
        act: (bloc) {
          final layer = TextLayer(text: 'test');
          bloc.add(
            VideoEditorMainCapabilitiesChanged(
              canUndo: false,
              canRedo: false,
              layers: [layer],
            ),
          );
        },
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.layers,
            'layers',
            hasLength(1),
          ),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'preserves existing layers when layers param is null',
        build: buildBloc,
        seed: () {
          final layer = TextLayer(text: 'existing');
          return VideoEditorMainState(layers: [layer]);
        },
        act: (bloc) => bloc.add(
          const VideoEditorMainCapabilitiesChanged(
            canUndo: true,
            canRedo: false,
          ),
        ),
        expect: () => [
          isA<VideoEditorMainState>()
              .having((s) => s.canUndo, 'canUndo', isTrue)
              .having((s) => s.layers, 'layers', hasLength(1)),
        ],
      );
    });

    group(VideoEditorLayerInteractionStarted, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with isLayerInteractionActive true',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorLayerInteractionStarted()),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isLayerInteractionActive,
            'isLayerInteractionActive',
            isTrue,
          ),
        ],
      );
    });

    group(VideoEditorLayerInteractionEnded, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with isLayerInteractionActive false '
        'and isLayerOverRemoveArea false',
        build: buildBloc,
        seed: () => const VideoEditorMainState(
          isLayerInteractionActive: true,
          isLayerOverRemoveArea: true,
        ),
        act: (bloc) => bloc.add(const VideoEditorLayerInteractionEnded()),
        expect: () => [
          isA<VideoEditorMainState>()
              .having(
                (s) => s.isLayerInteractionActive,
                'isLayerInteractionActive',
                isFalse,
              )
              .having(
                (s) => s.isLayerOverRemoveArea,
                'isLayerOverRemoveArea',
                isFalse,
              ),
        ],
      );
    });

    group(VideoEditorLayerOverRemoveAreaChanged, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with isLayerOverRemoveArea true',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoEditorLayerOverRemoveAreaChanged(isOver: true),
        ),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isLayerOverRemoveArea,
            'isLayerOverRemoveArea',
            isTrue,
          ),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'does not emit when value has not changed',
        build: buildBloc,
        seed: () => const VideoEditorMainState(isLayerOverRemoveArea: true),
        act: (bloc) => bloc.add(
          const VideoEditorLayerOverRemoveAreaChanged(isOver: true),
        ),
        expect: () => <VideoEditorMainState>[],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits when value changes from true to false',
        build: buildBloc,
        seed: () => const VideoEditorMainState(isLayerOverRemoveArea: true),
        act: (bloc) => bloc.add(
          const VideoEditorLayerOverRemoveAreaChanged(isOver: false),
        ),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isLayerOverRemoveArea,
            'isLayerOverRemoveArea',
            isFalse,
          ),
        ],
      );
    });

    group(VideoEditorMainOpenSubEditor, () {
      for (final type in SubEditorType.values) {
        blocTest<VideoEditorMainBloc, VideoEditorMainState>(
          'emits state with openSubEditor set to ${type.name}',
          build: buildBloc,
          act: (bloc) => bloc.add(VideoEditorMainOpenSubEditor(type)),
          expect: () => [
            isA<VideoEditorMainState>()
                .having((s) => s.openSubEditor, 'openSubEditor', type)
                .having((s) => s.isSubEditorOpen, 'isSubEditorOpen', isTrue),
          ],
        );
      }
    });

    group(VideoEditorMainSubEditorClosed, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with openSubEditor cleared',
        build: buildBloc,
        seed: () => const VideoEditorMainState(
          openSubEditor: SubEditorType.text,
        ),
        act: (bloc) => bloc.add(const VideoEditorMainSubEditorClosed()),
        expect: () => [
          isA<VideoEditorMainState>()
              .having((s) => s.openSubEditor, 'openSubEditor', isNull)
              .having((s) => s.isSubEditorOpen, 'isSubEditorOpen', isFalse),
        ],
      );
    });

    group(VideoEditorLayerAdded, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with new layer appended',
        build: buildBloc,
        act: (bloc) {
          final layer = TextLayer(text: 'Hello');
          bloc.add(VideoEditorLayerAdded(layer));
        },
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.layers,
            'layers',
            hasLength(1),
          ),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'appends to existing layers',
        build: buildBloc,
        seed: () {
          final existingLayer = TextLayer(text: 'Existing');
          return VideoEditorMainState(layers: [existingLayer]);
        },
        act: (bloc) {
          final newLayer = TextLayer(text: 'New');
          bloc.add(VideoEditorLayerAdded(newLayer));
        },
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.layers,
            'layers',
            hasLength(2),
          ),
        ],
      );
    });

    group(VideoEditorLayerRemoved, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with layer removed',
        build: buildBloc,
        seed: () {
          final layer = TextLayer(text: 'Remove me');
          return VideoEditorMainState(layers: [layer]);
        },
        act: (bloc) {
          final layer = bloc.state.layers.first;
          bloc.add(VideoEditorLayerRemoved(layer));
        },
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.layers,
            'layers',
            isEmpty,
          ),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'only removes the specified layer',
        build: buildBloc,
        seed: () {
          final layer1 = TextLayer(text: 'Keep');
          final layer2 = TextLayer(text: 'Remove');
          return VideoEditorMainState(layers: [layer1, layer2]);
        },
        act: (bloc) {
          final layerToRemove = bloc.state.layers.last;
          bloc.add(VideoEditorLayerRemoved(layerToRemove));
        },
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.layers,
            'layers',
            hasLength(1),
          ),
        ],
      );
    });

    group(VideoEditorPlaybackChanged, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with isPlaying true',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoEditorPlaybackChanged(isPlaying: true),
        ),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isTrue,
          ),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with isPlaying false',
        build: buildBloc,
        seed: () => const VideoEditorMainState(isPlaying: true),
        act: (bloc) => bloc.add(
          const VideoEditorPlaybackChanged(isPlaying: false),
        ),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isPlaying,
            'isPlaying',
            isFalse,
          ),
        ],
      );
    });

    group(VideoEditorPlayerReady, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with isPlayerReady true',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorPlayerReady()),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isPlayerReady,
            'isPlayerReady',
            isTrue,
          ),
        ],
      );
    });

    group(VideoEditorExternalPauseRequested, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with isExternalPauseRequested true',
        build: buildBloc,
        act: (bloc) => bloc.add(
          const VideoEditorExternalPauseRequested(isPaused: true),
        ),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isExternalPauseRequested,
            'isExternalPauseRequested',
            isTrue,
          ),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'emits state with isExternalPauseRequested false',
        build: buildBloc,
        seed: () => const VideoEditorMainState(
          isExternalPauseRequested: true,
        ),
        act: (bloc) => bloc.add(
          const VideoEditorExternalPauseRequested(isPaused: false),
        ),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.isExternalPauseRequested,
            'isExternalPauseRequested',
            isFalse,
          ),
        ],
      );
    });

    group(VideoEditorPlaybackRestartRequested, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'increments playbackRestartCounter',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorPlaybackRestartRequested()),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.playbackRestartCounter,
            'playbackRestartCounter',
            equals(1),
          ),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'increments from existing counter value',
        build: buildBloc,
        seed: () => const VideoEditorMainState(playbackRestartCounter: 5),
        act: (bloc) => bloc.add(const VideoEditorPlaybackRestartRequested()),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.playbackRestartCounter,
            'playbackRestartCounter',
            equals(6),
          ),
        ],
      );
    });

    group(VideoEditorPlaybackToggleRequested, () {
      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'increments playbackToggleCounter',
        build: buildBloc,
        act: (bloc) => bloc.add(const VideoEditorPlaybackToggleRequested()),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.playbackToggleCounter,
            'playbackToggleCounter',
            equals(1),
          ),
        ],
      );

      blocTest<VideoEditorMainBloc, VideoEditorMainState>(
        'increments from existing counter value',
        build: buildBloc,
        seed: () => const VideoEditorMainState(playbackToggleCounter: 3),
        act: (bloc) => bloc.add(const VideoEditorPlaybackToggleRequested()),
        expect: () => [
          isA<VideoEditorMainState>().having(
            (s) => s.playbackToggleCounter,
            'playbackToggleCounter',
            equals(4),
          ),
        ],
      );
    });
  });

  group('$VideoEditorMainState', () {
    test('isSubEditorOpen returns true when openSubEditor is set', () {
      const state = VideoEditorMainState(openSubEditor: SubEditorType.draw);
      expect(state.isSubEditorOpen, isTrue);
    });

    test('isSubEditorOpen returns false when openSubEditor is null', () {
      const state = VideoEditorMainState();
      expect(state.isSubEditorOpen, isFalse);
    });

    test('copyWith preserves all fields by default', () {
      final layer = TextLayer(text: 'test');
      final original = VideoEditorMainState(
        canUndo: true,
        canRedo: true,
        openSubEditor: SubEditorType.text,
        isLayerInteractionActive: true,
        isLayerOverRemoveArea: true,
        layers: [layer],
        isPlaying: true,
        isPlayerReady: true,
        isExternalPauseRequested: true,
        playbackRestartCounter: 5,
        playbackToggleCounter: 3,
      );

      final copy = original.copyWith();

      expect(copy.canUndo, isTrue);
      expect(copy.canRedo, isTrue);
      expect(copy.openSubEditor, SubEditorType.text);
      expect(copy.isLayerInteractionActive, isTrue);
      expect(copy.isLayerOverRemoveArea, isTrue);
      expect(copy.layers, hasLength(1));
      expect(copy.isPlaying, isTrue);
      expect(copy.isPlayerReady, isTrue);
      expect(copy.isExternalPauseRequested, isTrue);
      expect(copy.playbackRestartCounter, equals(5));
      expect(copy.playbackToggleCounter, equals(3));
    });

    test('copyWith with clearOpenSubEditor sets openSubEditor to null', () {
      const original = VideoEditorMainState(
        openSubEditor: SubEditorType.filter,
      );

      final copy = original.copyWith(clearOpenSubEditor: true);

      expect(copy.openSubEditor, isNull);
    });

    test('supports value equality', () {
      const state1 = VideoEditorMainState(canUndo: true);
      const state2 = VideoEditorMainState(canUndo: true);
      expect(state1, equals(state2));
    });

    test('different states are not equal', () {
      const state1 = VideoEditorMainState(canUndo: true);
      const state2 = VideoEditorMainState(canRedo: true);
      expect(state1, isNot(equals(state2)));
    });
  });

  group('$VideoEditorMainEvent equality', () {
    test(
      '$VideoEditorMainCapabilitiesChanged with same props are equal',
      () {
        const event1 = VideoEditorMainCapabilitiesChanged(
          canUndo: true,
          canRedo: false,
        );
        const event2 = VideoEditorMainCapabilitiesChanged(
          canUndo: true,
          canRedo: false,
        );
        expect(event1, equals(event2));
      },
    );

    test(
      '$VideoEditorMainCapabilitiesChanged with different props '
      'are not equal',
      () {
        const event1 = VideoEditorMainCapabilitiesChanged(
          canUndo: true,
          canRedo: false,
        );
        const event2 = VideoEditorMainCapabilitiesChanged(
          canUndo: false,
          canRedo: true,
        );
        expect(event1, isNot(equals(event2)));
      },
    );

    test('$VideoEditorLayerInteractionStarted events are equal', () {
      const event1 = VideoEditorLayerInteractionStarted();
      const event2 = VideoEditorLayerInteractionStarted();
      expect(event1, equals(event2));
    });

    test('$VideoEditorLayerInteractionEnded events are equal', () {
      const event1 = VideoEditorLayerInteractionEnded();
      const event2 = VideoEditorLayerInteractionEnded();
      expect(event1, equals(event2));
    });

    test(
      '$VideoEditorLayerOverRemoveAreaChanged with same isOver are equal',
      () {
        const event1 = VideoEditorLayerOverRemoveAreaChanged(isOver: true);
        const event2 = VideoEditorLayerOverRemoveAreaChanged(isOver: true);
        expect(event1, equals(event2));
      },
    );

    test(
      '$VideoEditorLayerOverRemoveAreaChanged with different isOver '
      'are not equal',
      () {
        const event1 = VideoEditorLayerOverRemoveAreaChanged(isOver: true);
        const event2 = VideoEditorLayerOverRemoveAreaChanged(isOver: false);
        expect(event1, isNot(equals(event2)));
      },
    );

    test('$VideoEditorMainOpenSubEditor with same type are equal', () {
      const event1 = VideoEditorMainOpenSubEditor(SubEditorType.text);
      const event2 = VideoEditorMainOpenSubEditor(SubEditorType.text);
      expect(event1, equals(event2));
    });

    test(
      '$VideoEditorMainOpenSubEditor with different types are not equal',
      () {
        const event1 = VideoEditorMainOpenSubEditor(SubEditorType.text);
        const event2 = VideoEditorMainOpenSubEditor(SubEditorType.draw);
        expect(event1, isNot(equals(event2)));
      },
    );

    test('$VideoEditorMainSubEditorClosed events are equal', () {
      const event1 = VideoEditorMainSubEditorClosed();
      const event2 = VideoEditorMainSubEditorClosed();
      expect(event1, equals(event2));
    });

    test('$VideoEditorPlaybackChanged with same isPlaying are equal', () {
      const event1 = VideoEditorPlaybackChanged(isPlaying: true);
      const event2 = VideoEditorPlaybackChanged(isPlaying: true);
      expect(event1, equals(event2));
    });

    test(
      '$VideoEditorPlaybackChanged with different isPlaying are not equal',
      () {
        const event1 = VideoEditorPlaybackChanged(isPlaying: true);
        const event2 = VideoEditorPlaybackChanged(isPlaying: false);
        expect(event1, isNot(equals(event2)));
      },
    );

    test('$VideoEditorPlayerReady events are equal', () {
      const event1 = VideoEditorPlayerReady();
      const event2 = VideoEditorPlayerReady();
      expect(event1, equals(event2));
    });

    test(
      '$VideoEditorExternalPauseRequested with same isPaused are equal',
      () {
        const event1 = VideoEditorExternalPauseRequested(isPaused: true);
        const event2 = VideoEditorExternalPauseRequested(isPaused: true);
        expect(event1, equals(event2));
      },
    );

    test(
      '$VideoEditorExternalPauseRequested with different isPaused '
      'are not equal',
      () {
        const event1 = VideoEditorExternalPauseRequested(isPaused: true);
        const event2 = VideoEditorExternalPauseRequested(isPaused: false);
        expect(event1, isNot(equals(event2)));
      },
    );

    test('$VideoEditorPlaybackRestartRequested events are equal', () {
      const event1 = VideoEditorPlaybackRestartRequested();
      const event2 = VideoEditorPlaybackRestartRequested();
      expect(event1, equals(event2));
    });

    test('$VideoEditorPlaybackToggleRequested events are equal', () {
      const event1 = VideoEditorPlaybackToggleRequested();
      const event2 = VideoEditorPlaybackToggleRequested();
      expect(event1, equals(event2));
    });
  });

  group(SubEditorType, () {
    test('has 5 values', () {
      expect(SubEditorType.values, hasLength(5));
    });

    test('contains expected types', () {
      expect(
        SubEditorType.values,
        containsAll([
          SubEditorType.text,
          SubEditorType.draw,
          SubEditorType.filter,
          SubEditorType.stickers,
          SubEditorType.music,
        ]),
      );
    });
  });
}
