// ABOUTME: Maps between burned-in caption TextLayers and CaptionCue models.
// ABOUTME: The Layer.meta marker is the single source of caption identity.

import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Whether [layer] is a burned-in caption cue (built by
/// `CaptionStylePreset.buildLayer`).
bool isCaptionCueLayer(Layer layer) =>
    layer.meta?[VideoEditorConstants.captionCueMetaKey] == true;

/// The cue id a burned-in caption [layer] carries, or `null` when [layer] is
/// not a caption cue layer (or lost its stored id).
String? captionCueIdOf(Layer layer) => isCaptionCueLayer(layer)
    ? (layer.meta?[VideoEditorConstants.captionCueIdMetaKey] as String?)
    : null;

/// Carries the on-canvas transform (position, rotation, scale) of a previous
/// caption layer over onto a freshly [rebuilt] one, so re-editing a burn-in
/// track doesn't silently reset a user's manual adjustments. Returns [rebuilt]
/// unchanged when there is no matching [existing] layer.
TextLayer preserveCaptionLayerTransform(TextLayer rebuilt, Layer? existing) =>
    existing == null
    ? rebuilt
    : rebuilt.copyWith(
        offset: existing.offset,
        rotation: existing.rotation,
        scale: existing.scale,
      );

/// Rebuilds the cue list from burned-in caption [layers], ordered by start.
///
/// Inverse of `CaptionStylePreset.buildLayer` for mode switching and for
/// re-opening the captions editor on a burn-in session (where the layers are
/// the source of truth). Layers without a stored cue id fall back to their
/// layer id, so a hand-tweaked draft still round-trips.
List<CaptionCue> captionCuesFromLayers(Iterable<Layer> layers) {
  final cues = <CaptionCue>[
    for (final layer in layers)
      if (layer is TextLayer && isCaptionCueLayer(layer))
        CaptionCue(
          id:
              layer.meta?[VideoEditorConstants.captionCueIdMetaKey]
                  as String? ??
              layer.id,
          text: layer.text,
          start: layer.startTime ?? Duration.zero,
          end: layer.endTime ?? Duration.zero,
        ),
  ]..sort((a, b) => a.start.compareTo(b.start));
  return cues;
}
