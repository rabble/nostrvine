import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/nostr_app_directory_entry.dart';
import 'package:openvine/services/nostr_app_bridge_policy.dart';
import 'package:openvine/services/nostr_app_grant_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('NostrAppBridgePolicy', () {
    late SharedPreferences sharedPreferences;
    late NostrAppGrantStore grantStore;
    late NostrAppBridgePolicy policy;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      grantStore = NostrAppGrantStore(sharedPreferences: sharedPreferences);
      policy = NostrAppBridgePolicy(
        grantStore: grantStore,
        currentUserPubkey: 'user-pubkey',
      );
    });

    test('prompts for signEvent when origin, method, and kind are allowed', () {
      final evaluation = policy.evaluate(
        app: _fixtureApp(),
        origin: Uri.parse('https://primal.net'),
        method: 'signEvent',
        eventKind: 1,
      );

      expect(evaluation.decision, BridgeDecision.prompt);
      expect(evaluation.capability, 'signEvent:1');
    });

    test('denies requests from blocked origins', () {
      final evaluation = policy.evaluate(
        app: _fixtureApp(),
        origin: Uri.parse('https://evil.example'),
        method: 'getPublicKey',
      );

      expect(evaluation.decision, BridgeDecision.deny);
      expect(evaluation.reasonCode, 'blocked_origin');
    });

    test('denies blocked methods', () {
      final evaluation = policy.evaluate(
        app: _fixtureApp(),
        origin: Uri.parse('https://primal.net'),
        method: 'nip44.decrypt',
      );

      expect(evaluation.decision, BridgeDecision.deny);
      expect(evaluation.reasonCode, 'blocked_method');
    });

    test('denies blocked signEvent kinds', () {
      final evaluation = policy.evaluate(
        app: _fixtureApp(),
        origin: Uri.parse('https://primal.net'),
        method: 'signEvent',
        eventKind: 4,
      );

      expect(evaluation.decision, BridgeDecision.deny);
      expect(evaluation.reasonCode, 'blocked_event_kind');
    });

    test('allows low-risk methods without a prompt', () {
      final evaluation = policy.evaluate(
        app: _fixtureApp(),
        origin: Uri.parse('https://primal.net'),
        method: 'getPublicKey',
      );

      expect(evaluation.decision, BridgeDecision.allow);
      expect(evaluation.capability, 'getPublicKey');
    });

    test(
      'allows previously granted capabilities without prompting again',
      () async {
        await grantStore.saveGrant(
          userPubkey: 'user-pubkey',
          appId: '1',
          origin: 'https://primal.net',
          capability: 'signEvent:1',
        );

        final evaluation = policy.evaluate(
          app: _fixtureApp(),
          origin: Uri.parse('https://primal.net'),
          method: 'signEvent',
          eventKind: 1,
        );

        expect(evaluation.decision, BridgeDecision.allow);
        expect(evaluation.reasonCode, 'remembered_grant');
      },
    );
  });
}

NostrAppDirectoryEntry _fixtureApp() {
  return NostrAppDirectoryEntry(
    id: '1',
    slug: 'primal',
    name: 'Primal',
    tagline: 'Fast Nostr feeds and messages',
    description: 'A vetted Nostr client for timelines and DMs.',
    iconUrl: 'https://cdn.divine.video/primal.png',
    launchUrl: 'https://primal.net/app',
    allowedOrigins: const ['https://primal.net'],
    allowedMethods: const ['getPublicKey', 'signEvent'],
    allowedSignEventKinds: const [1],
    promptRequiredFor: const ['nip44.encrypt'],
    status: 'approved',
    sortOrder: 1,
    createdAt: DateTime.parse('2026-03-24T08:00:00Z'),
    updatedAt: DateTime.parse('2026-03-25T08:00:00Z'),
  );
}
