// ABOUTME: Full-screen editor for correcting a video's subtitle text.
// ABOUTME: Page builds the cubit from Riverpod; View renders cue text fields.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/subtitle_editor/subtitle_editor_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/subtitle_repository_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/router/route_error_screen.dart';

/// Full-screen subtitle editor page.
///
/// The screen is keyed on [videoId] so it can be rebuilt from the route alone.
/// A [prefetched] video may be passed as a fast path when navigating from a
/// feed or metadata screen, but route state is not required for correctness.
class SubtitleEditorScreen extends ConsumerStatefulWidget {
  /// Creates the subtitle editor page for [videoId].
  const SubtitleEditorScreen({
    required this.videoId,
    this.prefetched,
    super.key,
  });

  /// Base route path.
  static const path = '/subtitle-edit';

  /// GoRouter route name.
  static const routeName = 'subtitle-edit';

  /// Returns the full path for a given video id.
  static String pathFor(String videoId) =>
      '$path/${Uri.encodeComponent(videoId)}';

  /// The event id of the video whose subtitles are being edited.
  final String videoId;

  /// Optional prefetched video used to avoid an async resolve on push.
  final VideoEvent? prefetched;

  @override
  ConsumerState<SubtitleEditorScreen> createState() =>
      _SubtitleEditorScreenState();
}

class _SubtitleEditorScreenState extends ConsumerState<SubtitleEditorScreen> {
  VideoEvent? _resolved;
  bool _resolveFailed = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefetched != null && widget.prefetched!.id == widget.videoId) {
      _resolved = widget.prefetched;
    } else {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final resolver = ref.read(videoEventResolverProvider);
    final video = await resolver.resolveById(
      widget.videoId,
      allowOwnContentBypass: true,
    );
    if (!mounted) return;
    setState(() {
      _resolved = video;
      _resolveFailed = video == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final video = _resolved;
    if (video == null) {
      if (_resolveFailed) {
        return RouteErrorScreen(message: context.l10n.routeInvalidVideoId);
      }
      return Scaffold(
        backgroundColor: context.vineColors.background,
        body: const Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      );
    }

    final repository = ref.watch(subtitleRepositoryProvider);
    return BlocProvider<SubtitleEditorCubit>(
      key: ObjectKey(repository),
      create: (_) =>
          SubtitleEditorCubit(repository: repository, video: video)..load(),
      child: const SubtitleEditorView(),
    );
  }
}

/// Renders the subtitle editor UI.
///
/// Expects a [SubtitleEditorCubit] ancestor provided by [SubtitleEditorScreen].
@visibleForTesting
class SubtitleEditorView extends StatelessWidget {
  /// Creates the subtitle editor view.
  const SubtitleEditorView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: context.vineColors.surface,
      appBar: DiVineAppBar(
        title: l10n.subtitleEditorTitle,
        backgroundColor: context.vineColors.surface,
        showBackButton: true,
        onBackPressed: context.safePop,
      ),
      body: BlocConsumer<SubtitleEditorCubit, SubtitleEditorState>(
        listenWhen: (previous, current) => previous.status != current.status,
        listener: (context, state) {
          if (state.status == SubtitleEditorStatus.success) {
            SemanticsService.sendAnnouncement(
              View.of(context),
              l10n.subtitleEditorSaveSuccess,
              Directionality.of(context),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.subtitleEditorSaveSuccess)),
            );
            context.pop(state.updatedVideo);
          } else if (state.status == SubtitleEditorStatus.failure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.cues.isEmpty
                      ? l10n.subtitleEditorLoadError
                      : l10n.subtitleEditorSaveError,
                ),
              ),
            );
          }
        },
        builder: (context, state) => switch (state.status) {
          SubtitleEditorStatus.loading => const _Loading(),
          // Transcription is still running, so writing captions now would
          // race the result. Wait or re-check, but don't offer authoring.
          SubtitleEditorStatus.processing => _NoCues(
            message: l10n.subtitleEditorProcessing,
          ),
          SubtitleEditorStatus.empty => _NoCues(
            message: l10n.subtitleEditorNoSpeech,
            canWriteOwn: true,
          ),
          SubtitleEditorStatus.unavailable => _NoCues(
            message: l10n.subtitleEditorLoadError,
            canWriteOwn: true,
          ),
          // A failure with nothing loaded is a failed load: the snackbar
          // fades, so the reason has to stay on screen. A failure with cues
          // is a failed save, and those cues are the creator's work — keep
          // the list.
          SubtitleEditorStatus.failure when state.cues.isEmpty => _NoCues(
            message: l10n.subtitleEditorLoadError,
            canWriteOwn: true,
          ),
          _ => _CueList(state: state),
        },
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Explains why there is nothing to edit, and offers a way forward.
///
/// When [canWriteOwn] is set there will be no auto-generated track to wait
/// for, so the creator is offered the chance to author captions by hand.
class _NoCues extends StatelessWidget {
  const _NoCues({required this.message, this.canWriteOwn = false});

  final String message;
  final bool canWriteOwn;

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
            message,
            textAlign: TextAlign.center,
            style: VineTheme.bodyMediumFont(
              color: context.vineColors.secondaryText,
            ),
          ),
          if (canWriteOwn)
            DivineButton(
              label: l10n.subtitleEditorWriteOwn,
              leadingIcon: DivineIconName.plus,
              onPressed: () => context.read<SubtitleEditorCubit>().addCue(),
            ),
          DivineButton(
            label: l10n.subtitleEditorRetry,
            type: DivineButtonType.link,
            onPressed: () => context.read<SubtitleEditorCubit>().load(),
          ),
        ],
      ),
    );
  }
}

class _CueList extends StatelessWidget {
  const _CueList({required this.state});

  final SubtitleEditorState state;

  @override
  Widget build(BuildContext context) {
    final saving = state.status == SubtitleEditorStatus.saving;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            // One trailing slot for the add action, so authoring a caption
            // stays reachable from the bottom of a long list.
            itemCount: state.cues.length + 1,
            itemBuilder: (context, index) => index == state.cues.length
                ? _AddCueButton(enabled: state.canAddCue && !saving)
                : _CueRow(index: index, cue: state.cues[index]),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                if (state.isDirty && !state.isValid)
                  Text(
                    context.l10n.subtitleEditorInvalidHint,
                    textAlign: TextAlign.center,
                    style: VineTheme.bodySmallFont(
                      color: context.vineColors.secondaryText,
                    ),
                  ),
                _SaveButton(
                  enabled: state.isDirty && state.isValid && !saving,
                  busy: saving,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Appends a cue to the end of the list.
///
/// Disabled once the cues already reach the end of the video: a line past
/// the end would never play, so there is nothing left to caption.
class _AddCueButton extends StatelessWidget {
  const _AddCueButton({required this.enabled});

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DivineButton(
        label: context.l10n.subtitleEditorAddCue,
        type: DivineButtonType.secondary,
        leadingIcon: DivineIconName.plus,
        onPressed: enabled
            ? () => context.read<SubtitleEditorCubit>().addCue()
            : null,
      ),
    );
  }
}

class _CueRow extends StatelessWidget {
  const _CueRow({required this.index, required this.cue});

  final int index;
  final EditableCue cue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<SubtitleEditorCubit>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Row(
            spacing: 8,
            children: [
              _TimeField(
                label: l10n.subtitleEditorStartLabel,
                milliseconds: cue.start,
                onChanged: (value) =>
                    cubit.updateCueTiming(index, start: value),
              ),
              Text(
                '–',
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.secondaryText,
                ),
              ),
              _TimeField(
                label: l10n.subtitleEditorEndLabel,
                milliseconds: cue.end,
                onChanged: (value) => cubit.updateCueTiming(index, end: value),
              ),
              const Spacer(),
              DivineIconButton(
                icon: DivineIconName.trash,
                type: DivineIconButtonType.ghostSecondary,
                size: DivineIconButtonSize.small,
                semanticLabel: l10n.subtitleEditorRemoveCue,
                onPressed: () => cubit.removeCue(index),
              ),
            ],
          ),
          _CueTextField(
            text: cue.text,
            onChanged: (value) => cubit.updateCueText(index, value),
          ),
        ],
      ),
    );
  }
}

/// Text field for a cue's caption line.
///
/// Owns its controller so the list can grow and shrink: rows are positional,
/// so removing a cue slides its successor into the same element and the
/// controller has to pick up the new text.
class _CueTextField extends StatefulWidget {
  const _CueTextField({required this.text, required this.onChanged});

  final String text;
  final ValueChanged<String> onChanged;

  @override
  State<_CueTextField> createState() => _CueTextFieldState();
}

class _CueTextFieldState extends State<_CueTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.text,
  );

  @override
  void didUpdateWidget(_CueTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only when the value changed underneath us — comparing first keeps the
    // caret still while the creator types.
    if (widget.text != _controller.text) _controller.text = widget.text;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      minLines: 1,
      maxLines: null,
      style: VineTheme.bodyMediumFont(color: context.vineColors.primaryText),
      decoration: InputDecoration(hintText: context.l10n.subtitleEditorCueHint),
      onChanged: widget.onChanged,
    );
  }
}

/// Compact seconds field for one end of a cue's timing.
class _TimeField extends StatefulWidget {
  const _TimeField({
    required this.label,
    required this.milliseconds,
    required this.onChanged,
  });

  final String label;
  final int milliseconds;
  final ValueChanged<int> onChanged;

  @override
  State<_TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<_TimeField> {
  late final TextEditingController _controller = TextEditingController(
    text: _format(widget.milliseconds),
  );
  late final FocusNode _focusNode = FocusNode()..addListener(_onFocusChanged);

  static String _format(int milliseconds) =>
      (milliseconds / Duration.millisecondsPerSecond).toStringAsFixed(1);

  static int? _parse(String value) {
    final seconds = double.tryParse(value.replaceAll(',', '.'));
    if (seconds == null || seconds.isNegative || !seconds.isFinite) return null;
    return (seconds * Duration.millisecondsPerSecond).round();
  }

  // Unparseable input — a cleared field, a lone "-" — never reaches the cubit,
  // so the field would sit showing a value the cue does not hold and publish
  // the old one. Restore what the cue actually holds once editing ends.
  void _onFocusChanged() {
    if (_focusNode.hasFocus) return;
    final committed = _format(widget.milliseconds);
    if (_controller.text != committed) _controller.text = committed;
  }

  @override
  void didUpdateWidget(_TimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Resync on the parsed value, not the raw text: a half-typed "1." already
    // means 1.0, and rewriting it would jump the caret mid-entry.
    if (_parse(_controller.text) != widget.milliseconds) {
      _controller.text = _format(widget.milliseconds);
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Semantics(
        label: widget.label,
        textField: true,
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.end,
          style: VineTheme.bodySmallFont(color: context.vineColors.primaryText),
          decoration: InputDecoration(
            isDense: true,
            suffixText: 's',
            suffixStyle: VineTheme.bodySmallFont(
              color: context.vineColors.secondaryText,
            ),
          ),
          onChanged: (value) {
            final parsed = _parse(value);
            if (parsed != null) widget.onChanged(parsed);
          },
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.enabled, required this.busy});

  final bool enabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      label: context.l10n.subtitleEditorSave,
      expanded: true,
      isLoading: busy,
      onPressed: enabled
          ? () => context.read<SubtitleEditorCubit>().save()
          : null,
    );
  }
}
