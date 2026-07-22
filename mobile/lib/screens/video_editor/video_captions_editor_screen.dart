// ABOUTME: Full-screen captions editor pushed over the video editor.
// ABOUTME: Generates cues on-device, then lets the user edit text and style.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_editor/captions_editor/captions_editor_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/caption_generation_outcome.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_caption_preset_sheet.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';

/// Result of the captions editor screen, returned via [Navigator.pop].
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

/// Full-screen captions editor.
///
/// A fresh session (no [initialCues]) transcribes the clips on-device first;
/// an existing session starts with its cues. Returns a [CaptionsEditorResult]
/// via pop, `null` when cancelled.
class VideoCaptionsEditorScreen extends StatefulWidget {
  /// Creates the captions editor screen.
  const VideoCaptionsEditorScreen({
    required this.mode,
    required this.presetId,
    required this.languageTag,
    required this.clips,
    required this.totalDuration,
    this.initialCues,
    this.canDeleteTrack = false,
    @visibleForTesting this.cubit,
    super.key,
  });

  /// Initial render mode of the session.
  final CaptionRenderMode mode;

  /// Initial style preset id.
  final String presetId;

  /// BCP-47 recognition/caption language.
  final String languageTag;

  /// The editor's clips, transcribed when this is a fresh session.
  final List<DivineVideoClip> clips;

  /// Total composition duration, used to clamp cue timing.
  final Duration totalDuration;

  /// Existing cues when re-opening a session; `null` triggers generation.
  final List<CaptionCue>? initialCues;

  /// Whether the toolbar offers deleting the whole caption track.
  final bool canDeleteTrack;

  /// Test override for the session cubit (e.g. one built on a mocked
  /// generation service).
  @visibleForTesting
  final CaptionsEditorCubit? cubit;

  @override
  State<VideoCaptionsEditorScreen> createState() =>
      _VideoCaptionsEditorScreenState();
}

class _VideoCaptionsEditorScreenState extends State<VideoCaptionsEditorScreen> {
  late final CaptionsEditorCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit =
        widget.cubit ??
        CaptionsEditorCubit(
          clips: widget.clips,
          totalDuration: widget.totalDuration,
          mode: widget.mode,
          presetId: widget.presetId,
          languageTag: widget.languageTag,
          initialCues: widget.initialCues,
        );
    _cubit.initialize();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  void _confirm() {
    final state = _cubit.state;
    if (state.status == CaptionsEditorStatus.generating) return;
    // Cues whose text was cleared are dropped on confirm; they render as
    // nothing anyway and would only clutter the timeline and the VTT.
    final cues = [
      for (final cue in state.cues)
        if (cue.text.trim().isNotEmpty) cue,
    ];
    context.pop<CaptionsEditorResult>(
      CaptionsConfirmed(
        track: state.track.copyWith(
          cues: state.mode == CaptionRenderMode.overlay ? cues : const [],
        ),
        cues: cues,
      ),
    );
  }

  Future<void> _deleteTrack() async {
    final confirmed = await VineBottomSheetPrompt.show<bool>(
      context: context,
      sticker: .alert,
      title: context.l10n.videoEditorCaptionsDeleteTrackConfirmTitle,
      subtitle: context.l10n.videoEditorCaptionsDeleteTrackConfirmSubtitle,
      primaryButtonText: context.l10n.commonDelete,
      primaryButtonType: .error,
      secondaryButtonText: context.l10n.commonCancel,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );
    if (confirmed ?? false) {
      if (mounted) {
        context.pop<CaptionsEditorResult>(const CaptionsDeleted());
      }
    }
  }

  Future<void> _changePreset() async {
    final picked = await showCaptionPresetSheet(
      context,
      selectedId: _cubit.state.presetId,
    );
    if (picked != null) _cubit.setPreset(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocProvider.value(
      value: _cubit,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: VineTheme.transparent,
          systemNavigationBarColor: VineTheme.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: VineTheme.transparent,
          resizeToAvoidBottomInset: true,
          body: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: VineTheme.scrim65),
              SafeArea(
                child: Column(
                  children: [
                    VideoEditorToolbar(
                      closeIcon: widget.canDeleteTrack ? .trash : .x,
                      closeType: widget.canDeleteTrack
                          ? .error
                          : .ghostSecondary,
                      closeSemanticLabel: widget.canDeleteTrack
                          ? l10n.videoEditorCaptionsDeleteTrack
                          : l10n.videoEditorCaptionsCloseSemanticLabel,
                      doneSemanticLabel:
                          l10n.videoEditorCaptionsDoneSemanticLabel,
                      onClose: widget.canDeleteTrack
                          ? _deleteTrack
                          : context.pop,
                      onDone: _confirm,
                      center: Flexible(
                        child: Text(
                          l10n.videoEditorCaptionsEditTitle,
                          style: VineTheme.titleMediumFont(),
                        ),
                      ),
                    ),
                    Expanded(
                      child:
                          BlocBuilder<CaptionsEditorCubit, CaptionsEditorState>(
                            builder: (context, state) => switch (state.status) {
                              CaptionsEditorStatus.generating =>
                                const _GeneratingView(),
                              CaptionsEditorStatus.empty ||
                              CaptionsEditorStatus.failed => _FallbackView(
                                state: state,
                              ),
                              CaptionsEditorStatus.ready => _CueEditor(
                                state: state,
                                onChangePreset: _changePreset,
                              ),
                            },
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeneratingView extends StatelessWidget {
  const _GeneratingView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 16,
        children: [
          const CircularProgressIndicator(color: VineTheme.vineGreen),
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
      ),
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
      ),
    );
  }
}

class _CueEditor extends StatelessWidget {
  const _CueEditor({required this.state, required this.onChangePreset});

  final CaptionsEditorState state;
  final VoidCallback onChangePreset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.cues.length,
            itemBuilder: (context, index) => _CueRow(
              key: ValueKey(state.cues[index].id),
              cue: state.cues[index],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              spacing: 8,
              children: [
                DivineButton(
                  label: l10n.videoEditorCaptionsAddCue,
                  type: .secondary,
                  expanded: true,
                  onPressed: () => context.read<CaptionsEditorCubit>().addCue(),
                ),
                if (state.mode == CaptionRenderMode.burnIn)
                  DivineButton(
                    label:
                        '${l10n.videoEditorCaptionsPresetTitle}: '
                        '${captionPresetDisplayName(l10n, state.presetId)}',
                    type: .ghostSecondary,
                    expanded: true,
                    onPressed: onChangePreset,
                  ),
                DivineButton(
                  label: state.mode == CaptionRenderMode.burnIn
                      ? l10n.videoEditorCaptionsSwitchToOverlay
                      : l10n.videoEditorCaptionsSwitchToBurnIn,
                  type: .ghostSecondary,
                  expanded: true,
                  onPressed: () {
                    final cubit = context.read<CaptionsEditorCubit>();
                    cubit.setMode(
                      state.mode == CaptionRenderMode.burnIn
                          ? CaptionRenderMode.overlay
                          : CaptionRenderMode.burnIn,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CueRow extends StatelessWidget {
  const _CueRow({required this.cue, super.key});

  final CaptionCue cue;

  String get _timestampLabel {
    String format(Duration d) {
      final seconds = d.inMilliseconds / 1000;
      return seconds.toStringAsFixed(1);
    }

    return '${format(cue.start)}–${format(cue.end)}s';
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<CaptionsEditorCubit>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              _timestampLabel,
              style: VineTheme.bodySmallFont(color: VineTheme.secondaryText),
            ),
          ),
          Expanded(
            child: TextFormField(
              initialValue: cue.text,
              minLines: 1,
              maxLines: null,
              style: VineTheme.bodyMediumFont(),
              decoration: InputDecoration(
                hintText: context.l10n.videoEditorCaptionsCueTextHint,
              ),
              onChanged: (value) => cubit.updateCueText(cue.id, value),
            ),
          ),
          DivineIconButton(
            icon: .trash,
            type: .ghostSecondary,
            semanticLabel:
                context.l10n.videoEditorCaptionsCueDeleteSemanticLabel,
            onPressed: () => cubit.removeCue(cue.id),
          ),
        ],
      ),
    );
  }
}
