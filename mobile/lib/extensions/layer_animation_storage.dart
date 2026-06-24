// ABOUTME: Bridges a pro_image_editor Layer's typed enter/leave animations to
// ABOUTME: the pro_video_editor LayerAnimation the export pipeline consumes.

import 'package:pro_image_editor/core/models/layers/layer.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

/// The two packages model layer animations identically (same enum names and
/// `toMap` keys), so a map round-trip converts losslessly between them. This is
/// the single boundary where pro_image_editor's [LayerAnimation] (used for
/// editing + the in-editor preview) becomes pro_video_editor's (used at export).
///
/// The round-trip relies on that schema parity; a future bump of either package
/// that changes its `toMap` keys or enum names would break it silently, so it is
/// guarded by the round-trip unit test in `layer_animation_storage_test.dart` —
/// re-run that test when bumping either dependency.
extension LayerAnimationStorage on Layer {
  /// This layer's enter/leave animations as pro_video_editor models, for the
  /// export pipeline. Empty when the layer has no animations.
  ///
  /// Reads [Layer.effectiveAnimations] (not the raw [Layer.animations]) so a
  /// layer that only carries the legacy `enterDuration` / `exitDuration` fade
  /// fields still exports the fade pro_image_editor synthesizes for the preview
  /// — keeping export and preview correct-by-construction.
  List<pve.LayerAnimation> get divineAnimations => effectiveAnimations
      .map((a) => pve.LayerAnimation.fromMap(a.toMap()))
      .toList();

  /// All [pve.AnimationPhase.animateIn] animations. A layer can combine several
  /// per phase (e.g. a fade and a slide), which the renderers compose. Empty
  /// when the layer has no enter animation.
  List<pve.LayerAnimation> get divineEnterAnimations => [
    for (final animation in divineAnimations)
      if (animation.phase == pve.AnimationPhase.animateIn) animation,
  ];

  /// All [pve.AnimationPhase.animateOut] animations. Empty when the layer has
  /// no leave animation.
  List<pve.LayerAnimation> get divineLeaveAnimations => [
    for (final animation in divineAnimations)
      if (animation.phase == pve.AnimationPhase.animateOut) animation,
  ];
}

/// Converts the picker's pro_video_editor animations into pro_image_editor
/// [LayerAnimation]s for assignment to [Layer.animations] — the inverse of
/// [LayerAnimationStorage.divineAnimations].
extension DivineLayerAnimationList on List<pve.LayerAnimation> {
  /// This list as pro_image_editor [LayerAnimation]s for [Layer.animations].
  List<LayerAnimation> toLayerAnimations() =>
      map((a) => LayerAnimation.fromMap(a.toMap())).toList();
}
