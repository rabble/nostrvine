// ABOUTME: Top bar with close, clip counter, and done buttons
// ABOUTME: Displays current clip position and total clip count

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/video_recorder_screen.dart';

/// Top bar with close button, clip counter, and done button.
class VideoEditorTopBar extends ConsumerWidget {
  /// Creates a video editor top bar widget.
  const VideoEditorTopBar({super.key, this.fromLibrary = false});

  /// Whether the editor was opened from the clip library.
  final bool fromLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalClips = ref.watch(
      clipManagerProvider.select((state) => state.clips.length),
    );
    final state = ref.watch(
      videoEditorProvider.select(
        (s) => (
          currentClipIndex: s.currentClipIndex,
          isEditing: s.isEditing,
          isReordering: s.isReordering,
        ),
      ),
    );

    return Padding(
      padding: const .all(16),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: state.isReordering
                  ? const SizedBox.shrink()
                  : state.isEditing
                  ? Align(
                      alignment: .centerLeft,
                      child: _CloseButton(
                        onTap: ref
                            .read(videoEditorProvider.notifier)
                            .stopClipEditing,
                      ),
                    )
                  : _BackToCameraButton(
                      onTap: () async {
                        // If came from library, go to recorder (not in stack)
                        // Otherwise pop back to recorder
                        if (fromLibrary) {
                          context.pushReplacement(VideoRecorderScreen.path);
                        } else {
                          context.pop();
                        }
                      },
                    ),
            ),

            // Clip counter
            Text(
              '${state.currentClipIndex + 1}/$totalClips',
              style: GoogleFonts.bricolageGrotesque(
                color: Colors.white,
                fontSize: 18,
                height: 1.33,
                letterSpacing: 0.15,
                fontWeight: .w800,
                fontFeatures: [const .tabularFigures()],
              ),
            ),

            Expanded(
              child: state.isEditing || state.isReordering
                  ? const SizedBox.shrink()
                  : Align(
                      alignment: .centerRight,
                      child: _NextButton(
                        onTap: () {
                          unawaited(
                            ref
                                .read(videoEditorProvider.notifier)
                                .startRenderVideo(),
                          );
                          unawaited(context.pushVideoMetadata());
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackToCameraButton extends StatelessWidget {
  const _BackToCameraButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // TODO(l10n): Replace with context.l10n when localization is added.
      label: 'Go back to camera',
      child: GestureDetector(
        behavior: .opaque,
        onTap: onTap,
        child: Row(
          spacing: 6,
          children: [
            SizedBox(
              height: 32,
              width: 32,
              child: SvgPicture.asset(
                'assets/icon/CaretLeft.svg',
                colorFilter: const ColorFilter.mode(Colors.white, .srcIn),
              ),
            ),
            SizedBox(
              height: 32,
              width: 32,
              child: SvgPicture.asset(
                'assets/icon/video_camera.svg',
                colorFilter: const ColorFilter.mode(Colors.white, .srcIn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // TODO(l10n): Replace with context.l10n when localization is added.
      label: 'Close video editor',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          height: 32,
          width: 32,
          child: SvgPicture.asset(
            'assets/icon/close.svg',
            colorFilter: const ColorFilter.mode(Colors.white, .srcIn),
          ),
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  const _NextButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // TODO(l10n): Replace with context.l10n when localization is added.
      label: 'Continue to metadata',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const .symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: .circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(1, 1),
                blurRadius: 1,
              ),
              BoxShadow(
                color: Color(0x1A000000),
                offset: Offset(0.4, 0.4),
                blurRadius: 0.6,
              ),
            ],
          ),
          child: Text(
            // TODO(l10n): Replace with context.l10n when localization is added.
            'Next',
            style: GoogleFonts.bricolageGrotesque(
              fontSize: 18,
              fontWeight: .w800,
              height: 1.33,
              letterSpacing: 0.15,
              color: const Color(0xFF00452D),
            ),
          ),
        ),
      ),
    );
  }
}
