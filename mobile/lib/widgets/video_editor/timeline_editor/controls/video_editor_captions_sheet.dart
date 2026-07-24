// ABOUTME: Bottom sheet for editing the captions session (cues, preset, mode).
// ABOUTME: Generates cues on-device for fresh sessions, pops a result on done.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/captions_editor/captions_editor_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/caption_generation_outcome.dart';
import 'package:openvine/models/video_editor/caption_style.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/services/video_editor/caption_remote_transcriber.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_caption_preset_sheet.dart';

/// Result of the captions editor sheet, returned via [Navigator.pop].
sealed class CaptionsEditorResult {
  const CaptionsEditorResult();
}

/// User confirmed the session; the editor commits [track] (and, for burn-in,
/// materializes [cues] as caption layers).
class CaptionsConfirmed extends CaptionsEditorResult {
  /// Creates the confirmed result.
  const CaptionsConfirmed({required this.track, required this.cues});

  /// The caption track to store in editor history meta.
  final CaptionTrack track;

  /// The full cue list of the session (also populated in burn-in mode,
  /// where [CaptionTrack.cues] stays empty).
  final List<CaptionCue> cues;
}

/// User removed the caption track entirely.
class CaptionsDeleted extends CaptionsEditorResult {
  /// Creates the deleted result.
  const CaptionsDeleted();
}

/// Shows the captions editor as a [VineBottomSheet] — the editor's standard
/// surface for focused tools (speed, transitions, presets).
///
/// A fresh session (no [initialCues]) transcribes the clips on-device first;
/// an existing session starts with its cues. Resolves to a
/// [CaptionsEditorResult], `null` when dismissed.
Future<CaptionsEditorResult?> showCaptionsEditorSheet(
  BuildContext context, {
  required String presetId,
  required String languageTag,
  required List<DivineVideoClip> clips,
  required Duration totalDuration,
  bool burnIn = false,
  CaptionCustomStyle? customStyle,
  List<CaptionCue>? initialCues,
  bool canDeleteTrack = false,
  CaptionRemoteTranscriber? remoteTranscriber,
  @visibleForTesting CaptionsEditorCubit? cubit,
}) async {
  final l10n = context.l10n;
  final sessionCubit =
      cubit ??
      CaptionsEditorCubit(
        clips: clips,
        totalDuration: totalDuration,
        burnIn: burnIn,
        presetId: presetId,
        customStyle: customStyle,
        languageTag: languageTag,
        initialCues: initialCues,
        remoteTranscriber: remoteTranscriber,
      );
  unawaited(sessionCubit.initialize());

  void confirm() {
    final state = sessionCubit.state;
    if (state.status == CaptionsEditorStatus.generating) return;
    // Cues whose text was cleared are dropped on confirm; they render as
    // nothing anyway and would only clutter the timeline and the VTT.
    // Free timing edits can reorder cues, so re-sort by start time — the
    // session keeps the edit order stable, but everything downstream
    // (timeline, VTT) expects timeline order.
    final cues = [
      for (final cue in state.cues)
        if (cue.text.trim().isNotEmpty) cue,
    ]..sort((a, b) => a.start.compareTo(b.start));
    Navigator.of(context).pop<CaptionsEditorResult>(
      CaptionsConfirmed(
        track: state.track.copyWith(cues: cues),
        cues: cues,
      ),
    );
  }

  Future<void> deleteTrack() async {
    final confirmed = await VineBottomSheetPrompt.show<bool>(
      context: context,
      sticker: .alert,
      title: l10n.videoEditorCaptionsDeleteTrackConfirmTitle,
      subtitle: l10n.videoEditorCaptionsDeleteTrackConfirmSubtitle,
      primaryButtonText: l10n.commonDelete,
      primaryButtonType: .error,
      secondaryButtonText: l10n.commonCancel,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );
    if ((confirmed ?? false) && context.mounted) {
      Navigator.of(context).pop<CaptionsEditorResult>(const CaptionsDeleted());
    }
  }

  try {
    return await VineBottomSheet.show<CaptionsEditorResult>(
      context: context,
      initialChildSize: 0.8,
      minChildSize: 0.8,
      title: Text(
        l10n.videoEditorCaptionsEditTitle,
        style: VineTheme.titleMediumFont(),
      ),
      headerLeadingAction: canDeleteTrack
          ? DivineIconButton(
              icon: .trash,
              type: .error,
              size: .small,
              semanticLabel: l10n.videoEditorCaptionsDeleteTrack,
              onPressed: deleteTrack,
            )
          : DivineIconButton(
              icon: .x,
              type: .secondary,
              size: .small,
              semanticLabel: l10n.videoEditorCaptionsCloseSemanticLabel,
              onPressed: () =>
                  Navigator.of(context).pop<CaptionsEditorResult>(),
            ),
      headerTrailingAction: DivineIconButton(
        icon: .check,
        size: .small,
        semanticLabel: l10n.videoEditorCaptionsDoneSemanticLabel,
        onPressed: confirm,
      ),
      contentWrapper: (_, child) =>
          BlocProvider.value(value: sessionCubit, child: child),
      buildScrollBody: (scrollController) => _CaptionsSheetBody(
        scrollController: scrollController,
        totalDuration: totalDuration,
      ),
    );
  } finally {
    unawaited(sessionCubit.close());
  }
}

class _CaptionsSheetBody extends StatelessWidget {
  const _CaptionsSheetBody({
    required this.scrollController,
    required this.totalDuration,
  });

  final ScrollController scrollController;
  final Duration totalDuration;

  /// Scrolls the cue list to the bottom so a freshly added cue is visible.
  /// Deferred to after layout so the new row is measured into
  /// [ScrollPosition.maxScrollExtent] before the animation targets it.
  void _scrollToNewCue() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Keyboard inset as scroll padding: content stays reachable above the
    // keyboard and the focused field can scroll itself into view — no
    // pinned bottom bar that would cover the list while typing.
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return BlocConsumer<CaptionsEditorCubit, CaptionsEditorState>(
      // Only when a cue is added to an already-shown list — not the initial
      // generation fill (generating→ready), which should stay scrolled to the
      // top.
      listenWhen: (prev, curr) =>
          prev.status == CaptionsEditorStatus.ready &&
          curr.cues.length > prev.cues.length,
      listener: (context, state) => _scrollToNewCue(),
      builder: (context, state) => switch (state.status) {
        CaptionsEditorStatus.generating => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: const [_GeneratingView()],
        ),
        CaptionsEditorStatus.empty || CaptionsEditorStatus.failed => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          children: [_FallbackView(state: state)],
        ),
        // Cue list scrolls; the action buttons stay pinned at the sheet
        // bottom. They carry no keyboard inset — while typing the keyboard
        // covers them and the list (padded by the inset) keeps the focused
        // field visible instead of the buttons overlapping it.
        CaptionsEditorStatus.ready => Column(
          children: [
            // Burn-in choice and style sit above the cue list so the primary
            // decision is made before editing individual cues.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: _CaptionsModeControls(state: state),
            ),
            const Divider(
              height: 2,
              thickness: 2,
              color: VineTheme.outlinedDisabled,
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
                children: [
                  for (var i = 0; i < state.cues.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 32, color: VineTheme.outlineMuted),
                    _CueRow(
                      key: ValueKey(state.cues[i].id),
                      cue: state.cues[i],
                      totalDuration: totalDuration,
                    ),
                  ],
                ],
              ),
            ),
            const Divider(
              height: 2,
              thickness: 2,
              color: VineTheme.outlinedDisabled,
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: DivineButton(
                  label: context.l10n.videoEditorCaptionsAddCue,
                  type: .secondary,
                  expanded: true,
                  onPressed: () => context.read<CaptionsEditorCubit>().addCue(),
                ),
              ),
            ),
          ],
        ),
      },
    );
  }
}

class _GeneratingView extends StatelessWidget {
  const _GeneratingView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        const Center(child: BrandedLoadingIndicator(size: 60)),
        Text(
          l10n.videoEditorCaptionsGeneratingTitle,
          textAlign: TextAlign.center,
          style: VineTheme.titleMediumFont(),
        ),
        Text(
          l10n.videoEditorCaptionsGeneratingSubtitle,
          textAlign: TextAlign.center,
          style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
        ),
      ],
    );
  }
}

class _FallbackView extends StatelessWidget {
  const _FallbackView({required this.state});

  final CaptionsEditorState state;

  String _message(AppLocalizations l10n) {
    if (state.status == CaptionsEditorStatus.empty) {
      return l10n.videoEditorCaptionsNoSpeechMessage;
    }
    return switch (state.failure) {
      CaptionGenerationFailure.recognizerUnavailable =>
        l10n.videoEditorCaptionsUnavailableMessage,
      CaptionGenerationFailure.notAuthorized =>
        l10n.videoEditorCaptionsNotAuthorizedMessage,
      CaptionGenerationFailure.unsupportedAudio ||
      CaptionGenerationFailure.failed ||
      null => l10n.videoEditorCaptionsFailedMessage,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 16,
      children: [
        Text(
          _message(l10n),
          textAlign: TextAlign.center,
          style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
        ),
        DivineButton(
          label: l10n.videoEditorCaptionsStartEmptyButton,
          type: .secondary,
          onPressed: () => context.read<CaptionsEditorCubit>().startEmpty(),
        ),
      ],
    );
  }
}

/// Burn-in choice and style, shown above the cue list.
class _CaptionsModeControls extends StatelessWidget {
  const _CaptionsModeControls({required this.state});

  final CaptionsEditorState state;

  Future<void> _changeStyle(BuildContext context) async {
    final cubit = context.read<CaptionsEditorCubit>();
    final selection = await showCaptionStyleSheet(
      context,
      selectedId: cubit.state.presetId,
      currentCustomStyle: cubit.state.customStyle,
    );
    switch (selection) {
      case CaptionPresetSelection(:final presetId):
        cubit.setPreset(presetId);
      case CaptionCustomSelection(:final style):
        cubit.setCustomStyle(style);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final styleName = state.hasCustomStyle
        ? l10n.videoEditorCaptionsPresetCustom
        : captionPresetDisplayName(l10n, state.presetId);
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        DivineRowCheckbox(
          state: state.burnIn
              ? DivineCheckboxState.selected
              : DivineCheckboxState.unselected,
          onChanged: (checked) =>
              context.read<CaptionsEditorCubit>().setBurnIn(burnIn: checked),
          label: Text(
            l10n.videoEditorCaptionsBurnInLabel,
            style: VineTheme.bodyMediumFont(),
          ),
        ),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            child: FadeTransition(
              opacity: animation,
              child: child,
            ),
          ),
          child: state.burnIn
              ? DivineButton(
                  label: '${l10n.videoEditorCaptionsPresetTitle}: $styleName',
                  type: .secondary,
                  expanded: true,
                  onPressed: () => _changeStyle(context),
                )
              : const SizedBox(width: .infinity),
        ),
      ],
    );
  }
}

class _CueRow extends StatefulWidget {
  const _CueRow({
    required this.cue,
    required this.totalDuration,
    super.key,
  });

  final CaptionCue cue;

  /// Slider range: the full video, so cues may freely overlap each other.
  final Duration totalDuration;

  @override
  State<_CueRow> createState() => _CueRowState();
}

class _CueRowState extends State<_CueRow> {
  late final TextEditingController _textController = TextEditingController(
    text: widget.cue.text,
  );

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  static double _seconds(Duration value) => value.inMilliseconds / 1000;

  static String _label(Duration value) =>
      '${_seconds(value).toStringAsFixed(1)}s';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<CaptionsEditorCubit>();
    final cue = widget.cue;
    return Column(
      spacing: 8,
      children: [
        // The slider spans the whole video — cues may freely overlap each
        // other; the cubit only enforces the minimum cue duration between
        // the two thumbs.
        Row(
          spacing: 12,
          children: [
            Text(
              _label(cue.start),
              style: VineTheme.bodySmallFont(color: VineTheme.secondaryText),
            ),
            Expanded(
              child: DivineRangeSlider(
                values: RangeValues(_seconds(cue.start), _seconds(cue.end)),
                max: _seconds(widget.totalDuration),
                onChanged: (values) => cubit.updateCueTiming(
                  cue.id,
                  start: Duration(
                    milliseconds: (values.start * 1000).round(),
                  ),
                  end: Duration(milliseconds: (values.end * 1000).round()),
                ),
              ),
            ),
            Text(
              _label(cue.end),
              style: VineTheme.bodySmallFont(color: VineTheme.secondaryText),
            ),
          ],
        ),
        Row(
          spacing: 8,
          children: [
            Expanded(
              child: _InputSurface(
                child: DivineTextField(
                  controller: _textController,
                  labelText: l10n.videoEditorCaptionsCueTextHint,
                  minLines: 1,
                  maxLines: 3,
                  keyboardType: .multiline,
                  textInputAction: .newline,
                  onChanged: (value) => cubit.updateCueText(cue.id, value),
                ),
              ),
            ),
            DivineIconButton(
              icon: .trash,
              type: .ghostSecondary,
              semanticLabel: l10n.videoEditorCaptionsCueDeleteSemanticLabel,
              onPressed: () => cubit.removeCue(cue.id),
            ),
          ],
        ),
      ],
    );
  }
}

/// Container surface for the sheet's inputs, mirroring the metadata form's
/// field styling on a contrasting sheet background.
class _InputSurface extends StatelessWidget {
  const _InputSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.containerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}
