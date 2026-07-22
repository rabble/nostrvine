// ABOUTME: Maps between burned-in caption TextLayers and CaptionCue models.
// ABOUTME: The Layer.meta marker is the single source of caption identity.

import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Whether [layer] is a burned-in caption cue (built by
/// `CaptionStylePreset.buildLayer`).
bool isCaptionCueLayer(Layer layer) =>
    layer.meta?[VideoEditorConstants.captionCueMetaKey] == true;

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
