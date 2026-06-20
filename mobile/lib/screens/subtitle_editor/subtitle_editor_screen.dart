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
      return const Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        body: Center(
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
      backgroundColor: VineTheme.surfaceBackground,
      appBar: DiVineAppBar(
        title: l10n.subtitleEditorTitle,
        backgroundColor: VineTheme.surfaceBackground,
        showBackButton: true,
        onBackPressed: context.pop,
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
            context.pop();
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
          SubtitleEditorStatus.processing => const _Processing(),
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

class _Processing extends StatelessWidget {
  const _Processing();

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
            l10n.subtitleEditorProcessing,
            textAlign: TextAlign.center,
            style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
          ),
          TextButton(
            onPressed: () => context.read<SubtitleEditorCubit>().load(),
            child: Text(l10n.subtitleEditorRetry),
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
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.cues.length,
            itemBuilder: (context, index) =>
                _CueRow(index: index, cue: state.cues[index]),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _SaveButton(
              enabled:
                  state.isDirty && state.status != SubtitleEditorStatus.saving,
              busy: state.status == SubtitleEditorStatus.saving,
            ),
          ),
        ),
      ],
    );
  }
}

class _CueRow extends StatelessWidget {
  const _CueRow({required this.index, required this.cue});

  final int index;
  final EditableCue cue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              cue.timestampLabel,
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
                hintText: context.l10n.subtitleEditorCueHint,
              ),
              onChanged: (value) => context
                  .read<SubtitleEditorCubit>()
                  .updateCueText(index, value),
            ),
          ),
        ],
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
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled
            ? () => context.read<SubtitleEditorCubit>().save()
            : null,
        child: busy
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(context.l10n.subtitleEditorSave),
      ),
    );
  }
}
