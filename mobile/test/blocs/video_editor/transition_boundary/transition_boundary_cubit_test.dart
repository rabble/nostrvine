import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/blocs/video_editor/transition_boundary/transition_boundary_cubit.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DivineVideoClip clip() => DivineVideoClip(
    id: 'c1',
    video: editor.EditorVideo.file(File('/tmp/clip.mp4')),
    duration: const Duration(seconds: 5),
    recordedAt: DateTime(2024),
    targetAspectRatio: model.AspectRatio.square,
    originalAspectRatio: 1,
  );

  group(TransitionBoundaryCubit, () {
    test('seeds its state with the provided placeholder frames', () {
      final cubit = TransitionBoundaryCubit(
        fromClip: clip(),
        toClip: clip(),
        fromPlaceholder: 'ghost.jpg',
        toPlaceholder: 'thumb.jpg',
      );
      addTearDown(cubit.close);

      expect(cubit.state.fromFramePath, equals('ghost.jpg'));
      expect(cubit.state.toFramePath, equals('thumb.jpg'));
    });

    test(
      'swaps in the freshly-extracted boundary frames as they resolve',
      () async {
        final cubit = TransitionBoundaryCubit(
          fromClip: clip(),
          toClip: clip(),
          fromPlaceholder: 'ghost.jpg',
          toPlaceholder: 'thumb.jpg',
          frameExtractor: (c, {required tail}) async =>
              tail ? 'from_exact.jpg' : 'to_exact.jpg',
        );
        addTearDown(cubit.close);

        await pumpEventQueue();

        expect(cubit.state.fromFramePath, equals('from_exact.jpg'));
        expect(cubit.state.toFramePath, equals('to_exact.jpg'));
      },
    );

    test('keeps the placeholder frames when extraction returns null', () async {
      final cubit = TransitionBoundaryCubit(
        fromClip: clip(),
        toClip: clip(),
        fromPlaceholder: 'ghost.jpg',
        toPlaceholder: 'thumb.jpg',
        frameExtractor: (c, {required tail}) async => null,
      );
      addTearDown(cubit.close);

      await pumpEventQueue();

      expect(cubit.state.fromFramePath, equals('ghost.jpg'));
      expect(cubit.state.toFramePath, equals('thumb.jpg'));
    });
  });

  group(TransitionBoundaryState, () {
    test('copyWith overrides only the given field', () {
      const state = TransitionBoundaryState(
        fromFramePath: 'a',
        toFramePath: 'b',
      );

      expect(
        state.copyWith(toFramePath: 'c'),
        equals(
          const TransitionBoundaryState(fromFramePath: 'a', toFramePath: 'c'),
        ),
      );
    });

    test('values with equal paths are equal', () {
      expect(
        const TransitionBoundaryState(fromFramePath: 'a'),
        equals(const TransitionBoundaryState(fromFramePath: 'a')),
      );
    });
  });
}
