// ABOUTME: Regression tests for which account owns locally recorded content.
// ABOUTME: Offline recordings must stay attributed to the restoring session.

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/utils/local_content_owner.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthService extends Mock implements AuthService {}

const _pubkeyA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _pubkeyB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _pubkeyC =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

void main() {
  group('local content owner', () {
    late AppDatabase db;
    late _MockAuthService authService;
    late ProviderContainer container;

    /// Builds a container whose auth service reports [currentPubkeyHex] as the
    /// live session (null meaning "still restoring"), over preferences holding
    /// [pendingSessionPubkeyHex] as the account this device is signed into and
    /// [lastActivePubkeyHex] as the known-accounts registry's most recent entry
    /// (null meaning the registry has never been written).
    Future<ProviderContainer> buildContainer({
      required String? currentPubkeyHex,
      required String? pendingSessionPubkeyHex,
      String? lastActivePubkeyHex,
    }) async {
      SharedPreferences.setMockInitialValues({
        currentUserPubkeyHexPrefKey: ?pendingSessionPubkeyHex,
        kKnownAccountsKey: ?(lastActivePubkeyHex == null
            ? null
            : jsonEncode([
                KnownAccount(
                  pubkeyHex: lastActivePubkeyHex,
                  authSource: AuthenticationSource.bunker,
                  addedAt: DateTime(2026, 8, 16),
                  lastUsedAt: DateTime(2026, 8, 17),
                ).toJson(),
                // An older entry, to prove the newest one is what is read.
                KnownAccount(
                  pubkeyHex: _pubkeyC,
                  authSource: AuthenticationSource.automatic,
                  addedAt: DateTime(2026, 8, 10),
                  lastUsedAt: DateTime(2026, 8, 11),
                ).toJson(),
              ])),
      });
      final prefs = await SharedPreferences.getInstance();

      when(() => authService.currentPublicKeyHex).thenReturn(currentPubkeyHex);

      return ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          authServiceProvider.overrideWithValue(authService),
        ],
      );
    }

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      authService = _MockAuthService();
      when(() => authService.authState).thenReturn(AuthState.authenticated);
      when(
        () => authService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('attributes to the live session when one is authenticated', () async {
      container = await buildContainer(
        currentPubkeyHex: _pubkeyA,
        pendingSessionPubkeyHex: _pubkeyB,
      );

      expect(container.read(clipLibraryServiceProvider).ownerPubkey, _pubkeyA);
      expect(container.read(draftStorageServiceProvider).ownerPubkey, _pubkeyA);
    });

    test(
      'attributes to the restoring session while it has no pubkey yet',
      () async {
        // The offline case: a bunker / Keycast reconnect runs into the startup
        // timeout, so the session never arrives and currentPublicKeyHex stays
        // null for the whole run. Clips recorded here used to land under the
        // anonymous marker, which every owner-scoped query hides — the user
        // saw an empty library on the next launch.
        container = await buildContainer(
          currentPubkeyHex: null,
          pendingSessionPubkeyHex: _pubkeyA,
        );

        expect(
          container.read(clipLibraryServiceProvider).ownerPubkey,
          _pubkeyA,
        );
        expect(
          container.read(draftStorageServiceProvider).ownerPubkey,
          _pubkeyA,
        );
      },
    );

    test(
      'refuses the preference when it names a different account than the '
      'one this device was last active as',
      () async {
        // The bunker / Amber hole: only _setupUserSession writes the
        // preference, and _reconnectBunker / _reconnectAmber establish a
        // session without it. So after switching from A to a bunker account B
        // the preference still reads A while B is signed in, and a cold start
        // whose bunker reconnect times out leaves no live session to correct
        // it.
        //
        // Stamping A would be worse than the marker: the automatic claim
        // matches `owner IS NULL OR owner = '<marker>'`, so a real foreign
        // pubkey is one B could never get back on its own.
        container = await buildContainer(
          currentPubkeyHex: null,
          pendingSessionPubkeyHex: _pubkeyA,
          lastActivePubkeyHex: _pubkeyB,
        );

        expect(
          container.read(clipLibraryServiceProvider).ownerPubkey,
          DraftStorageService.anonymousOwnerPubkey,
        );
        expect(
          container.read(draftStorageServiceProvider).ownerPubkey,
          DraftStorageService.anonymousOwnerPubkey,
        );
      },
    );

    test('accepts the preference when the registry agrees', () async {
      container = await buildContainer(
        currentPubkeyHex: null,
        pendingSessionPubkeyHex: _pubkeyA,
        lastActivePubkeyHex: _pubkeyA,
      );

      expect(container.read(clipLibraryServiceProvider).ownerPubkey, _pubkeyA);
      expect(container.read(draftStorageServiceProvider).ownerPubkey, _pubkeyA);
    });

    test('falls back to anonymous on a device with no account', () async {
      // Sign-out removes the preference, so this is a genuinely unattributed
      // recording — the case the marker exists for, rescued by the legacy-row
      // claim on the next sign-in.
      container = await buildContainer(
        currentPubkeyHex: null,
        pendingSessionPubkeyHex: null,
      );

      expect(
        container.read(clipLibraryServiceProvider).ownerPubkey,
        DraftStorageService.anonymousOwnerPubkey,
      );
      expect(
        container.read(draftStorageServiceProvider).ownerPubkey,
        DraftStorageService.anonymousOwnerPubkey,
      );
    });
  });
}
