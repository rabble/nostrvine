// ABOUTME: Maps a PublishOutcome to PublishUserFeedback — single source of
// ABOUTME: truth for how every service domain translates publish results into UX.

import 'package:meta/meta.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';

/// Severity level for a publish result.
///
/// UI layers use [PublishSeverity.success] for positive confirmations and
/// [PublishSeverity.error] for failure snackbars / banners.
enum PublishSeverity { success, error }

/// User-facing summary of a publish attempt, derived from a
/// [PublishOutcome].
///
/// Every service that migrates to `publishEventWithRetry` should funnel its
/// result through [PublishResultMapper.map] so the UX is consistent across
/// the app: the message key is looked up in l10n, [retryable] drives the
/// presence of a Retry affordance, and [firstRejectionReason] surfaces the
/// relay's explanation when available.
@immutable
class PublishUserFeedback {
  const PublishUserFeedback({
    required this.severity,
    required this.messageKey,
    required this.retryable,
    this.firstRejectionReason,
  });

  final PublishSeverity severity;

  /// i18n key for the user-facing message. Consumers look this up in
  /// their AppLocalizations / ARB. Keeping the mapper free of l10n
  /// dependencies makes it reusable across packages.
  final String messageKey;

  /// Whether retrying has a reasonable chance of succeeding. UIs should
  /// expose a retry affordance only when this is `true`.
  final bool retryable;

  /// First raw rejection reason from the outcome (if any). Useful for
  /// error snackbars and debug logs — do NOT display untranslated to
  /// end users without context.
  final String? firstRejectionReason;
}

/// Translates [PublishOutcome] to [PublishUserFeedback].
///
/// The decision tree:
/// - Any accept → success (partial accept is still durable).
/// - All three sets empty → `publish_no_relays_available` (retryable).
/// - Any transient relay (no-response or non-permanent reject) →
///   `publish_no_relay_response` (retryable).
/// - Otherwise all rejections are permanent →
///   `publish_rejected_permanent` (not retryable, surface reason).
abstract class PublishResultMapper {
  PublishResultMapper._();

  static PublishUserFeedback map(PublishOutcome outcome) {
    if (outcome.acceptedByAny) {
      return const PublishUserFeedback(
        severity: PublishSeverity.success,
        messageKey: 'publish_success',
        retryable: false,
      );
    }

    if (outcome.acceptedBy.isEmpty &&
        outcome.rejectedBy.isEmpty &&
        outcome.noResponseFrom.isEmpty) {
      return const PublishUserFeedback(
        severity: PublishSeverity.error,
        messageKey: 'publish_no_relays_available',
        retryable: true,
      );
    }

    if (outcome.transientRelays.isNotEmpty) {
      return const PublishUserFeedback(
        severity: PublishSeverity.error,
        messageKey: 'publish_no_relay_response',
        retryable: true,
      );
    }

    final firstReason = outcome.rejectedBy.values.isNotEmpty
        ? outcome.rejectedBy.values.first
        : null;
    return PublishUserFeedback(
      severity: PublishSeverity.error,
      messageKey: 'publish_rejected_permanent',
      retryable: false,
      firstRejectionReason: firstReason,
    );
  }
}
