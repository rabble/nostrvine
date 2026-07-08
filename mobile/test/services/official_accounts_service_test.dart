// ABOUTME: Tests for OfficialAccountsService (#176) — pin ∩ NIP-05 with graded
// ABOUTME: revocation, 1h TTL, 5-min absence recheck, and persistent last-known.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/services/nip05_resolver.dart';
import 'package:openvine/services/official_accounts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockResolver extends Mock implements Nip05Resolver {}

void main() {
  const hqHex =
      'c4a39f1291291d452405cd8ddd798c4a29a3858c52cd0d843f1f6852cf17682e';
  const modHex =
      '8fd5eb6d8f362163bc00a5ab6b4a3167dbf32d00ec4efdbcf43b3c9514433b7e';
  const strangerHex =
      'deadbeef00000000000000000000000000000000000000000000000000000000';
  const attackerHex =
      '1111111111111111111111111111111111111111111111111111111111111111';

  late _MockResolver resolver;
  late SharedPreferences prefs;
  DateTime clock = DateTime(2026, 7, 7, 12);

  setUp(() async {
    resolver = _MockResolver();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    clock = DateTime(2026, 7, 7, 12);
  });

  OfficialAccountsService build({List<OfficialAccount>? accounts}) =>
      OfficialAccountsService(
        resolver: resolver,
        prefs: prefs,
        now: () => clock,
        accounts: accounts,
      );

  const hqNip05 = '_@divinehq.divine.video';

  test('unpinned pubkey is never an approved recipient', () async {
    final svc = build();
    expect(svc.isPinnedMinorContactable(strangerHex), isFalse);
    expect(svc.isApprovedMinorDmRecipientSync(strangerHex), isFalse);
    expect(await svc.isApprovedMinorDmRecipient(strangerHex), isFalse);
    verifyNever(() => resolver.resolve(any(), any()));
  });

  test(
    'pinned but not minorContactable is rejected without a network call',
    () async {
      final svc = build(
        accounts: const [
          OfficialAccount(
            pubkeyHex: hqHex,
            nip05: hqNip05,
            role: 'hq',
            minorContactable: false,
          ),
        ],
      );
      expect(svc.isPinnedMinorContactable(hqHex), isFalse);
      expect(await svc.isApprovedMinorDmRecipient(hqHex), isFalse);
      verifyNever(() => resolver.resolve(any(), any()));
    },
  );

  test('pinned + NIP-05 matches -> approved', () async {
    when(
      () => resolver.resolve(hqNip05, hqHex),
    ).thenAnswer((_) async => const Nip05Resolution.matched(hqHex));

    final svc = build();
    expect(await svc.isApprovedMinorDmRecipient(hqHex), isTrue);
  });

  test(
    'pinned but NIP-05 resolves to a DIFFERENT key -> dropped immediately and persisted',
    () async {
      when(() => resolver.resolve(hqNip05, hqHex)).thenAnswer(
        (_) async => const Nip05Resolution.differentKey(attackerHex),
      );

      final svc = build();
      expect(await svc.isApprovedMinorDmRecipient(hqHex), isFalse);
      // persisted revoked: the sync hot path now rejects without re-resolving
      expect(svc.isApprovedMinorDmRecipientSync(hqHex), isFalse);
    },
  );

  test('a single absence never drops (keeps last-known approved)', () async {
    when(
      () => resolver.resolve(hqNip05, hqHex),
    ).thenAnswer((_) async => const Nip05Resolution.absent());

    final svc = build();
    expect(await svc.isApprovedMinorDmRecipient(hqHex), isTrue);
    expect(svc.isApprovedMinorDmRecipientSync(hqHex), isTrue);
  });

  test(
    'absence within the recheck window does not re-resolve or drop',
    () async {
      when(
        () => resolver.resolve(hqNip05, hqHex),
      ).thenAnswer((_) async => const Nip05Resolution.absent());

      final svc = build();
      expect(await svc.isApprovedMinorDmRecipient(hqHex), isTrue);
      clock = clock.add(const Duration(minutes: 2));
      expect(await svc.isApprovedMinorDmRecipient(hqHex), isTrue);
      verify(() => resolver.resolve(hqNip05, hqHex)).called(1);
    },
  );

  test(
    'a confirming absence after the recheck window drops and persists',
    () async {
      when(
        () => resolver.resolve(hqNip05, hqHex),
      ).thenAnswer((_) async => const Nip05Resolution.absent());

      final svc = build();
      expect(await svc.isApprovedMinorDmRecipient(hqHex), isTrue);
      clock = clock.add(const Duration(minutes: 6));
      expect(await svc.isApprovedMinorDmRecipient(hqHex), isFalse);
      expect(svc.isApprovedMinorDmRecipientSync(hqHex), isFalse);
    },
  );

  test('absence recovers if a later resolution matches again', () async {
    final answers = <Nip05Resolution>[
      const Nip05Resolution.absent(),
      const Nip05Resolution.matched(hqHex),
    ];
    var i = 0;
    when(
      () => resolver.resolve(hqNip05, hqHex),
    ).thenAnswer((_) async => answers[i++]);

    final svc = build();
    expect(await svc.isApprovedMinorDmRecipient(hqHex), isTrue);
    clock = clock.add(const Duration(minutes: 6));
    expect(await svc.isApprovedMinorDmRecipient(hqHex), isTrue);
    expect(svc.isApprovedMinorDmRecipientSync(hqHex), isTrue);
  });

  test('networkError keeps a previously revoked verdict', () async {
    final answers = <Nip05Resolution>[
      const Nip05Resolution.differentKey(attackerHex),
      const Nip05Resolution.networkError(),
    ];
    var i = 0;
    when(
      () => resolver.resolve(hqNip05, hqHex),
    ).thenAnswer((_) async => answers[i++]);

    final svc = build();
    expect(await svc.isApprovedMinorDmRecipient(hqHex), isFalse);
    clock = clock.add(const Duration(hours: 2));
    expect(await svc.isApprovedMinorDmRecipient(hqHex), isFalse);
  });

  test(
    'networkError with no record defaults to pin-trusted and retries',
    () async {
      when(
        () => resolver.resolve(hqNip05, hqHex),
      ).thenAnswer((_) async => const Nip05Resolution.networkError());

      final svc = build();
      expect(await svc.isApprovedMinorDmRecipient(hqHex), isTrue);
      // nothing cached -> the next call resolves again rather than trusting a non-answer
      expect(await svc.isApprovedMinorDmRecipient(hqHex), isTrue);
      verify(() => resolver.resolve(hqNip05, hqHex)).called(2);
    },
  );

  test('a fresh verdict is reused without re-resolving (TTL)', () async {
    when(
      () => resolver.resolve(hqNip05, hqHex),
    ).thenAnswer((_) async => const Nip05Resolution.matched(hqHex));

    final svc = build();
    expect(await svc.isApprovedMinorDmRecipient(hqHex), isTrue);
    clock = clock.add(const Duration(minutes: 30));
    expect(await svc.isApprovedMinorDmRecipient(hqHex), isTrue);
    verify(() => resolver.resolve(hqNip05, hqHex)).called(1);
  });

  test(
    'a stale verdict triggers a fresh resolution (send-time freshness)',
    () async {
      when(
        () => resolver.resolve(hqNip05, hqHex),
      ).thenAnswer((_) async => const Nip05Resolution.matched(hqHex));

      final svc = build();
      expect(await svc.isApprovedMinorDmRecipient(hqHex), isTrue);
      clock = clock.add(const Duration(hours: 2));
      expect(await svc.isApprovedMinorDmRecipient(hqHex), isTrue);
      verify(() => resolver.resolve(hqNip05, hqHex)).called(2);
    },
  );

  test(
    'moderation account is independently approved (both pins live)',
    () async {
      when(
        () => resolver.resolve('moderation@divine.video', modHex),
      ).thenAnswer((_) async => const Nip05Resolution.matched(modHex));

      final svc = build();
      expect(svc.isPinnedMinorContactable(modHex), isTrue);
      expect(await svc.isApprovedMinorDmRecipient(modHex), isTrue);
    },
  );

  test(
    'caller hex is normalized (mixed-case + surrounding whitespace)',
    () async {
      when(
        () => resolver.resolve(hqNip05, hqHex),
      ).thenAnswer((_) async => const Nip05Resolution.matched(hqHex));

      final svc = build();
      final messy = '  ${hqHex.toUpperCase()}\n';
      expect(svc.isPinnedMinorContactable(messy), isTrue);
      expect(await svc.isApprovedMinorDmRecipient(messy), isTrue);
    },
  );

  test('empty or whitespace hex is rejected without a network call', () async {
    final svc = build();
    expect(await svc.isApprovedMinorDmRecipient('   '), isFalse);
    expect(await svc.isApprovedMinorDmRecipient(''), isFalse);
    verifyNever(() => resolver.resolve(any(), any()));
  });

  test(
    'a revoked account re-approves when a later resolution matches again',
    () async {
      final answers = <Nip05Resolution>[
        const Nip05Resolution.differentKey(attackerHex),
        const Nip05Resolution.matched(hqHex),
      ];
      var i = 0;
      when(
        () => resolver.resolve(hqNip05, hqHex),
      ).thenAnswer((_) async => answers[i++]);

      final svc = build();
      expect(await svc.isApprovedMinorDmRecipient(hqHex), isFalse);
      clock = clock.add(const Duration(hours: 2));
      expect(await svc.isApprovedMinorDmRecipient(hqHex), isTrue);
      expect(svc.isApprovedMinorDmRecipientSync(hqHex), isTrue);
    },
  );

  test(
    'a networkError between absences does not reset the confirming-recheck clock',
    () async {
      final answers = <Nip05Resolution>[
        const Nip05Resolution.absent(),
        const Nip05Resolution.networkError(),
        const Nip05Resolution.absent(),
      ];
      var i = 0;
      when(
        () => resolver.resolve(hqNip05, hqHex),
      ).thenAnswer((_) async => answers[i++]);

      final svc = build();
      expect(await svc.isApprovedMinorDmRecipient(hqHex), isTrue); // absence #1
      clock = clock.add(const Duration(minutes: 6));
      expect(
        await svc.isApprovedMinorDmRecipient(hqHex),
        isTrue,
      ); // networkError
      clock = clock.add(const Duration(minutes: 1));
      // firstAbsentAt preserved from #1, so this confirming absence (>5m later) drops
      expect(await svc.isApprovedMinorDmRecipient(hqHex), isFalse);
    },
  );

  test('onVerdictChanged fires when a verdict flips to revoked', () async {
    when(() => resolver.resolve(hqNip05, hqHex)).thenAnswer(
      (_) async => const Nip05Resolution.differentKey(attackerHex),
    );
    final svc = build();
    addTearDown(svc.dispose);
    final fired = <void>[];
    final sub = svc.onVerdictChanged.listen(fired.add);
    addTearDown(sub.cancel);

    await svc.isApprovedMinorDmRecipient(hqHex);
    await Future<void>.delayed(Duration.zero);

    expect(fired, hasLength(1));
  });

  test(
    'onVerdictChanged does not fire when a resolution confirms the verdict',
    () async {
      when(
        () => resolver.resolve(hqNip05, hqHex),
      ).thenAnswer((_) async => const Nip05Resolution.matched(hqHex));
      final svc = build();
      addTearDown(svc.dispose);
      final fired = <void>[];
      final sub = svc.onVerdictChanged.listen(fired.add);
      addTearDown(sub.cancel);

      // matched == the pin-trusted default (approved), so no observable flip.
      await svc.isApprovedMinorDmRecipient(hqHex);
      await Future<void>.delayed(Duration.zero);

      expect(fired, isEmpty);
    },
  );
}
