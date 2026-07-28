// ABOUTME: Full-screen overlay shown when the active video has a 401/403
// ABOUTME: playback failure. Replaces the normal interactive feed overlay.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';
import 'package:openvine/l10n/l10n.dart';

/// Displayed in place of the normal feed overlay when the active video's
/// [PlaybackStatus] is [PlaybackStatus.forbidden] or
/// [PlaybackStatus.ageRestricted].
///
/// This widget is only valid for [PlaybackStatus.forbidden] and
/// [PlaybackStatus.ageRestricted]. Other values throw an assertion in debug
/// builds.
///
/// When [status] is [PlaybackStatus.ageRestricted], [onVerifyAge] MUST be
/// provided so the primary CTA can be wired to the caller's auth flow.
class ModeratedContentOverlay extends StatelessWidget {
  const ModeratedContentOverlay({
    required this.status,
    required this.onSkip,
    this.onVerifyAge,
    this.isVerifying = false,
    super.key,
  }) : assert(
         status == PlaybackStatus.forbidden ||
             status == PlaybackStatus.ageRestricted,
         'ModeratedContentOverlay only supports forbidden and ageRestricted',
       ),
       assert(
         status != PlaybackStatus.ageRestricted || onVerifyAge != null,
         'onVerifyAge must be provided when status is ageRestricted',
       );

  /// The reason the video cannot be played.
  final PlaybackStatus status;

  /// Called when the user taps Skip.
  final VoidCallback onSkip;

  /// Called when the user taps Verify age. Must be non-null when [status]
  /// is [PlaybackStatus.ageRestricted] — enforced by an assertion.
  final VoidCallback? onVerifyAge;

  /// Whether an age-verification retry is in flight. Shows the Verify age
  /// button's loading state (which also disables it, preventing double taps).
  final bool isVerifying;

  bool get _isAgeRestricted => status == PlaybackStatus.ageRestricted;

  @override
  Widget build(BuildContext context) {
    final icon = _isAgeRestricted
        ? DivineIconName.lockSimple
        : DivineIconName.shieldCheck;
    final title = _isAgeRestricted
        ? context.l10n.videoErrorAgeRestricted
        : context.l10n.videoErrorContentRestricted;
    final body = _isAgeRestricted
        ? context.l10n.videoErrorVerifyAgeBody
        : context.l10n.videoErrorContentRestrictedBody;

    return ColoredBox(
      color: context.vineColors.background,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                DivineIcon(icon: icon, color: VineTheme.whiteText, size: 64),
                Text(
                  title,
                  style: VineTheme.titleMediumFont(color: VineTheme.whiteText),
                  textAlign: TextAlign.center,
                ),
                Text(
                  body,
                  style: VineTheme.bodyMediumFont(color: VineTheme.whiteText),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                if (_isAgeRestricted && onVerifyAge != null)
                  DivineButton(
                    label: context.l10n.videoErrorVerifyAgeButton,
                    // Disabled while a retry is in flight so a second tap
                    // can't kick off a duplicate verification.
                    onPressed: isVerifying ? null : onVerifyAge,
                    isLoading: isVerifying,
                  ),
                DivineButton(
                  label: context.l10n.videoErrorSkip,
                  type: DivineButtonType.tertiary,
                  onPressed: onSkip,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
