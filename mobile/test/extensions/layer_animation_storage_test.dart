// ABOUTME: Tests the layer-animation meta adapter (read/write + clearing).

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:pro_image_editor/core/models/layers/layer.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

void main() {
  const enter = editor.LayerAnimation(
    type: editor.LayerAnimationType.slide,
    phase: editor.AnimationPhase.animateIn,
    duration: Duration(milliseconds: 400),
    slideDirection: editor.SlideDirection.left,
  );
  const leave = editor.LayerAnimation(
    type: editor.LayerAnimationType.fade,
    phase: editor.AnimationPhase.animateOut,
    duration: Duration(milliseconds: 300),
  );

  group('metaWithLayerAnimations', () {
    test('stores animations under the meta key', () {
      final meta = metaWithLayerAnimations(null, [enter, leave]);
      final layer = Layer(meta: meta);

      expect(layer.divineAnimations, equals([enter, leave]));
    });

    test('preserves other meta keys', () {
      final meta = metaWithLayerAnimations({'foo': 'bar'}, [enter]);

      expect(meta!['foo'], equals('bar'));
    });

    test('removes the key (and empties meta) when animations is empty', () {
      final meta = metaWithLayerAnimations(null, const []);

      expect(meta, isNull);
    });

    test('keeps other keys when clearing animations', () {
      final seeded = metaWithLayerAnimations({'foo': 'bar'}, [enter]);
      final cleared = metaWithLayerAnimations(seeded, const []);

      expect(cleared, equals({'foo': 'bar'}));
    });
  });

  group('LayerAnimationStorage', () {
    test('returns [] when no animations are set', () {
      expect(Layer().divineAnimations, isEmpty);
    });

    test('exposes the enter and leave animations by phase', () {
      final layer = Layer(meta: metaWithLayerAnimations(null, [leave, enter]));

      expect(layer.divineEnterAnimation, equals(enter));
      expect(layer.divineLeaveAnimation, equals(leave));
    });

    test('round-trips through a JSON-shaped meta map', () {
      // Simulates a draft save/load: animations stored as plain maps.
      final layer = Layer(
        meta: {
          'divineLayerAnimations': [enter.toMap(), leave.toMap()],
        },
      );

      expect(layer.divineAnimations, equals([enter, leave]));
    });

    test('skips a corrupt entry rather than dropping the whole set', () {
      final layer = Layer(
        meta: {
          'divineLayerAnimations': [
            {'type': 'not-a-type'},
            leave.toMap(),
          ],
        },
      );

      expect(layer.divineAnimations, equals([leave]));
    });
  });
}
