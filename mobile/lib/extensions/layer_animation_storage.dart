// ABOUTME: Bridges a pro_image_editor Layer's typed enter/leave animations to
// ABOUTME: the pro_video_editor LayerAnimation the export pipeline consumes.

import 'package:pro_image_editor/core/models/layers/layer.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

/// The two packages model layer animations identically (same enum names and
/// `toMap` keys), so a map round-trip converts losslessly between them. This is
/// the single boundary where pro_image_editor's [LayerAnimation] (used for
/// editing + the in-editor preview) becomes pro_video_editor's (used at export).
extension LayerAnimationStorage on Layer {
  /// This layer's enter/leave animations as pro_video_editor models, for the
  /// export pipeline. Empty when the layer has no animations.
  List<pve.LayerAnimation> get divineAnimations =>
      animations.map((a) => pve.LayerAnimation.fromMap(a.toMap())).toList();

  /// The first [pve.AnimationPhase.animateIn] animation, or `null`.
  pve.LayerAnimation? get divineEnterAnimation {
    for (final animation in divineAnimations) {
      if (animation.phase == pve.AnimationPhase.animateIn) return animation;
    }
    return null;
  }

  /// The first [pve.AnimationPhase.animateOut] animation, or `null`.
  pve.LayerAnimation? get divineLeaveAnimation {
    for (final animation in divineAnimations) {
      if (animation.phase == pve.AnimationPhase.animateOut) return animation;
    }
    return null;
  }
}

/// Converts the picker's pro_video_editor animations into pro_image_editor
/// [LayerAnimation]s for assignment to [Layer.animations].
List<LayerAnimation> toLayerAnimations(List<pve.LayerAnimation> animations) =>
    animations.map((a) => LayerAnimation.fromMap(a.toMap())).toList();
