// ABOUTME: Deprecated alias kept for in-flight callers; use ClickableText instead.

// TODO(#3935): Migrate all callers to ClickableText, then delete this file.

import 'package:openvine/widgets/clickable_text.dart';

export 'package:openvine/widgets/clickable_text.dart' show ClickableText;

/// Backwards-compat alias preserving the previous widget name during the
/// migration to [ClickableText].
@Deprecated(
  'Use ClickableText — supports URLs in addition to hashtags/mentions.',
)
typedef ClickableHashtagText = ClickableText;
