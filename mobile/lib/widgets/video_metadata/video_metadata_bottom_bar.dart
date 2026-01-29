import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/providers/video_editor_provider.dart';

/// Bottom bar with "Save draft" and "Post" buttons for video metadata.
///
/// Buttons are disabled with reduced opacity when metadata is invalid.
class VideoMetadataBottomBar extends StatelessWidget {
  /// Creates a video metadata bottom bar.
  const VideoMetadataBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: .fromLTRB(16, 0, 16, 4),
      child: Row(
        crossAxisAlignment: .end,
        spacing: 16,
        children: [
          // TODO(@hm21): Once the Drafts library exists, uncomment the Drafts button again.
          // Expanded(child: _SaveDraftButton()),
          Expanded(child: _PostButton()),
        ],
      ),
    );
  }
}

/// Outlined button to save the video as a draft.
/* class _SaveDraftButton extends ConsumerWidget {
  /// Creates a save draft button.
  const _SaveDraftButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSaving = ref.watch(
      videoEditorProvider.select((s) => s.isSavingDraft),
    );

    return Semantics(
      // TODO(l10n): Replace with context.l10n when localization is added.
      label: 'Save draft button',
      hint: isSaving ? 'Saving draft...' : 'Save video as draft',
      button: true,
      enabled: !isSaving,
      child: GestureDetector(
        onTap: isSaving ? null : () => _onSaveDraft(context, ref),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isSaving ? 0.6 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              color: VineTheme.surfaceContainer,
              border: .all(color: Color(0xFF0E2B21), width: 2),
              borderRadius: .circular(20),
            ),
            padding: const .symmetric(vertical: 10),
            child: Center(
              child: isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: VineTheme.primary,
                      ),
                    )
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  : Text(
                      'Save draft',
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 18,
                        fontWeight: .w800,
                        color: VineTheme.primary,
                        height: 1.33,
                        letterSpacing: 0.15,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSaveDraft(BuildContext context, WidgetRef ref) async {
    final success = await ref.read(videoEditorProvider.notifier).saveAsDraft();

    if (!context.mounted) return;

    // Store router reference before showing SnackBar, as context may become
    // invalid after navigate to the home page.
    final router = GoRouter.of(context);

    // TODO(@hm21): Update after new final snackbar-design is implemented.
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      SnackBar(
        duration: Duration(seconds: 5),
        shape: RoundedRectangleBorder(borderRadius: .circular(16)),
        content: Row(
          children: [
            Expanded(
              child: Text(
                // TODO(l10n): Replace with context.l10n when localization is added.
                success ? 'Draft has been saved!' : 'Failed to save draft',
                style: VineTheme.bodyFont(
                  fontSize: 14,
                  fontWeight: .w600,
                  height: 1.43,
                  letterSpacing: 0.1,
                  color: VineTheme.whiteText,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                scaffoldMessenger.hideCurrentSnackBar();
                router.push(ClipLibraryScreen.draftsPath);
              },
              style: TextButton.styleFrom(
                padding: .symmetric(horizontal: 8),
                minimumSize: .zero,
                tapTargetSize: .shrinkWrap,
              ),
              child: Text(
                // TODO(l10n): Replace with context.l10n when localization is added.
                'Go to Library',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 18,
                  fontWeight: .w800,
                  height: 1.33,
                  letterSpacing: 0.15,
                  color: VineTheme.primary,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Color(0xFF000A06),
        behavior: .floating,
      ),
    );

    if (success) {
      ref.read(videoPublishProvider.notifier).cleanupAfterPublish();
      context.goHome();
    }
  }
}
 */
/// Filled button to publish the video to the feed.
class _PostButton extends ConsumerWidget {
  /// Creates a post button.
  const _PostButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isValidToPost = ref.watch(
      videoEditorProvider.select((s) => s.isValidToPost),
    );

    // Fade buttons when form is invalid
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isValidToPost ? 1 : 0.32,
      child: Semantics(
        // TODO(l10n): Replace with context.l10n when localization is added.
        label: 'Post button',
        hint: isValidToPost
            ? 'Publish video to feed'
            : 'Fill out the form to enable',
        button: true,
        enabled: isValidToPost,
        child: GestureDetector(
          onTap: isValidToPost
              ? () => ref.read(videoEditorProvider.notifier).postVideo(context)
              : null,
          child: Container(
            decoration: BoxDecoration(
              color: VineTheme.primary,
              borderRadius: .circular(20),
            ),
            padding: const .symmetric(vertical: 12),
            child: Center(
              // TODO(l10n): Replace with context.l10n when localization is added.
              child: Text(
                'Post',
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 18,
                  fontWeight: .w800,
                  color: const Color(0xFF002C1C),
                  height: 1.33,
                  letterSpacing: 0.15,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
