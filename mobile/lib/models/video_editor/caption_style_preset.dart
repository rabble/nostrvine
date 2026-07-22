// ABOUTME: Track-wide caption style presets: font + colors + animation as one
// ABOUTME: fixed unit, and the TextLayer factory for burned-in caption cues.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;

/// A caption look: font, colors, and enter/leave animation as one fixed unit.
///
/// Presets are the only way captions are styled — font and animation are never
/// configured separately. The animation primitives are restricted to what
/// pro_video_editor renders natively (fade/slide/scale with easing curves), so
/// the in-editor preview (pro_image_editor `LayerTimelineVisibility`) and the
/// exported video always match.
class CaptionStylePreset {
  /// Creates a preset. Instances live in [presets]; UI resolves display names
  /// from [id] via l10n.
  const CaptionStylePreset({
    required this.id,
    required this.font,
    required this.color,
    required this.background,
    required this.colorMode,
    required this.enter,
    required this.leave,
    this.fontScale = 1,
  });

  /// Stable identifier stored on the [CaptionTrack].
  final String id;

  /// The Google Font this preset renders with.
  final TextFont font;

  /// Text color.
  final Color color;

  /// Pill/background color (used when [colorMode] draws a background).
  final Color background;

  /// How [color] and [background] combine on the text layer.
  final LayerBackgroundMode colorMode;

  /// Animations played when a cue appears.
  final List<pve.LayerAnimation> enter;

  /// Animations played when a cue disappears.
  final List<pve.LayerAnimation> leave;

  /// Multiplier on the editor's base font size.
  final double fontScale;

  /// Builds the burned-in editor layer for [cue].
  ///
  /// [fittedBoxScale] and [bodySize] are the canvas metrics the editor screen
  /// exposes, used to place the cue bottom-center in render coordinates (the
  /// same conversion the sticker flow applies).
  TextLayer buildLayer(
    CaptionCue cue, {
    required double fittedBoxScale,
    required Size bodySize,
  }) {
    return TextLayer(
      text: cue.text,
      textStyle: font(),
      colorMode: colorMode,
      color: color,
      background: background,
      align: TextAlign.center,
      fontScale: fontScale,
      offset: Offset(0, bodySize.height * _bottomOffsetFactor / fittedBoxScale),
      startTime: cue.start,
      endTime: cue.end,
      animations: [...enter, ...leave].toLayerAnimations(),
      meta: {
        VideoEditorConstants.captionCueMetaKey: true,
        VideoEditorConstants.captionCueIdMetaKey: cue.id,
      },
    );
  }

  /// Vertical placement of caption cues: fraction of the canvas height below
  /// center, keeping captions in the lower third without touching the edge.
  static const double _bottomOffsetFactor = 0.32;

  /// Resolves [id] to its preset, falling back to the first preset so an
  /// unknown id from an old draft still renders.
  static CaptionStylePreset byId(String id) => presets.firstWhere(
    (preset) => preset.id == id,
    orElse: () => presets.first,
  );

  /// Colors from the editor's shared text palette
  /// ([VideoEditorConstants.colors]) so presets introduce no new raw colors.
  static final Color _white = VideoEditorConstants.colors[0];
  static final Color _pink = VideoEditorConstants.colors[6];

  /// All available presets, in display order.
  static final List<CaptionStylePreset> presets = [
    CaptionStylePreset(
      id: 'classic',
      font: GoogleFonts.inter,
      color: _white,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.backgroundAndColor,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 200),
          curve: pve.AnimationCurve.easeOut,
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 200),
          curve: pve.AnimationCurve.easeIn,
        ),
      ],
    ),
    const CaptionStylePreset(
      id: 'pop',
      font: GoogleFonts.bricolageGrotesque,
      color: VideoEditorConstants.primaryColor,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      fontScale: 1.15,
      enter: [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.scale,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 450),
          curve: pve.AnimationCurve.bounceOut,
          scaleFrom: 0.6,
        ),
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 150),
        ),
      ],
      leave: [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 150),
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'slideUp',
      font: GoogleFonts.montserrat,
      color: _white,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.backgroundAndColor,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.slide,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 350),
          curve: pve.AnimationCurve.easeOutCubic,
          slideDirection: pve.SlideDirection.bottom,
        ),
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 250),
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 250),
        ),
      ],
    ),
    const CaptionStylePreset(
      id: 'spring',
      font: GoogleFonts.poppins,
      color: VineTheme.primaryContainer,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      fontScale: 1.1,
      enter: [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.scale,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 600),
          curve: pve.AnimationCurve.elasticOut,
          scaleFrom: 0.3,
        ),
      ],
      leave: [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 150),
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'mono',
      font: GoogleFonts.ibmPlexMono,
      color: _white,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 120),
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.fade,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 120),
        ),
      ],
    ),
    CaptionStylePreset(
      id: 'headline',
      font: GoogleFonts.bebasNeue,
      color: _pink,
      background: VineTheme.scrim65,
      colorMode: LayerBackgroundMode.onlyColor,
      fontScale: 1.3,
      enter: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.slide,
          phase: pve.AnimationPhase.animateIn,
          duration: Duration(milliseconds: 300),
          curve: pve.AnimationCurve.easeOut,
          slideDirection: pve.SlideDirection.left,
        ),
      ],
      leave: const [
        pve.LayerAnimation(
          type: pve.LayerAnimationType.slide,
          phase: pve.AnimationPhase.animateOut,
          duration: Duration(milliseconds: 300),
          curve: pve.AnimationCurve.easeIn,
          slideDirection: pve.SlideDirection.right,
        ),
      ],
    ),
  ];
}
