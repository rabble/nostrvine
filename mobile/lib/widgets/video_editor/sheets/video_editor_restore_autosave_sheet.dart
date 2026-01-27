// ABOUTME: Bottom sheet asking user to restore autosaved video editing session
// ABOUTME: Shows warning icon with restore/discard options

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:divine_ui/divine_ui.dart';

/// Bottom sheet displayed when an autosaved editing session is detected.
///
/// Asks the user whether they want to restore their previous work or
/// start fresh. Returns `true` if restore is selected, `false` if discarded.
class VideoEditorRestoreAutosaveSheet extends StatelessWidget {
  /// Creates a restore autosave sheet.
  const VideoEditorRestoreAutosaveSheet({this.lastSavedAt, super.key});

  /// Optional timestamp of when the autosave was created.
  final DateTime? lastSavedAt;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const .fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: .stretch,
        mainAxisSize: .min,
        children: [
          const _WarningIcon(),
          const SizedBox(height: 16),

          const _Title(),
          const SizedBox(height: 16),

          const _Description(),
          const SizedBox(height: 32),

          const _RestoreButton(),
          const SizedBox(height: 16),

          const _DiscardButton(),
        ],
      ),
    );
  }
}

class _WarningIcon extends StatelessWidget {
  const _WarningIcon();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icon/video_clap_board.png',
      width: 132,
      height: 132,
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Text(
      // TODO(l10n): Replace with context.l10n when localization is added.
      'We found work in progress',
      style: GoogleFonts.bricolageGrotesque(
        color: VineTheme.onSurface,
        fontWeight: .w700,
        fontSize: 24,
        height: 1.33,
      ),
      textAlign: .center,
    );
  }
}

class _Description extends StatelessWidget {
  const _Description();

  @override
  Widget build(BuildContext context) {
    return Text(
      // TODO(l10n): Replace with context.l10n when localization is added.
      'Would you like to continue where you left off?',
      style: VineTheme.bodyFont(
        color: VineTheme.onSurface,
        fontSize: 16,
        height: 1.5,
        letterSpacing: 0.15,
        fontWeight: .w400,
      ),
      textAlign: .center,
    );
  }
}

class _RestoreButton extends ConsumerWidget {
  const _RestoreButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: () {
        ref.read(videoEditorProvider.notifier).restoreDraft();
        context.pop();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: VineTheme.vineGreen,
        foregroundColor: Colors.white,
        padding: const .symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: .circular(20)),
      ),
      child: Text(
        // TODO(l10n): Replace with context.l10n when localization is added.
        'Yes, continue',
        textAlign: .center,
        style: VineTheme.titleFont(
          color: const Color(0xFF00150D),
          fontSize: 18,
          height: 1.33,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}

class _DiscardButton extends ConsumerWidget {
  const _DiscardButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton(
      onPressed: () {
        context.pop();
        ref.read(videoEditorProvider.notifier).removeAutosavedDraft();
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: Color(0xFF032017),
        side: BorderSide(width: 2, color: const Color(0xFF0E2B21)),
        padding: const .symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: .circular(20)),
      ),
      child: Text(
        // TODO(l10n): Replace with context.l10n when localization is added.
        'No, start a new video',
        textAlign: .center,
        style: VineTheme.titleFont(
          color: const Color(0xFF27C58B),
          fontSize: 18,
          height: 1.33,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}
