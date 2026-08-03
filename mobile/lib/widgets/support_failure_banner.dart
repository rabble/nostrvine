// ABOUTME: Failure banner shared by the bug report and feature request sheets
// ABOUTME: Keeps a failed submission visible while the user retries

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Banner reporting a failed support submission.
///
/// Lives in the sheets' pinned footer: the form stays open on failure, so the
/// reason has to stay visible no matter how far the form is scrolled. Success
/// takes the opposite route — it closes the sheet and confirms via snackbar.
class SupportFailureBanner extends StatelessWidget {
  const SupportFailureBanner({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: VineTheme.error.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: VineTheme.error),
        ),
        child: Text(
          message,
          style: VineTheme.bodyMediumFont(color: VineTheme.error),
        ),
      ),
    );
  }
}
