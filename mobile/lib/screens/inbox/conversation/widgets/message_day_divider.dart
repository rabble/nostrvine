// ABOUTME: Centered date pill separating calendar days in a DM thread.
// ABOUTME: Labels resolve via LocalizedTimeFormatter.formatDateLabel.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';

/// The DM redesign's timeline divider: a small centered pill reading
/// "Today", "Yesterday", a weekday within the past week, or a localized
/// date beyond, rendered above the first message of each calendar day.
class MessageDayDivider extends StatelessWidget {
  const MessageDayDivider({required this.unixSeconds, super.key});

  /// Timestamp (Unix seconds) of the first message of the day.
  final int unixSeconds;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: context.vineColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            LocalizedTimeFormatter.formatDateLabel(
              context.l10n,
              unixSeconds,
              locale: Localizations.localeOf(context).toLanguageTag(),
            ),
            style: VineTheme.labelSmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
