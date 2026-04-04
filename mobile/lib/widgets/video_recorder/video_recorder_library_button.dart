import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/screens/library_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    //TODO: FIXME: select first clip from library if empty
    final clips = ref.watch(clipManagerProvider.select((p) => p.clips));

    final currentPath = clips.lastOrNull?.thumbnailPath;
    if (currentPath != null) {
      _lastKnownThumbnailPath = currentPath;
    } else if (clips.isEmpty) {
      _lastKnownThumbnailPath = null;
    }

    final thumbnailPath = _lastKnownThumbnailPath;

    return Semantics(
      button: true,
      label: 'Open the clip library',
      child: InkWell(
        onTap: () => context.push(LibraryScreen.clipsPath),
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
              Align(
                alignment: .topRight,
                child: FractionalTranslation(
                  translation: const Offset(0.5, -0.5),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                    child: clips.isEmpty
                        ? const SizedBox.shrink()
                        : Container(
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            decoration: BoxDecoration(
                              color: VineTheme.error,
                              shape: .circle,
                              border: Border.all(
                                width: 2,
                                color: VineTheme.backgroundCamera,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  clips.length.toString(),
                                  textAlign: TextAlign.center,
                                  style: VineTheme.labelSmallFont().copyWith(
                                    fontFeatures: [
                                      const .tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
