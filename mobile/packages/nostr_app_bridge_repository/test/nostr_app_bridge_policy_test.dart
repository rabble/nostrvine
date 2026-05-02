import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

void main() {
  group('NostrAppBridgePolicy', () {
    late SharedPreferences sharedPreferences;
    late NostrAppGrantStore grantStore;
    late NostrAppBridgePolicy policy;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      grantStore = NostrAppGrantStore(
        sharedPreferences: sharedPreferences,
      );
      policy = NostrAppBridgePolicy(
        grantStore: grantStore,
        currentUserPubkey: 'f' * 64,
      );
    });

    test(
      'allows getPublicKey for an allowed origin without '
      'a prompt',
      () {
        final evaluation = policy.evaluate(
          app: _app(),
          origin: Uri.parse('https://primal.net'),
          method: 'getPublicKey',
        );

        expect(evaluation.decision, BridgeDecision.allow);
        expect(evaluation.capability, 'getPublicKey');
      },
    );

    test(
      'prompts for signEvent when the manifest requires it',
      () {
        final evaluation = policy.evaluate(
          app: _app(
            promptRequiredFor: const ['signEvent'],
          ),
          origin: Uri.parse('https://primal.net'),
          method: 'signEvent',
          eventKind: 1,
        );

        expect(evaluation.decision, BridgeDecision.prompt);
        expect(evaluation.capability, 'signEvent:1');
      },
    );

    test(
      'allows a prompted capability after a stored grant',
      () async {
        await grantStore.saveGrant(
          userPubkey: 'f' * 64,
          appId: 'primal',
          origin: 'https://primal.net',
          capability: 'signEvent:1',
        );

        final evaluation = policy.evaluate(
          app: _app(
            promptRequiredFor: const ['signEvent'],
          ),
          origin: Uri.parse('https://primal.net'),
          method: 'signEvent',
          eventKind: 1,
        );

        expect(evaluation.decision, BridgeDecision.allow);
        expect(evaluation.capability, 'signEvent:1');
      },
    );

    test(
      'allows a remembered grant after the app id changes '
      'for the same slug',
      () async {
        await grantStore.saveGrant(
          userPubkey: 'f' * 64,
          appId: 'primal',
          origin: 'https://primal.net',
          capability: 'signEvent:1',
        );

        final evaluation = policy.evaluate(
          app: _app(
            id: '42',
            promptRequiredFor: const ['signEvent'],
          ),
          origin: Uri.parse('https://primal.net'),
          method: 'signEvent',
          eventKind: 1,
        );

        expect(evaluation.decision, BridgeDecision.allow);
        expect(evaluation.capability, 'signEvent:1');
      },
    );

    test(
      'blocks requests from a non-allowlisted origin',
      () {
        final evaluation = policy.evaluate(
          app: _app(),
          origin: Uri.parse('https://evil.example'),
          method: 'getPublicKey',
        );

        expect(evaluation.decision, BridgeDecision.deny);
        expect(evaluation.reasonCode, 'blocked_origin');
      },
    );

    test(
      'blocks methods outside the manifest allowlist',
      () {
        final evaluation = policy.evaluate(
          app: _app(),
          origin: Uri.parse('https://primal.net'),
          method: 'nip44.decrypt',
        );

        expect(evaluation.decision, BridgeDecision.deny);
        expect(evaluation.reasonCode, 'blocked_method');
      },
    );

    test(
      'blocks signEvent kinds outside the manifest allowlist',
      () {
        final evaluation = policy.evaluate(
          app: _app(),
          origin: Uri.parse('https://primal.net'),
          method: 'signEvent',
          eventKind: 4,
        );

        expect(evaluation.decision, BridgeDecision.deny);
        expect(evaluation.reasonCode, 'blocked_event_kind');
      },
    );

    test(
      'preloaded Divine Badges manifest allows only NIP-58 '
      'badge event signing',
      () {
        final badges = preloadedNostrApps
            .where((app) => app.slug == 'badges')
            .single;

        expect(
          badges.allowedSignEventKinds,
          [3, 8, 10002, 10008, 30008, 30009],
        );

        final acceptedBadgeProfile = policy.evaluate(
          app: badges,
          origin: Uri.parse('https://badges.divine.video/me'),
          method: 'signEvent',
          eventKind: 10008,
        );
        expect(acceptedBadgeProfile.decision, BridgeDecision.prompt);
        expect(acceptedBadgeProfile.capability, 'signEvent:10008');

        final blockedDirectMessage = policy.evaluate(
          app: badges,
          origin: Uri.parse('https://badges.divine.video/me'),
          method: 'signEvent',
          eventKind: 4,
        );
        expect(blockedDirectMessage.decision, BridgeDecision.deny);
        expect(blockedDirectMessage.reasonCode, 'blocked_event_kind');
      },
    );
  });
}

NostrAppDirectoryEntry _app({
  String id = 'primal-app',
  List<String> promptRequiredFor = const [],
}) {
  return NostrAppDirectoryEntry(
    id: id,
    slug: 'primal',
    name: 'Primal',
    tagline: 'A social client',
    description: 'A vetted Nostr app.',
    iconUrl: 'https://primal.net/icon.png',
    launchUrl: 'https://primal.net/app',
    allowedOrigins: const ['https://primal.net'],
    allowedMethods: const ['getPublicKey', 'signEvent'],
    allowedSignEventKinds: const [1],
    promptRequiredFor: promptRequiredFor,
    status: 'approved',
    sortOrder: 1,
    createdAt: DateTime.utc(2026, 3, 25),
    updatedAt: DateTime.utc(2026, 3, 25),
  );
}
