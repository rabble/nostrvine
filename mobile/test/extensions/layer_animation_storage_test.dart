// ABOUTME: Tests the layer-animation bridge between pro_image_editor's typed
// ABOUTME: Layer.animations and the pro_video_editor models used at export.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:pro_image_editor/core/models/layers/layer.dart' show Layer;
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

  group('LayerAnimationStorage', () {
    test('round-trips animations through Layer.animations', () {
      final layer = Layer(animations: toLayerAnimations([enter, leave]));

      expect(layer.divineAnimations, equals([enter, leave]));
    });

    test('returns [] when the layer has no animations', () {
      expect(Layer().divineAnimations, isEmpty);
    });

    test('exposes the enter and leave animations by phase', () {
      final layer = Layer(animations: toLayerAnimations([leave, enter]));

      expect(layer.divineEnterAnimation, equals(enter));
      expect(layer.divineLeaveAnimation, equals(leave));
    });

    test('preserves scale-from across the conversion', () {
      const scaleIn = editor.LayerAnimation(
        type: editor.LayerAnimationType.scale,
        phase: editor.AnimationPhase.animateIn,
        duration: Duration(milliseconds: 500),
        scaleFrom: 0.5,
      );
      final layer = Layer(animations: toLayerAnimations([scaleIn]));

      expect(layer.divineAnimations.single.scaleFrom, equals(0.5));
    });

    test('empty input clears to no animations', () {
      final layer = Layer(animations: toLayerAnimations(const []));

      expect(layer.divineAnimations, isEmpty);
    });
  });
}
