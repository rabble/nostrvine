import 'package:nostr_app_bridge_repository/src/models/nostr_app_directory_entry.dart';
import 'package:nostr_app_bridge_repository/src/nostr_app_grant_store.dart';

/// The outcome of a bridge policy evaluation.
enum BridgeDecision {
  /// The request may proceed without user interaction.
  allow,

  /// The user must be prompted before proceeding.
  prompt,

  /// The request is denied.
  deny,
}

/// The result of evaluating a bridge request against policy.
class BridgeEvaluation {
  /// Creates an evaluation result.
  const BridgeEvaluation({
    required this.decision,
    required this.capability,
    this.reasonCode,
  });

  /// The decision.
  final BridgeDecision decision;

  /// The capability string (e.g. `signEvent:1`).
  final String capability;

  /// A machine-readable reason code when denied.
  final String? reasonCode;
}

/// Evaluates NIP-07 bridge requests against the app manifest and
/// persisted grants.
class NostrAppBridgePolicy {
  /// Creates a policy evaluator.
  const NostrAppBridgePolicy({
    required NostrAppGrantStore grantStore,
    required String? currentUserPubkey,
  }) : _grantStore = grantStore,
       _currentUserPubkey = currentUserPubkey;

  final NostrAppGrantStore _grantStore;
  final String? _currentUserPubkey;

  /// Persists a user-approved grant so future requests are
  /// auto-allowed.
  Future<void> rememberGrant({
    required NostrAppDirectoryEntry app,
    required Uri origin,
    required String capability,
  }) async {
    final userPubkey = _currentUserPubkey;
    if (userPubkey == null || userPubkey.isEmpty) {
      return;
    }

    await _grantStore.saveGrant(
      userPubkey: userPubkey,
      appId: app.grantKey,
      origin: origin.origin,
      capability: capability,
    );
  }

  /// Evaluates a bridge request and returns the decision.
  BridgeEvaluation evaluate({
    required NostrAppDirectoryEntry app,
    required Uri origin,
    required String method,
    int? eventKind,
  }) {
    final normalizedOrigin = origin.origin;
    final capability = _capabilityFor(method: method, eventKind: eventKind);

    if ((_currentUserPubkey ?? '').isEmpty) {
      return BridgeEvaluation(
        decision: BridgeDecision.deny,
        capability: capability,
        reasonCode: 'unauthenticated',
      );
    }

    if (!app.allowedOrigins.contains(normalizedOrigin)) {
      return BridgeEvaluation(
        decision: BridgeDecision.deny,
        capability: capability,
        reasonCode: 'blocked_origin',
      );
    }

    if (!app.allowedMethods.contains(method)) {
      return BridgeEvaluation(
        decision: BridgeDecision.deny,
        capability: capability,
        reasonCode: 'blocked_method',
      );
    }

    if (method == 'signEvent') {
      if (eventKind == null || !app.allowedSignEventKinds.contains(eventKind)) {
        return BridgeEvaluation(
          decision: BridgeDecision.deny,
          capability: capability,
          reasonCode: 'blocked_event_kind',
        );
      }
    }

    final hasGrant = _grantStore.hasGrant(
      userPubkey: _currentUserPubkey!,
      appId: app.grantKey,
      origin: normalizedOrigin,
      capability: capability,
    );
    if (hasGrant) {
      return BridgeEvaluation(
        decision: BridgeDecision.allow,
        capability: capability,
        reasonCode: 'remembered_grant',
      );
    }

    final requiresPrompt =
        method == 'signEvent' ||
        app.promptRequiredFor.contains(method) ||
        app.promptRequiredFor.contains(capability);

    if (requiresPrompt) {
      return BridgeEvaluation(
        decision: BridgeDecision.prompt,
        capability: capability,
      );
    }

    return BridgeEvaluation(
      decision: BridgeDecision.allow,
      capability: capability,
    );
  }

  static String _capabilityFor({
    required String method,
    required int? eventKind,
  }) {
    if (method == 'signEvent') {
      return 'signEvent:${eventKind ?? 'unknown'}';
    }
    return method;
  }
}
