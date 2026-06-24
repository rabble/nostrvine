// ABOUTME: Persists a layer's enter/leave animations on a pro_image_editor
// ABOUTME: Layer via its meta map, until the typed package API ships.

import 'package:pro_image_editor/core/models/layers/layer.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show AnimationPhase, LayerAnimation;

/// Meta key under which a layer's enter/leave animations are stored.
///
/// pro_image_editor 12.6.0's [Layer] only persists a *fade* enter/leave
/// natively ([Layer.enterDuration] / [Layer.exitDuration] / curves); the richer
/// slide/scale + per-phase config has no typed home yet, so it rides along in
/// the generic [Layer.meta] (which is serialized with the layer). When
/// pro_image_editor gains a typed `Layer.animations`, only this file changes.
const _animationsMetaKey = 'divineLayerAnimations';

/// Reads the enter/leave animations a layer carries.
extension LayerAnimationStorage on Layer {
  /// The animations configured for this layer, or `const []` when none.
  ///
  /// Corrupt entries are skipped rather than throwing, so a single bad map
  /// can't blank a layer's whole animation set.
  List<LayerAnimation> get divineAnimations {
    final raw = meta?[_animationsMetaKey];
    if (raw is! List) return const [];
    final result = <LayerAnimation>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      try {
        result.add(LayerAnimation.fromMap(entry.cast<String, dynamic>()));
      } catch (_) {
        // Skip an unparseable entry; the rest stay usable.
      }
    }
    return result;
  }

  /// The first [AnimationPhase.animateIn] animation, or `null`.
  LayerAnimation? get divineEnterAnimation => divineAnimations
      .where((a) => a.phase == AnimationPhase.animateIn)
      .firstOrNull;

  /// The first [AnimationPhase.animateOut] animation, or `null`.
  LayerAnimation? get divineLeaveAnimation => divineAnimations
      .where((a) => a.phase == AnimationPhase.animateOut)
      .firstOrNull;
}

/// Returns a copy of [existing] meta with [animations] stored (or the key
/// removed when [animations] is empty), suitable for `Layer.copyWith(meta:)`.
///
/// Returns `null` when the resulting map is empty so the layer doesn't persist
/// an empty `meta` object.
Map<String, dynamic>? metaWithLayerAnimations(
  Map<String, dynamic>? existing,
  List<LayerAnimation> animations,
) {
  final map = {...?existing};
  if (animations.isEmpty) {
    map.remove(_animationsMetaKey);
  } else {
    map[_animationsMetaKey] = animations.map((a) => a.toMap()).toList();
  }
  return map.isEmpty ? null : map;
}
