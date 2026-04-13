// ABOUTME: Full-screen overlay shown when the active video has a 401/403
// ABOUTME: playback failure. Replaces the normal FeedVideoOverlay entirely.

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
      color: VineTheme.backgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                DivineIcon(
                  icon: icon,
                  color: VineTheme.whiteText,
                  size: 64,
                ),
                Text(
                  title,
                  style: VineTheme.titleMediumFont(),
                  textAlign: TextAlign.center,
                ),
                Text(
                  body,
                  style: VineTheme.bodyMediumFont(),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                if (_isAgeRestricted && onVerifyAge != null)
                  DivineButton(
                    label: context.l10n.videoErrorVerifyAgeButton,
                    onPressed: onVerifyAge,
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

/// User-facing copy for [ModeratedContentOverlay].
///
/// Kept as static constants so tests can reference the same values the
/// widget renders, preventing drift when copy changes. When l10n lands,
/// these become the keys fed into the localizer.
@visibleForTesting
class ModeratedContentOverlayStrings {
  const ModeratedContentOverlayStrings._();

  static const String forbiddenTitle = 'Content restricted';
  static const String forbiddenBody = 'This video was restricted by the relay.';
  static const String ageRestrictedTitle = 'Age-restricted content';
  static const String ageRestrictedBody = 'Verify your age to view this video.';
  static const String skipLabel = 'Skip';
  static const String verifyAgeLabel = 'Verify age';
}
