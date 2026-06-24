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
      final layer = Layer(animations: [enter, leave].toLayerAnimations());

      expect(layer.divineAnimations, equals([enter, leave]));
    });

    test('returns [] when the layer has no animations', () {
      expect(Layer().divineAnimations, isEmpty);
    });

    test('exposes the enter and leave animations by phase', () {
      final layer = Layer(animations: [leave, enter].toLayerAnimations());

      expect(layer.divineEnterAnimations, equals([enter]));
      expect(layer.divineLeaveAnimations, equals([leave]));
    });

    test('exposes every animation of a phase when several are combined', () {
      const slideIn = editor.LayerAnimation(
        type: editor.LayerAnimationType.slide,
        phase: editor.AnimationPhase.animateIn,
        duration: Duration(milliseconds: 400),
        slideDirection: editor.SlideDirection.left,
      );
      const fadeIn = editor.LayerAnimation(
        type: editor.LayerAnimationType.fade,
        phase: editor.AnimationPhase.animateIn,
        duration: Duration(milliseconds: 400),
      );
      final layer = Layer(animations: [fadeIn, slideIn].toLayerAnimations());

      expect(layer.divineEnterAnimations, equals([fadeIn, slideIn]));
      expect(layer.divineLeaveAnimations, isEmpty);
    });

    test('preserves scale-from across the conversion', () {
      const scaleIn = editor.LayerAnimation(
        type: editor.LayerAnimationType.scale,
        phase: editor.AnimationPhase.animateIn,
        duration: Duration(milliseconds: 500),
        scaleFrom: 0.5,
      );
      final layer = Layer(animations: [scaleIn].toLayerAnimations());

      expect(layer.divineAnimations.single.scaleFrom, equals(0.5));
    });

    test('empty input clears to no animations', () {
      final layer = Layer(
        animations: const <editor.LayerAnimation>[].toLayerAnimations(),
      );

      expect(layer.divineAnimations, isEmpty);
    });

    // pro_video_editor's fromMap is strict (`values.byName` throws on an
    // unknown name), so a future dependency bump that renamed any unexercised
    // enum value would throw at export time. Iterating every value turns the
    // schema-parity guarantee into something these tests enforce.
    test('round-trips every animation curve', () {
      for (final curve in editor.AnimationCurve.values) {
        final animation = editor.LayerAnimation(
          type: editor.LayerAnimationType.fade,
          phase: editor.AnimationPhase.animateIn,
          duration: const Duration(milliseconds: 400),
          curve: curve,
        );
        final layer = Layer(animations: [animation].toLayerAnimations());

        expect(
          layer.divineAnimations.single,
          equals(animation),
          reason: '$curve',
        );
      }
    });

    test('round-trips every slide direction', () {
      for (final direction in editor.SlideDirection.values) {
        final animation = editor.LayerAnimation(
          type: editor.LayerAnimationType.slide,
          phase: editor.AnimationPhase.animateIn,
          duration: const Duration(milliseconds: 400),
          slideDirection: direction,
        );
        final layer = Layer(animations: [animation].toLayerAnimations());

        expect(
          layer.divineAnimations.single,
          equals(animation),
          reason: '$direction',
        );
      }
    });

    test('round-trips every type and phase', () {
      for (final type in editor.LayerAnimationType.values) {
        for (final phase in editor.AnimationPhase.values) {
          final animation = editor.LayerAnimation(
            type: type,
            phase: phase,
            duration: const Duration(milliseconds: 250),
            slideDirection: type == editor.LayerAnimationType.slide
                ? editor.SlideDirection.top
                : null,
            scaleFrom: type == editor.LayerAnimationType.scale ? 0.25 : null,
          );
          final layer = Layer(animations: [animation].toLayerAnimations());

          expect(
            layer.divineAnimations.single,
            equals(animation),
            reason: '$type / $phase',
          );
        }
      }
    });
  });
}
