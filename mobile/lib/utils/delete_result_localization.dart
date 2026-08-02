import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/content_deletion_service.dart';

/// User-facing message for a failed [DeleteResult] (localized, no raw exceptions).
String localizedDeleteFailureMessage(
  BuildContext context,
  DeleteResult result,
) {
  if (result.success) {
    return '';
  }
  final kind = result.failureKind ?? DeleteFailureKind.unknown;
  final l10n = context.l10n;
  switch (kind) {
    case DeleteFailureKind.notInitialized:
      return l10n.shareMenuDeleteFailedNotInitialized;
    case DeleteFailureKind.notOwner:
      return l10n.shareMenuDeleteFailedNotOwner;
    case DeleteFailureKind.notAuthenticated:
      return l10n.shareMenuDeleteFailedNotAuthenticated;
    case DeleteFailureKind.couldNotSign:
      return l10n.shareMenuDeleteFailedCouldNotSign;
    case DeleteFailureKind.relayRejected:
      return l10n.shareMenuDeleteFailedRelayRejected;
    case DeleteFailureKind.relayNoResponse:
      return l10n.shareMenuDeleteFailedRelayNoResponse;
    case DeleteFailureKind.unknown:
      return l10n.shareMenuDeleteFailedGeneric;
  }
}

/// Message for a delete that succeeded but that only part of the relay set
/// accepted, or `null` when every targeted relay confirmed.
///
/// Returning `null` lets each screen keep its own confirmation copy and only
/// swap it out when there is a caveat to report.
String? localizedPartialDeleteMessage(
  BuildContext context,
  DeleteResult? result,
) => result != null && result.acceptance == DeleteAcceptance.someRelays
    ? context.l10n.shareMenuDeletePartiallyConfirmed
    : null;
