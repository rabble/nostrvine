import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostr extends Mock implements Nostr {}

class _MockRelayManager extends Mock implements RelayManager {}

class _FakeEvent extends Fake implements Event {}

const _pubkey =
    '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';

Event _event({
  int kind = EventKind.textNote,
  List<List<String>> tags = const [],
}) {
  return Event(
    _pubkey,
    kind,
    tags.map(List<String>.from).toList(),
    'hello',
    createdAt: 1700000000,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    Nip89ClientTag.resetForTest();
  });

  tearDown(Nip89ClientTag.resetForTest);

  group('Nip89ClientTag', () {
    test('adds the canonical Divine tag', () async {
      final event = _event();
      final originalId = event.id;

      final changed = await Nip89ClientTag.applyToEvent(event);

      expect(changed, isTrue);
      expect(event.tags, contains(Nip89ClientTag.tag));
      expect(event.id, isNot(originalId));
      expect(event.sig, isEmpty);
    });

    test('skips excluded wrapper kinds', () async {
      final event = _event(
        kind: EventKind.giftWrap,
        tags: const [
          ['p', _pubkey],
        ],
      );
      final originalId = event.id;

      final changed = await Nip89ClientTag.applyToEvent(event);

      expect(changed, isFalse);
      expect(event.tags, isNot(contains(Nip89ClientTag.tag)));
      expect(event.id, originalId);
    });

    test('respects opt-out preference', () async {
      await Nip89ClientTag.setEnabled(enabled: false);
      final event = _event();

      final changed = await Nip89ClientTag.applyToEvent(event);

      expect(changed, isFalse);
      expect(event.tags, isNot(contains(Nip89ClientTag.tag)));
    });

    test('does not duplicate an existing client tag', () async {
      final event = _event(tags: [Nip89ClientTag.tag]);

      final changed = await Nip89ClientTag.applyToEvent(event);

      expect(changed, isFalse);
      expect(event.tags.where((tag) => tag.first == 'client'), hasLength(1));
    });
  });

  group('NostrClient publish augmentation', () {
    late _MockNostr mockNostr;
    late _MockRelayManager mockRelayManager;
    late NostrClient client;

    setUp(() {
      mockNostr = _MockNostr();
      mockRelayManager = _MockRelayManager();
      client = NostrClient.forTesting(
        nostr: mockNostr,
        relayManager: mockRelayManager,
      );

      when(() => mockRelayManager.connectedRelays).thenReturn(['wss://relay']);
      when(
        () => mockNostr.sendEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
          tempRelays: any(named: 'tempRelays'),
        ),
      ).thenAnswer((invocation) async {
        return invocation.positionalArguments.first as Event;
      });
    });

    test('mutates a signed event in place before publish', () async {
      final event = _event()..sig = 'already-signed';
      final originalId = event.id;

      final result = await client.publishEvent(event);

      expect(result, isA<PublishSuccess>());
      expect(event.tags, contains(Nip89ClientTag.tag));
      expect(event.id, isNot(originalId));
      expect(event.sig, isEmpty);
      verify(
        () => mockNostr.sendEvent(
          event,
          targetRelays: any(named: 'targetRelays'),
          tempRelays: any(named: 'tempRelays'),
        ),
      ).called(1);
    });
  });
}
