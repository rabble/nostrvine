import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';

class VideoRecorderLibraryButton extends ConsumerStatefulWidget {
  const VideoRecorderLibraryButton({super.key});

  @override
  ConsumerState<VideoRecorderLibraryButton> createState() =>
      _VideoRecorderLibraryButtonState();
}

class _VideoRecorderLibraryButtonState
    extends ConsumerState<VideoRecorderLibraryButton> {
  /// Last non-null thumbnail path seen, used as fallback while a new clip's
  /// thumbnail is still being generated (~1 s delay).
  String? _lastKnownThumbnailPath;

  /// Thumbnail path from the persisted clip library, loaded on demand.
  String? _libraryThumbnailPath;

  @override
  void initState() {
    super.initState();
    _loadLibraryThumbnail();
  }

  Future<void> _loadLibraryThumbnail() async {
    final service = ref.read(clipLibraryServiceProvider);
    final libraryClips = await service.getAllClips();
    if (!mounted) return;
    setState(() {
      _libraryThumbnailPath = libraryClips.isNotEmpty
          ? libraryClips.first.thumbnailPath
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final clips = ref.watch(clipManagerProvider.select((p) => p.clips));

    // Re-query library thumbnail whenever session clips change to empty
    // (e.g. user reset or deleted clips).
    ref.listen(
      clipManagerProvider.select((p) => p.clips.length),
      (previous, next) {
        if (next == 0) _loadLibraryThumbnail();
      },
    );

    final currentPath = clips.lastOrNull?.thumbnailPath;
    if (currentPath != null) {
      _lastKnownThumbnailPath = currentPath;
    } else if (clips.isEmpty) {
      _lastKnownThumbnailPath = null;
    }

    final thumbnailPath = _lastKnownThumbnailPath ?? _libraryThumbnailPath;

    return Semantics(
      button: true,
      label: thumbnailPath == null
          ? 'Clip library, no clips'
          : 'Open clip library, ${clips.length} '
                'clip${clips.length == 1 ? '' : 's'}',
      enabled: clips.isNotEmpty,
      child: InkWell(
        onTap: thumbnailPath == null
            ? null
            : () async {
                await ref
                    .read(videoRecorderProvider.notifier)
                    .openLibrary(context);

                // Refresh library thumbnail after returning — user may have
                // deleted clips or new thumbnails may have been recovered.
                _loadLibraryThumbnail();
              },
        child: Container(
          margin: const .only(left: 16),
          width: 40,
          height: 40,
          decoration: ShapeDecoration(
            color: VineTheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 2, color: VineTheme.onSurface),
              borderRadius: .circular(16),
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: .circular(14),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                  layoutBuilder: (currentChild, previousChildren) => Stack(
                    alignment: .center,
                    fit: .expand,
                    children: [...previousChildren, ?currentChild],
                  ),
                  child: thumbnailPath != null
                      ? Image.file(
                          File(thumbnailPath),
                          key: ValueKey(thumbnailPath),
                          fit: BoxFit.cover,
                        )
                      : const SizedBox.shrink(),
                ),
              ),

              _SelectionCountBadge(count: clips.length),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionCountBadge extends StatelessWidget {
  const _SelectionCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: .topRight,
      child: FractionalTranslation(
        translation: const Offset(0.5, -0.5),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: child,
          ),
          child: count == 0
              ? const SizedBox.shrink()
              : Container(
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  padding: const .symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: VineTheme.error,
                    shape: .circle,
                    border: .all(width: 2, color: VineTheme.backgroundCamera),
                  ),
                  child: Column(
                    mainAxisSize: .min,
                    mainAxisAlignment: .center,
                    children: [
                      MediaQuery.withNoTextScaling(
                        child: Text(
                          count.toString(),
                          textAlign: .center,
                          style: VineTheme.labelSmallFont().copyWith(
                            fontFeatures: [
                              const .tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
