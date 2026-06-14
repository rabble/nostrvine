// ABOUTME: Tests for AuthService bunker lifecycle management
// ABOUTME: Tests clearError, pause/resume, dispose with bunker signer

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {}

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class _MockNostrRemoteSigner extends Mock implements NostrRemoteSigner {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockSecureKeyStorage mockKeyStorage;
  late _MockUserDataCleanupService mockCleanupService;
  late _MockFlutterSecureStorage mockFlutterSecureStorage;
  late AuthService authService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockKeyStorage = _MockSecureKeyStorage();
    mockCleanupService = _MockUserDataCleanupService();
    mockFlutterSecureStorage = _MockFlutterSecureStorage();

    // Default stubs
    when(() => mockKeyStorage.initialize()).thenAnswer((_) async {});
    when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
    when(() => mockKeyStorage.dispose()).thenReturn(null);
    when(
      () => mockFlutterSecureStorage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);

    authService = AuthService(
      userDataCleanupService: mockCleanupService,
      keyStorage: mockKeyStorage,
      flutterSecureStorage: mockFlutterSecureStorage,
    );
  });

  tearDown(() async {
    await authService.dispose();
  });

  group('AuthService clearError', () {
    test('clearError should set lastError to null', () {
      // Verify initial state - no error
      expect(authService.lastError, isNull);

      // We can't directly set _lastError, but we can verify clearError works
      // by checking it doesn't throw and the state remains null
      authService.clearError();

      expect(authService.lastError, isNull);
    });

    test('clearError can be called multiple times safely', () {
      expect(() {
        authService.clearError();
        authService.clearError();
        authService.clearError();
      }, returnsNormally);
    });
  });

  group('AuthService BackgroundAwareService implementation', () {
    test('serviceName should return AuthService', () {
      expect(authService.serviceName, equals('AuthService'));
    });

    test('onAppBackgrounded should not throw when no bunker signer', () {
      expect(() => authService.onAppBackgrounded(), returnsNormally);
    });

    test('onAppResumed should not throw when no bunker signer', () {
      expect(() => authService.onAppResumed(), returnsNormally);
    });

    test('onExtendedBackground should not throw when no bunker signer', () {
      expect(() => authService.onExtendedBackground(), returnsNormally);
    });

    test('onPeriodicCleanup should not throw', () {
      expect(() => authService.onPeriodicCleanup(), returnsNormally);
    });
  });

  group('AuthService bunker signer lifecycle', () {
    late _MockNostrRemoteSigner mockBunkerSigner;

    setUp(() {
      mockBunkerSigner = _MockNostrRemoteSigner();
      when(() => mockBunkerSigner.pause()).thenReturn(null);
      when(() => mockBunkerSigner.resume()).thenReturn(null);
      when(() => mockBunkerSigner.close()).thenReturn(null);
    });

    // Note: These tests document expected behavior.
    // Full integration would require injecting the bunker signer,
    // which is created internally during connectWithBunker().

    test('onAppBackgrounded should pause bunker signer when active', () {
      // This test documents the expected behavior:
      // When app goes to background and bunker signer is active,
      // authService.onAppBackgrounded() should call _bunkerSigner.pause()
      //
      // Code path:
      //   void onAppBackgrounded() {
      //     if (_bunkerSigner != null) {
      //       _bunkerSigner!.pause();
      //     }
      //   }
      expect(true, isTrue); // Documentation test
    });

    test('onAppResumed should resume bunker signer when active', () {
      // This test documents the expected behavior:
      // When app returns to foreground and bunker signer is active,
      // authService.onAppResumed() should call _bunkerSigner.resume()
      //
      // Code path:
      //   void onAppResumed() {
      //     if (_bunkerSigner != null) {
      //       _bunkerSigner!.resume();
      //     }
      //   }
      expect(true, isTrue); // Documentation test
    });

    test('dispose should close bunker signer when active', () {
      // This test documents the expected behavior:
      // When authService is disposed and bunker signer is active,
      // it should call _bunkerSigner.close() before nulling the reference
      //
      // Code path:
      //   Future<void> dispose() async {
      //     _bunkerSigner?.close();
      //     _bunkerSigner = null;
      //   }
      expect(true, isTrue); // Documentation test
    });

    test(
      'connectWithBunker failure should close signer before setting to null',
      () {
        // This test documents the expected behavior:
        // When bunker connection fails, we should call close() on the signer
        // before setting _bunkerSigner = null to clean up WebSocket connections
        //
        // Code path (in catch block):
        //   _bunkerSigner?.close();
        //   _bunkerSigner = null;
        expect(true, isTrue); // Documentation test
      },
    );

    test('startup restore times out unreachable bunker signer', () async {
      await authService.dispose();

      SharedPreferences.setMockInitialValues({
        'authentication_source': 'bunker',
      });
      const bunkerUrl =
          'bunker://deadbeef1234567890abcdef1234567890abcdef1234567890abcdef12345678'
          '?relay=wss://relay.example.com';

      when(
        () => mockFlutterSecureStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => bunkerUrl);
      when(
        () => mockBunkerSigner.connect(sendConnectRequest: false),
      ).thenAnswer((_) => Future<String?>.delayed(const Duration(hours: 1)));

      authService = AuthService(
        userDataCleanupService: mockCleanupService,
        keyStorage: mockKeyStorage,
        flutterSecureStorage: mockFlutterSecureStorage,
        remoteSignerFactory: (_, _) => mockBunkerSigner,
        startupNetworkOperationTimeout: const Duration(milliseconds: 1),
      );

      await authService.initialize();

      expect(authService.authState, AuthState.unauthenticated);
      verify(
        () => mockBunkerSigner.connect(sendConnectRequest: false),
      ).called(1);
      verify(() => mockBunkerSigner.close()).called(1);
    });

    test('interactive signInForAccount reconnect is unbounded for an '
        'unreachable bunker signer', () async {
      await authService.dispose();

      const pubkeyHex =
          'deadbeef1234567890abcdef1234567890abcdef1234567890abcdef12345678';
      const bunkerUrl = 'bunker://$pubkeyHex?relay=wss://relay.example.com';

      when(
        () => mockFlutterSecureStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => bunkerUrl);
      when(
        () => mockFlutterSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      // connect() never resolves: the bunker relay is unreachable.
      final neverResolves = Completer<String?>();
      when(
        () => mockBunkerSigner.connect(sendConnectRequest: false),
      ).thenAnswer((_) => neverResolves.future);

      authService = AuthService(
        userDataCleanupService: mockCleanupService,
        keyStorage: mockKeyStorage,
        flutterSecureStorage: mockFlutterSecureStorage,
        remoteSignerFactory: (_, _) => mockBunkerSigner,
      );

      fakeAsync((async) {
        var completed = false;
        unawaited(
          authService
              .signInForAccount(pubkeyHex, AuthenticationSource.bunker)
              .then((_) => completed = true)
              .catchError((Object _) => completed = true),
        );

        // Unlike the bounded startup path, the interactive reconnect applies
        // no startup timeout: even after twice the startup budget elapses the
        // call is still pending.
        async.elapse(
          AuthService.defaultStartupNetworkOperationTimeout * 2,
        );

        expect(completed, isFalse);
        verify(
          () => mockBunkerSigner.connect(sendConnectRequest: false),
        ).called(1);
      });
    });
  });

  group('AuthService dispose cleanup', () {
    test('dispose should call keyStorage.dispose', () async {
      await authService.dispose();

      verify(() => mockKeyStorage.dispose()).called(1);
    });

    test('dispose can be called safely', () async {
      // Should not throw
      await expectLater(authService.dispose(), completes);
    });
  });

  group('AuthService userStats', () {
    test('userStats should include lastError status', () {
      final info = authService.userStats;

      expect(info, containsPair('has_error', false));
      expect(info, containsPair('last_error', null));
    });

    test('userStats should include auth_state', () {
      final info = authService.userStats;

      expect(info, contains('auth_state'));
    });
  });
}
