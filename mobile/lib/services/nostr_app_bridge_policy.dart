import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/services/nostr_app_grant_store.dart';

enum BridgeDecision { allow, prompt, deny }

class BridgeEvaluation {
  const BridgeEvaluation({
    required this.decision,
    required this.capability,
    this.reasonCode,
  });

  final BridgeDecision decision;
  final String capability;
  final String? reasonCode;
}

class NostrAppBridgePolicy {
  const NostrAppBridgePolicy({
    required NostrAppGrantStore grantStore,
    required String? currentUserPubkey,
  }) : _grantStore = grantStore,
       _currentUserPubkey = currentUserPubkey;

  final NostrAppGrantStore _grantStore;
  final String? _currentUserPubkey;

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
      appId: app.id,
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
