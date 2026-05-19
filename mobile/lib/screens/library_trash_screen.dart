// ABOUTME: Trash bin screen for soft-deleted clips with restore + purge actions
// ABOUTME: Loads trashed clips on entry and lets the user restore or delete now.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:openvine/widgets/video_clip/video_clip_thumbnail_card.dart';

/// Screen showing clips that have been soft-deleted and are awaiting
/// 30-day auto-purge. The user can [Restore] a clip back to the
/// library or [Delete now] to skip the retention window.
class LibraryTrashScreen extends StatefulWidget {
  const LibraryTrashScreen({super.key});

  @override
  State<LibraryTrashScreen> createState() => _LibraryTrashScreenState();
}

class _LibraryTrashScreenState extends State<LibraryTrashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ClipsLibraryBloc>().add(
        const ClipsLibraryTrashLoadRequested(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      appBar: AppBar(
        backgroundColor: VineTheme.surfaceBackground,
        elevation: 0,
        leading: const _BackButton(),
        title: Text(
          context.l10n.libraryTrashTitle,
          style: VineTheme.titleMediumFont(),
        ),
        actions: const [_EmptyTrashAction()],
      ),
      body: SafeArea(
        child: BlocBuilder<ClipsLibraryBloc, ClipsLibraryState>(
          buildWhen: (prev, curr) =>
              prev.trashedClips != curr.trashedClips ||
              prev.status != curr.status,
          builder: (context, state) {
            if (state.status == ClipsLibraryStatus.trashLoading &&
                state.trashedClips.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: VineTheme.vineGreen),
              );
            }
            if (state.trashedClips.isEmpty) {
              return EmptyLibraryState(
                icon: DivineIconName.trash,
                title: context.l10n.libraryTrashEmptyTitle,
                subtitle: context.l10n.libraryTrashEmptySubtitle,
                showRecordButton: false,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: state.trashedClips.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _TrashedClipTile(clip: state.trashedClips[index]),
            );
          },
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: DivineIconButton(
        size: DivineIconButtonSize.small,
        type: DivineIconButtonType.secondary,
        icon: DivineIconName.caretLeft,
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

class _EmptyTrashAction extends StatelessWidget {
  const _EmptyTrashAction();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ClipsLibraryBloc, ClipsLibraryState, bool>(
      selector: (state) => state.trashedClips.isNotEmpty,
      builder: (context, hasTrashed) {
        if (!hasTrashed) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: DivineButton(
              size: DivineButtonSize.small,
              type: DivineButtonType.secondary,
              label: context.l10n.libraryTrashEmptyAllLabel,
              onPressed: () => context.read<ClipsLibraryBloc>().add(
                const ClipsLibraryEmptyTrash(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrashedClipTile extends StatelessWidget {
  const _TrashedClipTile({required this.clip});

  final DivineVideoClip clip;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: VineTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          spacing: 12,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                child: VideoClipThumbnailCard(
                  clip: clip,
                  showSelectionIndicator: false,
                  onTap: () {},
                  onLongPress: () {},
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 4,
                children: [
                  Text(
                    '${clip.duration.inSeconds}s',
                    style: VineTheme.titleSmallFont(),
                  ),
                  Text(
                    _formatRecordedAt(context, clip.recordedAt),
                    style: VineTheme.bodyMediumFont(
                      color: VineTheme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                DivineButton(
                  size: DivineButtonSize.small,
                  type: DivineButtonType.secondary,
                  label: context.l10n.libraryTrashRestoreLabel,
                  onPressed: () => context.read<ClipsLibraryBloc>().add(
                    ClipsLibraryRestoreClips({clip.id}),
                  ),
                ),
                DivineButton(
                  size: DivineButtonSize.small,
                  type: DivineButtonType.error,
                  label: context.l10n.libraryTrashDeleteNowLabel,
                  onPressed: () => context.read<ClipsLibraryBloc>().add(
                    ClipsLibraryHardDeleteClip(clip),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatRecordedAt(BuildContext context, DateTime recordedAt) {
    final localized = MaterialLocalizations.of(context);
    return localized.formatMediumDate(recordedAt);
  }
}
