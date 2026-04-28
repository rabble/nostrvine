// ABOUTME: Shared layout metrics for [FeedModeSwitch] and aligned overlays.
// ABOUTME: Keeps vertical math for [FollowingHashtagPageTitle] in sync with the mode row.

import 'package:flutter/widgets.dart';

/// Padding inside [SafeArea] around the feed mode row, and related vertical spacing.
///
/// [feedModeLabelLineHeight] matches one line box of [VineTheme.headlineSmallFont]
/// (font size 24, height 32/24).
abstract final class FeedModeOverlayLayout {
  static const EdgeInsets contentPadding = EdgeInsets.only(
    top: 16,
    bottom: 16,
    left: 20,
    right: 20,
  );

  /// Line height for a single line of feed mode label text ([VineTheme.headlineSmallFont]).
  static const double feedModeLabelLineHeight = 32;

  /// Space between the bottom of the feed mode row and the following-hashtag line.
  static const double gapBeforeFollowingHashtagLine = 6;
}
