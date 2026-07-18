// ABOUTME: Tests the one-time corrupted-video repair completion-flag contract:
// ABOUTME: the flag is only set once the scan actually ran, so calling the
// ABOUTME: repair before an identity is restored can't silently disable it.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/corrupted_video_repair_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  group(CorruptedVideoRepairService, () {
    late _MockNostrClient nostrClient;
    late _MockAuthService authService;
    late SharedPreferences prefs;

    setUp(() async {
      nostrClient = _MockNostrClient();
      authService = _MockAuthService();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      prefs = await SharedPreferences.getInstance();
    });

    CorruptedVideoRepairService buildService() => CorruptedVideoRepairService(
      nostrClient: nostrClient,
      authService: authService,
      prefs: prefs,
      blossomBaseUrl: 'https://blossom.example',
    );

    test(
      'does not mark complete when not authenticated, so it retries later',
      () async {
        // Reproduces the pre-restore startup window: the repair runs before
        // the identity is restored. Before the fix it set the completion flag
        // regardless, permanently disabling the migration (#2144).
        when(() => authService.isAuthenticated).thenReturn(false);
        final service = buildService();

        expect(await service.repairIfNeeded(), 0);
        // Flag NOT set: a second attempt still runs (returns 0, not -1).
        expect(
          await service.repairIfNeeded(),
          0,
          reason:
              'an unauthenticated run must not mark the one-time repair '
              'complete — it has to retry once an identity is available.',
        );
      },
    );

    test('does not mark complete when the public key is empty', () async {
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => nostrClient.publicKey).thenReturn('');
      final service = buildService();

      expect(await service.repairIfNeeded(), 0);
      expect(await service.repairIfNeeded(), 0);
    });

    test('marks complete after a real scan and skips thereafter', () async {
      when(() => authService.isAuthenticated).thenReturn(true);
      when(() => nostrClient.publicKey).thenReturn('a' * 64);
      when(
        () => nostrClient.queryEvents(
          any(),
          useCache: any(named: 'useCache'),
        ),
      ).thenAnswer((_) async => <Event>[]);
      final service = buildService();

      expect(
        await service.repairIfNeeded(),
        0,
        reason: 'an authenticated scan with no corrupted events repairs none.',
      );
      expect(
        await service.repairIfNeeded(),
        -1,
        reason: 'once the scan has run the migration is marked complete.',
      );
    });
  });
}
