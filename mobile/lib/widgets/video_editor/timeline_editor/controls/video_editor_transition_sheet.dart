// ABOUTME: Bottom-sheet picker for the transition between two adjacent clips.
// ABOUTME: Shows looped previews on the real neighbour frames + duration/curve.

import 'dart:io';
import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/transition_boundary/transition_boundary_cubit.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show
        AnimationCurve,
        ClipTransition,
        ClipTransitionDirection,
        ClipTransitionType;

/// Inclusive bounds (and snap step) for the duration slider, in milliseconds.
/// Steps in 0.01s (10ms) for fine control. The applied transition is
/// additionally clamped to the clip length at render time, so the upper bound
/// here is only the UI ceiling.
const _minDurationMs = 10;
const _maxDurationMs = 2000;
const _durationStepMs = 10;

/// Every easing curve pro_video_editor supports, shown as drawn glyphs.
const List<AnimationCurve> _curveOptions = AnimationCurve.values;

/// Directions offered for direction-aware transitions (slide/push/wipe).
const _directionOptions = <ClipTransitionDirection>[
  ClipTransitionDirection.left,
  ClipTransitionDirection.right,
  ClipTransitionDirection.up,
  ClipTransitionDirection.down,
];

/// Transition types whose effect depends on [ClipTransitionDirection].
const _directionalTypes = <ClipTransitionType>{
  ClipTransitionType.slide,
  ClipTransitionType.push,
  ClipTransitionType.wipe,
};

const _previewWidth = 64.0;
const _previewHeight = 84.0;

/// Total preview loop length, in milliseconds. The transition itself occupies
/// the middle `_duration` slice of every loop (so the preview literally plays
/// over the chosen duration), with the remaining time split into a lead/tail
/// hold on the first/last frame. Kept above the duration ceiling so even the
/// longest transition still shows a hold.
const _loopMs = 2800;

/// Opens the transition picker for the boundary between clip [leftClipIndex]
/// and the following clip, then applies the choice to that clip's
/// [DivineVideoClip.transition] through the editor history.
///
/// A transition describes how a clip flows **into the next** clip, so the
/// boundary is identified by its left clip; the last clip has no boundary.
Future<void> editClipTransition(
  BuildContext context,
  int leftClipIndex,
) async {
  final bloc = context.read<ClipEditorBloc>();
  final state = bloc.state;
  if (leftClipIndex < 0 || leftClipIndex >= state.clips.length - 1) return;

  final clip = state.clips[leftClipIndex];
  final nextClip = state.clips[leftClipIndex + 1];
  final editor = VideoEditorScope.of(context).requireEditor;

  final result = await VineBottomSheet.show<({ClipTransition? transition})>(
    context: context,
    expanded: false,
    scrollable: false,
    isScrollControlled: true,
    title: Text(
      context.l10n.videoEditorTransitionSheetTitle,
      style: VineTheme.titleMediumFont(),
    ),
    body: BlocProvider<TransitionBoundaryCubit>(
      // A transition runs at the boundary: clip A's tail into clip B's head.
      // The cubit shows A's ghost frame and B's thumbnail immediately, then
      // swaps in the exact boundary frames (A at trimEnd, B at trimStart) as
      // they are extracted fresh.
      create: (_) => TransitionBoundaryCubit(
        fromClip: clip,
        toClip: nextClip,
        fromPlaceholder: clip.ghostFramePath ?? clip.thumbnailPath,
        toPlaceholder: nextClip.thumbnailPath,
      ),
      child: TransitionPickerView(
        // Overlaps blend both clips at once (half the shorter clip); dips fade
        // out then in, so they can run up to twice it.
        overlapMaxMs: _snapDurationMs(_boundaryShorterMs(clip, nextClip) ~/ 2),
        dipMaxMs: _snapDurationMs(_boundaryShorterMs(clip, nextClip) * 2),
        initial: clip.transition,
      ),
    ),
  );

  if (result == null || !context.mounted) return;

  final newTransition = result.transition;
  // Re-selecting the current transition is a no-op — avoid a redundant history
  // entry.
  if (newTransition == clip.transition) return;

  final updated = clip.copyWith(
    transition: newTransition,
    clearTransition: newTransition == null,
  );
  final newClips = state.clips
      .map((c) => c.id == clip.id ? updated : c)
      .toList();

  bloc.add(ClipEditorClipUpdated(clipId: clip.id, clip: updated));
  editor.setClipState(newClips);
}

/// The shorter of the two adjacent clips' playback durations, in ms — the basis
/// for how long a transition at this boundary may run.
int _boundaryShorterMs(DivineVideoClip a, DivineVideoClip b) {
  final shorter = a.playbackDuration < b.playbackDuration
      ? a.playbackDuration
      : b.playbackDuration;
  return shorter.inMilliseconds;
}

/// Snaps [ms] down to the slider's step grid and into its valid range, so every
/// division lands on a clean 0.01s value (an off-grid max makes the slider
/// interpolate ugly intermediate steps).
int _snapDurationMs(int ms) =>
    ((ms ~/ _durationStepMs) * _durationStepMs).clamp(
      _minDurationMs,
      _maxDurationMs,
    );

/// Stateful picker body: a row of looped transition previews plus duration and
/// curve controls. Pops `(transition:)` on confirm.
@visibleForTesting
class TransitionPickerView extends StatefulWidget {
  const TransitionPickerView({
    required this.initial,
    this.overlapMaxMs = _maxDurationMs,
    this.dipMaxMs = _maxDurationMs,
    super.key,
  });

  /// Duration-slider ceilings for the two transition families. An overlap
  /// (dissolve/slide/push/wipe) blends both clips at once, so it's capped at
  /// half the shorter clip; a dip (fadeToBlack/White) fades out then in, so it
  /// can run up to twice the shorter clip. Both are what the seam preview can
  /// show faithfully; the render path clamps to the same values as a safety
  /// net. Default to [_maxDurationMs] in tests.
  final int overlapMaxMs;
  final int dipMaxMs;

  final ClipTransition? initial;

  @override
  State<TransitionPickerView> createState() => _TransitionPickerViewState();
}

class _TransitionPickerViewState extends State<TransitionPickerView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  ClipTransitionType? _type;
  Duration _duration = const Duration(milliseconds: 500);
  AnimationCurve _curve = AnimationCurve.linear;
  ClipTransitionDirection _direction = ClipTransitionDirection.left;

  static const _options = <ClipTransitionType?>[
    null,
    ClipTransitionType.dissolve,
    ClipTransitionType.fadeToBlack,
    ClipTransitionType.fadeToWhite,
    ClipTransitionType.slide,
    ClipTransitionType.push,
    ClipTransitionType.wipe,
  ];

  /// Dip transitions fade out then in (no simultaneous blend), so they may run
  /// up to twice the shorter clip; overlaps blend both at once and cap at half.
  bool _isDip(ClipTransitionType? type) =>
      type == ClipTransitionType.fadeToBlack ||
      type == ClipTransitionType.fadeToWhite;

  /// The duration-slider ceiling for the currently selected type.
  int get _currentMaxMs =>
      _isDip(_type) ? widget.dipMaxMs : widget.overlapMaxMs;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _type = initial?.type;
    _duration = Duration(
      milliseconds: (initial?.duration ?? _duration).inMilliseconds.clamp(
        _minDurationMs,
        _currentMaxMs,
      ),
    );
    _curve = initial?.curve ?? _curve;
    _direction = initial?.direction ?? _direction;
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

  ClipTransition? _buildTransition() {
    final type = _type;
    if (type == null) return null;
    return ClipTransition(
      type: type,
      duration: _duration,
      curve: _curve,
      direction: _direction,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final fromPath = context.select(
      (TransitionBoundaryCubit c) => c.state.fromFramePath,
    );
    final toPath = context.select(
      (TransitionBoundaryCubit c) => c.state.toFramePath,
    );

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .stretch,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: _previewHeight + 44,
            child: ListView.separated(
              scrollDirection: .horizontal,
              padding: const .fromSTEB(16, 4, 16, 4),
              itemCount: _options.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final type = _options[index];
                return _TransitionTile(
                  type: type,
                  label: _typeLabel(l10n, type),
                  selected: type == _type,
                  controller: _controller,
                  curve: _curve,
                  direction: _direction,
                  durationMs: _duration.inMilliseconds,
                  fromThumbnailPath: fromPath,
                  toThumbnailPath: toPath,
                  onTap: () => setState(() {
                    _type = type;
                    // The ceiling depends on the type (overlap vs dip); re-clamp
                    // so a dip's longer pick doesn't survive a switch to an
                    // overlap.
                    _duration = Duration(
                      milliseconds: _duration.inMilliseconds.clamp(
                        _minDurationMs,
                        _currentMaxMs,
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          Padding(
            padding: const .symmetric(horizontal: 16),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: .topCenter,
              child: Column(
                crossAxisAlignment: .stretch,
                children: [
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: .spaceBetween,
                    children: [
                      _SectionLabel(l10n.videoEditorTransitionDuration),
                      Text(
                        _durationLabel(_duration),
                        style: VineTheme.labelSmallFont(
                          color: VineTheme.lightText,
                        ),
                      ),
                    ],
                  ),
                  if (_currentMaxMs > _minDurationMs) ...[
                    const SizedBox(height: 8),
                    DivineSlider(
                      value: _duration.inMilliseconds.toDouble(),
                      min: _minDurationMs.toDouble(),
                      max: _currentMaxMs.toDouble(),
                      divisions:
                          ((_currentMaxMs - _minDurationMs) ~/ _durationStepMs)
                              .clamp(1, 1 << 20),
                      onChanged: (value) => setState(
                        () => _duration = Duration(
                          milliseconds: value.round(),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _SectionLabel(l10n.videoEditorTransitionCurve),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < _curveOptions.length; i++)
                        _PickerChip(
                          selected: _curveOptions[i] == _curve,
                          onTap: () =>
                              setState(() => _curve = _curveOptions[i]),
                          semanticLabel: l10n
                              .videoEditorTransitionCurveOptionSemanticLabel(
                                i + 1,
                              ),
                          child: SizedBox(
                            width: 28,
                            height: 18,
                            child: CustomPaint(
                              painter: _CurveGlyphPainter(
                                curve: _flutterCurve(_curveOptions[i]),
                                color: _curveOptions[i] == _curve
                                    ? VineTheme.primary
                                    : VineTheme.secondaryText,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_directionalTypes.contains(_type)) ...[
                    const SizedBox(height: 16),
                    _SectionLabel(l10n.videoEditorTransitionDirection),
                    const SizedBox(height: 8),
                    Row(
                      spacing: 8,
                      children: [
                        for (final direction in _directionOptions)
                          _PickerChip(
                            selected: direction == _direction,
                            onTap: () => setState(
                              () => _direction = direction,
                            ),
                            semanticLabel: _directionLabel(l10n, direction),
                            child: DivineIcon(
                              icon: _directionIcon(direction),
                              size: 18,
                              color: direction == _direction
                                  ? VineTheme.primary
                                  : VineTheme.secondaryText,
                            ),
                          ),
                      ],
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
              onPressed: () =>
                  Navigator.of(context).pop((transition: _buildTransition())),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: VineTheme.labelSmallFont(color: VineTheme.secondaryText),
  );
}

/// One transition option: a looped preview over the real neighbour frames with
/// a label, highlighted when [selected].
class _TransitionTile extends StatelessWidget {
  const _TransitionTile({
    required this.type,
    required this.label,
    required this.selected,
    required this.controller,
    required this.curve,
    required this.direction,
    required this.durationMs,
    required this.fromThumbnailPath,
    required this.toThumbnailPath,
    required this.onTap,
  });

  final ClipTransitionType? type;
  final String label;
  final bool selected;
  final AnimationController controller;
  final AnimationCurve curve;
  final ClipTransitionDirection direction;
  final int durationMs;
  final String? fromThumbnailPath;
  final String? toThumbnailPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fromFrame = _PreviewFrame(
      path: fromThumbnailPath,
      fallback: const [
        VineTheme.primaryDarkGreen,
        VineTheme.surfaceBackground,
      ],
    );
    final toFrame = _PreviewFrame(
      path: toThumbnailPath,
      fallback: const [
        VineTheme.cardBackground,
        VineTheme.surfaceContainerHigh,
      ],
    );
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
                      builder: (context, _) => _TransitionEffect(
                        type: type,
                        direction: direction,
                        progress: _flutterCurve(curve).transform(
                          _holdProgress(controller.value, durationMs),
                        ),
                        from: fromFrame,
                        to: toFrame,
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

/// Renders [from] transitioning into [to] at [progress] (0..1) for [type].
class _TransitionEffect extends StatelessWidget {
  const _TransitionEffect({
    required this.type,
    required this.direction,
    required this.progress,
    required this.from,
    required this.to,
  });

  final ClipTransitionType? type;
  final ClipTransitionDirection direction;
  final double progress;
  final Widget from;
  final Widget to;

  @override
  Widget build(BuildContext context) {
    // Elastic/bounce curves overshoot outside 0..1: opacity, the dip overlay
    // and the wipe factor must stay in range, while translate offsets keep the
    // raw value so the spring stays visible.
    final clamped = progress.clamp(0.0, 1.0);
    return SizedBox(
      width: _previewWidth,
      height: _previewHeight,
      child: switch (type) {
        // Hard cut: snap from the first to the second frame at the midpoint.
        null => clamped < 0.5 ? from : to,
        ClipTransitionType.dissolve => Stack(
          fit: .expand,
          children: [
            from,
            Opacity(opacity: clamped, child: to),
          ],
        ),
        ClipTransitionType.fadeToBlack => _dip(
          VineTheme.backgroundColor,
          clamped,
        ),
        ClipTransitionType.fadeToWhite => _dip(
          VineTheme.inverseSurface,
          clamped,
        ),
        ClipTransitionType.slide => Stack(
          fit: .expand,
          children: [
            from,
            Transform.translate(offset: _enter, child: to),
          ],
        ),
        ClipTransitionType.push => Stack(
          fit: .expand,
          children: [
            Transform.translate(offset: _exit, child: from),
            Transform.translate(offset: _enter, child: to),
          ],
        ),
        ClipTransitionType.wipe => Stack(
          fit: .expand,
          children: [from, _wipe(clamped)],
        ),
      },
    );
  }

  Widget _dip(Color color, double p) {
    final overlay = p < 0.5 ? p * 2 : (1 - p) * 2;
    return Stack(
      fit: .expand,
      children: [
        if (p < 0.5) from else to,
        Positioned.fill(
          child: ColoredBox(color: color.withValues(alpha: overlay)),
        ),
      ],
    );
  }

  Offset get _enter => switch (direction) {
    ClipTransitionDirection.left => Offset((1 - progress) * _previewWidth, 0),
    ClipTransitionDirection.right => Offset(-(1 - progress) * _previewWidth, 0),
    ClipTransitionDirection.up => Offset(0, (1 - progress) * _previewHeight),
    ClipTransitionDirection.down => Offset(0, -(1 - progress) * _previewHeight),
  };

  Offset get _exit => switch (direction) {
    ClipTransitionDirection.left => Offset(-progress * _previewWidth, 0),
    ClipTransitionDirection.right => Offset(progress * _previewWidth, 0),
    ClipTransitionDirection.up => Offset(0, -progress * _previewHeight),
    ClipTransitionDirection.down => Offset(0, progress * _previewHeight),
  };

  // A widthFactor/heightFactor Align can't drive the reveal here: under the
  // enclosing StackFit.expand the clip is force-sized to fill, so the factor is
  // ignored. Clip an explicit rect that grows with progress instead.
  Widget _wipe(double p) => ClipRect(
    clipper: _WipeClipper(progress: p, direction: direction),
    child: SizedBox(width: _previewWidth, height: _previewHeight, child: to),
  );
}

/// Reveals the incoming frame over a rectangle that grows with [progress],
/// with the wipe edge moving in [direction].
class _WipeClipper extends CustomClipper<Rect> {
  const _WipeClipper({required this.progress, required this.direction});

  final double progress;
  final ClipTransitionDirection direction;

  @override
  Rect getClip(Size size) => switch (direction) {
    ClipTransitionDirection.right => Rect.fromLTWH(
      0,
      0,
      size.width * progress,
      size.height,
    ),
    ClipTransitionDirection.left => Rect.fromLTWH(
      size.width * (1 - progress),
      0,
      size.width * progress,
      size.height,
    ),
    ClipTransitionDirection.down => Rect.fromLTWH(
      0,
      0,
      size.width,
      size.height * progress,
    ),
    ClipTransitionDirection.up => Rect.fromLTWH(
      0,
      size.height * (1 - progress),
      size.width,
      size.height * progress,
    ),
  };

  @override
  bool shouldReclip(_WipeClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.direction != direction;
}

/// A single preview frame backed by a clip thumbnail, or a gradient fallback
/// when the thumbnail is missing/unreadable.
class _PreviewFrame extends StatelessWidget {
  const _PreviewFrame({required this.path, required this.fallback});

  final String? path;
  final List<Color> fallback;

  @override
  Widget build(BuildContext context) {
    final fallbackBox = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: fallback,
        ),
      ),
      child: const SizedBox.expand(),
    );
    final filePath = path;
    if (filePath == null) return fallbackBox;
    return Image.file(
      File(filePath),
      width: _previewWidth,
      height: _previewHeight,
      fit: .cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => fallbackBox,
    );
  }
}

/// Selectable pill used for curve and direction options. The glyph/icon it
/// holds carries no text, so [semanticLabel] names the option for screen
/// readers and [selected] is surfaced as the semantic selected state.
class _PickerChip extends StatelessWidget {
  const _PickerChip({
    required this.selected,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final String semanticLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: .opaque,
        child: ConstrainedBox(
          // 48dp min keeps the tap target at the accessibility floor on both
          // axes: the wider curve glyphs already clear 48dp via padding, but
          // the 18dp direction icons (18+14+14 = 46dp) need the minWidth.
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected
                  ? VineTheme.primary.withValues(alpha: 0.18)
                  : VineTheme.lightText.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? VineTheme.primary : Colors.transparent,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Center(widthFactor: 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the shape of an easing [curve] so it needs no localized label.
class _CurveGlyphPainter extends CustomPainter {
  _CurveGlyphPainter({required this.curve, required this.color});

  final Curve curve;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    const steps = 24;
    final samples = <double>[
      for (var i = 0; i <= steps; i++) curve.transform(i / steps),
    ];
    // Normalize each curve into the glyph box so overshooting curves
    // (bounce/elastic) stay visible instead of clipping at the edges.
    final minY = samples.reduce(math.min);
    final maxY = samples.reduce(math.max);
    final span = (maxY - minY).abs() < 1e-3 ? 1.0 : maxY - minY;
    const inset = 2.0;
    final drawHeight = size.height - inset * 2;

    final path = Path();
    for (var i = 0; i <= steps; i++) {
      final x = (i / steps) * size.width;
      final norm = (samples[i] - minY) / span;
      final y = inset + (1 - norm) * drawHeight;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CurveGlyphPainter old) =>
      old.curve != curve || old.color != color;
}

/// Maps the controller's loop position (0..1) to a held 0..1 transition ramp.
///
/// The middle `durationMs` slice of the [_loopMs] loop is the transition; the
/// remaining time is split into a lead/tail hold on the first/last frame. This
/// makes the preview play the transition over exactly the chosen duration while
/// still pausing on each clip between loops.
double _holdProgress(double value, int durationMs) {
  final transition = durationMs.clamp(0, _loopMs) / _loopMs;
  final start = (1 - transition) / 2;
  final end = start + transition;
  if (transition <= 0 || value <= start) return 0;
  if (value >= end) return 1;
  return (value - start) / (end - start);
}

Curve _flutterCurve(AnimationCurve curve) => switch (curve) {
  AnimationCurve.linear => Curves.linear,
  AnimationCurve.easeIn => Curves.easeIn,
  AnimationCurve.easeOut => Curves.easeOut,
  AnimationCurve.easeInOut => Curves.easeInOut,
  AnimationCurve.easeInCubic => Curves.easeInCubic,
  AnimationCurve.easeOutCubic => Curves.easeOutCubic,
  AnimationCurve.easeInOutCubic => Curves.easeInOutCubic,
  AnimationCurve.bounceIn => Curves.bounceIn,
  AnimationCurve.bounceOut => Curves.bounceOut,
  AnimationCurve.bounceInOut => Curves.bounceInOut,
  AnimationCurve.elasticIn => Curves.elasticIn,
  AnimationCurve.elasticOut => Curves.elasticOut,
  AnimationCurve.elasticInOut => Curves.elasticInOut,
};

String _directionLabel(
  AppLocalizations l10n,
  ClipTransitionDirection direction,
) => switch (direction) {
  ClipTransitionDirection.left => l10n.videoEditorTransitionDirectionLeft,
  ClipTransitionDirection.right => l10n.videoEditorTransitionDirectionRight,
  ClipTransitionDirection.up => l10n.videoEditorTransitionDirectionUp,
  ClipTransitionDirection.down => l10n.videoEditorTransitionDirectionDown,
};

DivineIconName _directionIcon(ClipTransitionDirection direction) =>
    switch (direction) {
      ClipTransitionDirection.left => DivineIconName.arrowLeft,
      ClipTransitionDirection.right => DivineIconName.arrowRight,
      ClipTransitionDirection.up => DivineIconName.arrowUp,
      ClipTransitionDirection.down => DivineIconName.arrowDown,
    };

String _durationLabel(Duration duration) =>
    '${(duration.inMilliseconds / 1000).toStringAsFixed(2)}s';

String _typeLabel(AppLocalizations l10n, ClipTransitionType? type) =>
    switch (type) {
      null => l10n.videoEditorTransitionNone,
      ClipTransitionType.dissolve => l10n.videoEditorTransitionDissolve,
      ClipTransitionType.fadeToBlack => l10n.videoEditorTransitionFadeToBlack,
      ClipTransitionType.fadeToWhite => l10n.videoEditorTransitionFadeToWhite,
      ClipTransitionType.slide => l10n.videoEditorTransitionSlide,
      ClipTransitionType.push => l10n.videoEditorTransitionPush,
      ClipTransitionType.wipe => l10n.videoEditorTransitionWipe,
    };
