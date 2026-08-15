// ABOUTME: The single sanctioned entry point to the platform share sheet.
// ABOUTME: Fills the sharePositionOrigin anchor iPad refuses to share without.

import 'package:flutter/widgets.dart';
import 'package:openvine/utils/share_position_origin.dart';
import 'package:share_plus/share_plus.dart';

/// The share_plus value types call sites need, re-exported so that nothing
/// else has to import the plugin.
///
/// `SharePlus` and the deprecated `Share` are deliberately absent: they are
/// the entry points that skip the anchor, and leaving them unreachable is
/// what makes the omission in #7506 unrepresentable rather than merely
/// discouraged. `test/tools/share_sheet_entry_point_test.dart` fails if any
/// other file under `lib/` or `packages/*/lib/` imports share_plus directly.
export 'package:share_plus/share_plus.dart'
    show
        CupertinoActivityType,
        ShareParams,
        ShareResult,
        ShareResultStatus,
        XFile;

/// Presents the platform share sheet, anchored to [context].
///
/// Use this instead of `SharePlus.instance.share`. On iPad idiom (real iPads
/// and iOS builds running on Apple Silicon Macs) share_plus rejects a share
/// whose `sharePositionOrigin` is missing or empty with
/// `PlatformException(sharePositionOrigin: argument must be set …)`. Routing
/// every share through here is what keeps a call site from omitting it;
/// `test/tools/share_sheet_entry_point_test.dart` holds the line.
///
/// [context] must still be mounted, so resolve the anchor before any
/// `await` — callers that share after awaiting should capture
/// [shareAnchorForContext] first and use [showShareSheetAtOrigin].
Future<ShareResult> showShareSheet(BuildContext context, ShareParams params) {
  return showShareSheetAtOrigin(
    params,
    sharePositionOrigin: shareAnchorForContext(context),
  );
}

/// Presents the platform share sheet for callers that resolved the anchor
/// earlier, or that have no [BuildContext] at all (services).
///
/// [sharePositionOrigin] comes from [shareAnchorForContext] at the widget
/// layer. It stays nullable because a service can be driven from a headless
/// caller, but passing `null` on iPad is what the crash in #7506 was.
Future<ShareResult> showShareSheetAtOrigin(
  ShareParams params, {
  required Rect? sharePositionOrigin,
}) {
  return SharePlus.instance.share(
    shareParamsWithPositionOrigin(params, sharePositionOrigin),
  );
}

/// Copies [params] with [sharePositionOrigin] filled in, keeping an origin
/// the caller set explicitly.
///
/// `ShareParams` ships no `copyWith`, so every field is forwarded by hand and
/// a new share_plus field has to be added here as well —
/// `test/utils/share_sheet_test.dart` fails when one is dropped.
@visibleForTesting
ShareParams shareParamsWithPositionOrigin(
  ShareParams params,
  Rect? sharePositionOrigin,
) {
  if (params.sharePositionOrigin != null) return params;
  return ShareParams(
    text: params.text,
    subject: params.subject,
    title: params.title,
    previewThumbnail: params.previewThumbnail,
    sharePositionOrigin: sharePositionOrigin,
    uri: params.uri,
    files: params.files,
    fileNameOverrides: params.fileNameOverrides,
    downloadFallbackEnabled: params.downloadFallbackEnabled,
    mailToFallbackEnabled: params.mailToFallbackEnabled,
    excludedCupertinoActivities: params.excludedCupertinoActivities,
  );
}
