// ABOUTME: Bottom-sheet picker for a layer's enter/leave animation (fade,
// ABOUTME: slide, scale) — twin of the clip-transition sheet, shared controls.

import 'dart:ui' show lerpDouble;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/animation_picker_components.dart';
import 'package:pro_image_editor/core/models/layers/layer.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show
        AnimationCurve,
        AnimationPhase,
        LayerAnimation,
        LayerAnimationType,
        SlideDirection;

/// Inclusive bounds (and snap step) for the duration slider, in milliseconds.
const _minDurationMs = 10;
const _maxDurationMs = 2000;
const _durationStepMs = 10;

/// Default duration applied when a type is first picked for a phase.
const _defaultDuration = Duration(milliseconds: 400);

/// Preview loop length; the animation occupies the middle slice (see
/// [_holdProgress]).
const _loopMs = 2400;

const _previewWidth = 56.0;
const _previewHeight = 72.0;

/// Directions offered for a slide animation, mapped onto [SlideDirection].
const _slideDirections = <SlideDirection>[
  SlideDirection.left,
  SlideDirection.right,
  SlideDirection.top,
  SlideDirection.bottom,
];

/// Opens the enter/leave animation picker for [layer] and applies the choice to
/// that layer through the editor history.
///
/// A layer carries up to one enter animation and one leave animation; both are
/// editable in the sheet and stored via [metaWithLayerAnimations] (plus the
/// native fade fields + a [Layer.transitionBuilder] so the in-editor timeline
/// previews them).
Future<void> editLayerAnimation(BuildContext context, Layer layer) async {
  final scope = VideoEditorScope.of(context);
  final editor = scope.editor;
  if (editor == null) return;

  final result = await VineBottomSheet.show<_LayerAnimationResult>(
    context: context,
    expanded: false,
    scrollable: false,
    isScrollControlled: true,
    title: Text(
      context.l10n.videoEditorLayerAnimationLabel,
      style: VineTheme.titleMediumFont(),
    ),
    body: LayerAnimationPickerView(
      initialEnter: layer.divineEnterAnimation,
      initialLeave: layer.divineLeaveAnimation,
    ),
  );

  if (result == null || !context.mounted) return;

  final layers = List<Layer>.from(editor.activeLayers);
  final index = layers.indexWhere((l) => l.id == layer.id);
  if (index < 0) return;

  final animations = <LayerAnimation>[
    if (result.enter != null) result.enter!,
    if (result.leave != null) result.leave!,
  ];

  layers[index] = layer.copyWith()
    ..meta = metaWithLayerAnimations(layer.meta, animations)
    ..enterDuration = result.enter?.duration
    ..exitDuration = result.leave?.duration
    ..enterCurve = result.enter == null
        ? null
        : flutterCurveFor(result.enter!.curve)
    ..exitCurve = result.leave == null
        ? null
        : flutterCurveFor(result.leave!.curve)
    ..transitionBuilder = buildLayerTransitionBuilder(
      enter: result.enter,
      leave: result.leave,
    );

  editor.addHistory(layers: layers);
}

/// The picker's result: the chosen enter and/or leave animation (`null` =
/// none for that phase).
typedef _LayerAnimationResult = ({
  LayerAnimation? enter,
  LayerAnimation? leave,
});

/// Builds a per-layer timeline transition builder that renders [enter]/[leave]
/// in the editor preview.
///
/// pro_image_editor drives a single `animation` (0→1 entering, 1→0 leaving)
/// through one builder, so a differing enter vs leave type can't both be shown
/// faithfully here — the [enter] spec (falling back to [leave]) drives the
/// visual. The export path applies each phase exactly; full per-phase preview
/// arrives with the typed `Layer.animations` package API. Returns `null` when
/// there is nothing to animate (default fade builder is used).
Widget Function(Widget, Animation<double>)? buildLayerTransitionBuilder({
  required LayerAnimation? enter,
  required LayerAnimation? leave,
}) {
  final spec = enter ?? leave;
  if (spec == null) return null;
  final curve = flutterCurveFor(spec.curve);
  return (child, animation) {
    final t = curve.transform(animation.value.clamp(0.0, 1.0));
    return switch (spec.type) {
      LayerAnimationType.fade => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: child,
      ),
      LayerAnimationType.scale => Transform.scale(
        scale: lerpDouble(spec.scaleFrom ?? 0.0, 1.0, t) ?? 1.0,
        child: child,
      ),
      LayerAnimationType.slide => Transform.translate(
        offset: _slideOffset(spec.slideDirection ?? SlideDirection.left, 1 - t),
        child: child,
      ),
    };
  };
}

/// Offset for a slide at [away] (0 = in place, 1 = fully off in [direction]).
/// Uses a fixed reach since the layer's own size isn't known in the builder;
/// the native export computes the exact travel.
Offset _slideOffset(SlideDirection direction, double away) {
  const reach = 160.0;
  return switch (direction) {
    SlideDirection.left => Offset(-away * reach, 0),
    SlideDirection.right => Offset(away * reach, 0),
    SlideDirection.top => Offset(0, -away * reach),
    SlideDirection.bottom => Offset(0, away * reach),
  };
}

/// Stateful picker body. Edits the enter and leave animations independently via
/// an Enter|Leave toggle; pops a [_LayerAnimationResult] on confirm.
@visibleForTesting
class LayerAnimationPickerView extends StatefulWidget {
  const LayerAnimationPickerView({
    required this.initialEnter,
    required this.initialLeave,
    this.maxDurationMs = _maxDurationMs,
    super.key,
  });

  final LayerAnimation? initialEnter;
  final LayerAnimation? initialLeave;
  final int maxDurationMs;

  @override
  State<LayerAnimationPickerView> createState() =>
      _LayerAnimationPickerViewState();
}

class _LayerAnimationPickerViewState extends State<LayerAnimationPickerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  AnimationPhase _phase = AnimationPhase.animateIn;

  late _PhaseConfig _enter;
  late _PhaseConfig _leave;

  static const _typeOptions = <LayerAnimationType?>[
    null,
    LayerAnimationType.fade,
    LayerAnimationType.slide,
    LayerAnimationType.scale,
  ];

  @override
  void initState() {
    super.initState();
    _enter = _PhaseConfig.fromAnimation(widget.initialEnter);
    _leave = _PhaseConfig.fromAnimation(widget.initialLeave);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _loopMs),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _PhaseConfig get _active =>
      _phase == AnimationPhase.animateIn ? _enter : _leave;

  void _updateActive(_PhaseConfig Function(_PhaseConfig) update) {
    setState(() {
      if (_phase == AnimationPhase.animateIn) {
        _enter = update(_enter);
      } else {
        _leave = update(_leave);
      }
    });
  }

  int get _maxMs => widget.maxDurationMs;

  LayerAnimation? _build(_PhaseConfig config, AnimationPhase phase) {
    final type = config.type;
    if (type == null) return null;
    return LayerAnimation(
      type: type,
      phase: phase,
      duration: config.duration,
      curve: config.curve,
      slideDirection: type == LayerAnimationType.slide
          ? config.direction
          : null,
      scaleFrom: type == LayerAnimationType.scale ? config.scaleFrom : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = _active;
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: _PhaseToggle(
              phase: _phase,
              onChanged: (phase) => setState(() => _phase = phase),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: _previewHeight + 40,
            child: ListView.separated(
              scrollDirection: .horizontal,
              padding: const .fromSTEB(16, 4, 16, 4),
              itemCount: _typeOptions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final type = _typeOptions[index];
                return _LayerTypeTile(
                  type: type,
                  label: _typeLabel(l10n, type),
                  selected: type == active.type,
                  controller: _controller,
                  phase: _phase,
                  direction: active.direction,
                  scaleFrom: active.scaleFrom,
                  curve: active.curve,
                  durationMs: active.duration.inMilliseconds,
                  onTap: () => _updateActive((c) => c.copyWith(type: type)),
                );
              },
            ),
          ),
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: .topCenter,
              // Duration + curve stay visible for every type (incl. None) so the
              // values persist when switching type; direction/scale-from are
              // type-specific and appear only for slide/scale.
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      SectionLabel(l10n.videoEditorTransitionDuration),
                      Text(
                        _durationLabel(active.duration),
                        style: VineTheme.labelSmallFont(
                          color: VineTheme.lightText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DivineSlider(
                    value: active.duration.inMilliseconds
                        .clamp(_minDurationMs, _maxMs)
                        .toDouble(),
                    min: _minDurationMs.toDouble(),
                    max: _maxMs.toDouble(),
                    divisions: ((_maxMs - _minDurationMs) ~/ _durationStepMs)
                        .clamp(1, 1 << 20),
                    onChanged: (value) => _updateActive(
                      (c) => c.copyWith(
                        duration: Duration(milliseconds: value.round()),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SectionLabel(l10n.videoEditorTransitionCurve),
                  const SizedBox(height: 8),
                  CurvePickerRow(
                    selected: active.curve,
                    onChanged: (curve) =>
                        _updateActive((c) => c.copyWith(curve: curve)),
                  ),
                  if (active.type == LayerAnimationType.slide) ...[
                    const SizedBox(height: 16),
                    SectionLabel(l10n.videoEditorTransitionDirection),
                    const SizedBox(height: 8),
                    Row(
                      spacing: 8,
                      children: [
                        for (final direction in _slideDirections)
                          AnimationPickerChip(
                            selected: direction == active.direction,
                            onTap: () => _updateActive(
                              (c) => c.copyWith(direction: direction),
                            ),
                            semanticLabel: _directionLabel(
                              l10n,
                              direction,
                            ),
                            child: DivineIcon(
                              icon: _directionIcon(direction),
                              size: 18,
                              color: direction == active.direction
                                  ? VineTheme.primary
                                  : VineTheme.secondaryText,
                            ),
                          ),
                      ],
                    ),
                  ],
                  if (active.type == LayerAnimationType.scale) ...[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: .spaceBetween,
                      children: [
                        SectionLabel(
                          l10n.videoEditorLayerAnimationScaleFrom,
                        ),
                        Text(
                          '${(active.scaleFrom * 100).round()}%',
                          style: VineTheme.labelSmallFont(
                            color: VineTheme.lightText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DivineSlider(
                      value: (active.scaleFrom * 100).clamp(0, 100),
                      max: 100,
                      divisions: 20,
                      onChanged: (value) => _updateActive(
                        (c) => c.copyWith(scaleFrom: value / 100),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: DivineButton(
              label: l10n.videoEditorDoneLabel,
              onPressed: () => Navigator.of(context).pop((
                enter: _build(_enter, AnimationPhase.animateIn),
                leave: _build(_leave, AnimationPhase.animateOut),
              )),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _typeLabel(AppLocalizations l10n, LayerAnimationType? type) =>
      switch (type) {
        null => l10n.videoEditorTransitionNone,
        LayerAnimationType.fade => l10n.videoEditorLayerAnimationFade,
        LayerAnimationType.slide => l10n.videoEditorTransitionSlide,
        LayerAnimationType.scale => l10n.videoEditorLayerAnimationScale,
      };
}

/// Per-phase editable animation config.
class _PhaseConfig {
  const _PhaseConfig({
    required this.type,
    required this.duration,
    required this.curve,
    required this.direction,
    required this.scaleFrom,
  });

  factory _PhaseConfig.fromAnimation(LayerAnimation? animation) => _PhaseConfig(
    type: animation?.type,
    duration: animation?.duration ?? _defaultDuration,
    curve: animation?.curve ?? AnimationCurve.easeOut,
    direction: animation?.slideDirection ?? SlideDirection.left,
    scaleFrom: animation?.scaleFrom ?? 0.0,
  );

  final LayerAnimationType? type;
  final Duration duration;
  final AnimationCurve curve;
  final SlideDirection direction;
  final double scaleFrom;

  /// Sentinel marking "argument not supplied" so [copyWith] can tell a missing
  /// [type] from an explicit `null` (None).
  static const Object _unset = Object();

  _PhaseConfig copyWith({
    Object? type = _unset,
    Duration? duration,
    AnimationCurve? curve,
    SlideDirection? direction,
    double? scaleFrom,
  }) => _PhaseConfig(
    type: identical(type, _unset) ? this.type : type as LayerAnimationType?,
    duration: duration ?? this.duration,
    curve: curve ?? this.curve,
    direction: direction ?? this.direction,
    scaleFrom: scaleFrom ?? this.scaleFrom,
  );
}

/// Enter|Leave segmented toggle.
class _PhaseToggle extends StatelessWidget {
  const _PhaseToggle({required this.phase, required this.onChanged});

  final AnimationPhase phase;
  final ValueChanged<AnimationPhase> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.lightText.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _PhaseSegment(
            label: l10n.videoEditorLayerAnimationEnter,
            selected: phase == AnimationPhase.animateIn,
            onTap: () => onChanged(AnimationPhase.animateIn),
          ),
          _PhaseSegment(
            label: l10n.videoEditorLayerAnimationLeave,
            selected: phase == AnimationPhase.animateOut,
            onTap: () => onChanged(AnimationPhase.animateOut),
          ),
        ],
      ),
    );
  }
}

class _PhaseSegment extends StatelessWidget {
  const _PhaseSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? VineTheme.primary.withValues(alpha: 0.18)
                  : null,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? VineTheme.primary : Colors.transparent,
              ),
            ),
            child: Text(
              label,
              style: VineTheme.labelMediumFont(
                color: selected ? VineTheme.primary : VineTheme.lightText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One layer-animation option: a looped preview of [type] on a placeholder
/// layer for the active [phase], with a label, highlighted when [selected].
class _LayerTypeTile extends StatelessWidget {
  const _LayerTypeTile({
    required this.type,
    required this.label,
    required this.selected,
    required this.controller,
    required this.phase,
    required this.direction,
    required this.scaleFrom,
    required this.curve,
    required this.durationMs,
    required this.onTap,
  });

  final LayerAnimationType? type;
  final String label;
  final bool selected;
  final AnimationController controller;
  final AnimationPhase phase;
  final SlideDirection direction;
  final double scaleFrom;
  final AnimationCurve curve;
  final int durationMs;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: .opaque,
        child: Column(
          spacing: 6,
          mainAxisSize: .min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? VineTheme.primary : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: ExcludeSemantics(
                    child: AnimatedBuilder(
                      animation: controller,
                      builder: (context, _) => _LayerEffect(
                        type: type,
                        phase: phase,
                        direction: direction,
                        scaleFrom: scaleFrom,
                        progress: flutterCurveFor(curve).transform(
                          _holdProgress(controller.value, durationMs),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Text(
              label,
              style: VineTheme.labelSmallFont(
                color: selected ? VineTheme.primary : VineTheme.lightText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders a placeholder layer with [type] applied at [progress] (0..1) for the
/// active [phase].
class _LayerEffect extends StatelessWidget {
  const _LayerEffect({
    required this.type,
    required this.phase,
    required this.direction,
    required this.scaleFrom,
    required this.progress,
  });

  final LayerAnimationType? type;
  final AnimationPhase phase;
  final SlideDirection direction;
  final double scaleFrom;
  final double progress;

  @override
  Widget build(BuildContext context) {
    // Presence: 1 = fully on screen, 0 = gone. Enter ramps up, leave ramps down.
    final presence = phase == AnimationPhase.animateIn
        ? progress
        : 1 - progress;
    const layer = _PlaceholderLayer();
    return DecoratedBox(
      // Tinted backdrop (not a flat surface) so the placeholder layer reads
      // clearly against it during fade/slide/scale.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [VineTheme.primaryDarkGreen, VineTheme.surfaceBackground],
        ),
      ),
      child: SizedBox(
        width: _previewWidth,
        height: _previewHeight,
        child: switch (type) {
          null => const Center(child: layer),
          LayerAnimationType.fade => Center(
            child: Opacity(opacity: presence.clamp(0.0, 1.0), child: layer),
          ),
          LayerAnimationType.scale => Center(
            child: Transform.scale(
              scale: lerpDouble(scaleFrom, 1, presence) ?? 1,
              child: layer,
            ),
          ),
          LayerAnimationType.slide => Center(
            child: Transform.translate(
              offset: _previewSlideOffset(direction, 1 - presence),
              child: layer,
            ),
          ),
        },
      ),
    );
  }

  Offset _previewSlideOffset(SlideDirection direction, double away) {
    return switch (direction) {
      SlideDirection.left => Offset(-away * _previewWidth, 0),
      SlideDirection.right => Offset(away * _previewWidth, 0),
      SlideDirection.top => Offset(0, -away * _previewHeight),
      SlideDirection.bottom => Offset(0, away * _previewHeight),
    };
  }
}

class _PlaceholderLayer extends StatelessWidget {
  const _PlaceholderLayer();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.primary.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const SizedBox(
        width: 30,
        height: 30,
        child: Center(
          child: DivineIcon(
            icon: .sparkle,
            size: 16,
            color: VineTheme.backgroundColor,
          ),
        ),
      ),
    );
  }
}

/// Maps the controller's loop position (0..1) to a held 0..1 ramp so the
/// animation plays over [durationMs] of the loop with a hold on each end.
double _holdProgress(double value, int durationMs) {
  final ratio = durationMs.clamp(0, _loopMs) / _loopMs;
  final start = (1 - ratio) / 2;
  final end = start + ratio;
  if (ratio <= 0 || value <= start) return 0;
  if (value >= end) return 1;
  return (value - start) / (end - start);
}

String _directionLabel(AppLocalizations l10n, SlideDirection direction) =>
    switch (direction) {
      SlideDirection.left => l10n.videoEditorTransitionDirectionLeft,
      SlideDirection.right => l10n.videoEditorTransitionDirectionRight,
      SlideDirection.top => l10n.videoEditorTransitionDirectionUp,
      SlideDirection.bottom => l10n.videoEditorTransitionDirectionDown,
    };

DivineIconName _directionIcon(SlideDirection direction) => switch (direction) {
  SlideDirection.left => DivineIconName.arrowLeft,
  SlideDirection.right => DivineIconName.arrowRight,
  SlideDirection.top => DivineIconName.arrowUp,
  SlideDirection.bottom => DivineIconName.arrowDown,
};

String _durationLabel(Duration duration) =>
    '${(duration.inMilliseconds / 1000).toStringAsFixed(2)}s';
