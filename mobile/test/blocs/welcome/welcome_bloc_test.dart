// ABOUTME: Tests for WelcomeBloc
// ABOUTME: Verifies multi-account loading, selection, and auth actions

import 'package:bloc_test/bloc_test.dart';
import 'package:db_client/db_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/welcome/welcome_bloc.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;

class _MockUserProfilesDao extends Mock implements UserProfilesDao {}

class _MockAuthService extends Mock implements AuthService {}

const _testPubkeyHex =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

const _testPubkeyHex2 =
    'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';

final _testProfile = UserProfile(
  pubkey: _testPubkeyHex,
  displayName: 'Test User',
  picture: 'https://example.com/avatar.png',
  nip05: 'testuser@example.com',
  rawData: const {},
  createdAt: DateTime(2024),
  eventId: 'e1e2e3e4e5e6e7e8e1e2e3e4e5e6e7e8e1e2e3e4e5e6e7e8e1e2e3e4e5e6e7e8',
);

final _testProfile2 = UserProfile(
  pubkey: _testPubkeyHex2,
  displayName: 'Second User',
  picture: 'https://example.com/avatar2.png',
  nip05: 'second@example.com',
  rawData: const {},
  createdAt: DateTime(2024),
  eventId: 'f1f2f3f4f5f6f7f8f1f2f3f4f5f6f7f8f1f2f3f4f5f6f7f8f1f2f3f4f5f6f7f8',
);

final _testKnownAccount = KnownAccount(
  pubkeyHex: _testPubkeyHex,
  authSource: AuthenticationSource.automatic,
  addedAt: DateTime(2024),
  lastUsedAt: DateTime(2024, 6),
);

final _testKnownAccount2 = KnownAccount(
  pubkeyHex: _testPubkeyHex2,
  authSource: AuthenticationSource.amber,
  addedAt: DateTime(2024),
  lastUsedAt: DateTime(2024, 3),
);

const _testPreviousAccount = PreviousAccount(
  pubkeyHex: _testPubkeyHex,
  authSource: AuthenticationSource.automatic,
);

const _testPreviousAccount2 = PreviousAccount(
  pubkeyHex: _testPubkeyHex2,
  authSource: AuthenticationSource.amber,
);

void main() {
  late _MockUserProfilesDao mockUserProfilesDao;
  late _MockAuthService mockAuthService;

  setUpAll(() {
    registerFallbackValue(AuthenticationSource.none);
  });

  setUp(() {
    mockUserProfilesDao = _MockUserProfilesDao();
    mockAuthService = _MockAuthService();

    when(() => mockAuthService.getKnownAccounts()).thenAnswer((_) async => []);
    when(() => mockAuthService.acceptTerms()).thenAnswer((_) async {});
    when(
      () => mockAuthService.signInForAccount(any(), any()),
    ).thenAnswer((_) async {});
  });

  WelcomeBloc buildBloc() => WelcomeBloc(
    userProfilesDao: mockUserProfilesDao,
    authService: mockAuthService,
  );

  group(WelcomeBloc, () {
    test('initial state is $WelcomeState with initial status', () {
      final bloc = buildBloc();
      expect(bloc.state, const WelcomeState());
      expect(bloc.state.status, WelcomeStatus.initial);
      bloc.close();
    });

    group('$WelcomeStarted', () {
      blocTest<WelcomeBloc, WelcomeState>(
        'emits loaded with no returning users when no known accounts',
        build: buildBloc,
        act: (bloc) => bloc.add(const WelcomeStarted()),
        expect: () => [const WelcomeState(status: WelcomeStatus.loaded)],
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'emits loaded with single returning user and profile',
        setUp: () {
          when(
            () => mockAuthService.getKnownAccounts(),
          ).thenAnswer((_) async => [_testKnownAccount]);
          when(
            () => mockUserProfilesDao.getProfile(_testPubkeyHex),
          ).thenAnswer((_) async => _testProfile);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const WelcomeStarted()),
        expect: () => [
          WelcomeState(
            status: WelcomeStatus.loaded,
            previousAccounts: [
              PreviousAccount(
                pubkeyHex: _testPubkeyHex,
                authSource: AuthenticationSource.automatic,
                profile: _testProfile,
              ),
            ],
          ),
        ],
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'emits loaded with account but null profile when not cached',
        setUp: () {
          when(
            () => mockAuthService.getKnownAccounts(),
          ).thenAnswer((_) async => [_testKnownAccount]);
          when(
            () => mockUserProfilesDao.getProfile(_testPubkeyHex),
          ).thenAnswer((_) async => null);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const WelcomeStarted()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.loaded,
            previousAccounts: [_testPreviousAccount],
          ),
        ],
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'emits loaded with account when profile lookup throws',
        setUp: () {
          when(
            () => mockAuthService.getKnownAccounts(),
          ).thenAnswer((_) async => [_testKnownAccount]);
          when(
            () => mockUserProfilesDao.getProfile(_testPubkeyHex),
          ).thenThrow(Exception('DB error'));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const WelcomeStarted()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.loaded,
            previousAccounts: [_testPreviousAccount],
          ),
        ],
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'emits loaded with multiple accounts in order',
        setUp: () {
          when(
            () => mockAuthService.getKnownAccounts(),
          ).thenAnswer((_) async => [_testKnownAccount, _testKnownAccount2]);
          when(
            () => mockUserProfilesDao.getProfile(_testPubkeyHex),
          ).thenAnswer((_) async => _testProfile);
          when(
            () => mockUserProfilesDao.getProfile(_testPubkeyHex2),
          ).thenAnswer((_) async => _testProfile2);
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const WelcomeStarted()),
        expect: () => [
          WelcomeState(
            status: WelcomeStatus.loaded,
            previousAccounts: [
              PreviousAccount(
                pubkeyHex: _testPubkeyHex,
                authSource: AuthenticationSource.automatic,
                profile: _testProfile,
              ),
              PreviousAccount(
                pubkeyHex: _testPubkeyHex2,
                authSource: AuthenticationSource.amber,
                profile: _testProfile2,
              ),
            ],
          ),
        ],
      );
    });

    group('$WelcomeLastUserDismissed', () {
      blocTest<WelcomeBloc, WelcomeState>(
        'clears returning user data',
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          previousAccounts: [_testPreviousAccount],
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const WelcomeLastUserDismissed()),
        expect: () => [const WelcomeState(status: WelcomeStatus.loaded)],
      );
    });

    group('$WelcomeLogBackInRequested', () {
      blocTest<WelcomeBloc, WelcomeState>(
        'emits accepting and calls signInForAccount with selected account',
        build: buildBloc,
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          previousAccounts: [_testPreviousAccount],
        ),
        act: (bloc) => bloc.add(const WelcomeLogBackInRequested()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.accepting,
            previousAccounts: [_testPreviousAccount],
            signingInPubkeyHex: _testPubkeyHex,
          ),
        ],
        verify: (_) {
          verify(
            () => mockAuthService.signInForAccount(
              _testPubkeyHex,
              AuthenticationSource.automatic,
            ),
          ).called(1);
        },
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'signs in with explicitly selected account from multi-account list',
        build: buildBloc,
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
          selectedPubkeyHex: _testPubkeyHex2,
        ),
        act: (bloc) => bloc.add(const WelcomeLogBackInRequested()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.accepting,
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
            selectedPubkeyHex: _testPubkeyHex2,
            signingInPubkeyHex: _testPubkeyHex2,
          ),
        ],
        verify: (_) {
          verify(
            () => mockAuthService.signInForAccount(
              _testPubkeyHex2,
              AuthenticationSource.amber,
            ),
          ).called(1);
        },
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'does nothing when no accounts exist',
        build: buildBloc,
        seed: () => const WelcomeState(status: WelcomeStatus.loaded),
        act: (bloc) => bloc.add(const WelcomeLogBackInRequested()),
        expect: () => <WelcomeState>[],
        verify: (_) {
          verifyNever(() => mockAuthService.signInForAccount(any(), any()));
        },
      );

      blocTest<WelcomeBloc, WelcomeState>(
        'emits error on signInForAccount failure',
        setUp: () {
          when(
            () => mockAuthService.signInForAccount(any(), any()),
          ).thenThrow(Exception('Network error'));
        },
        build: buildBloc,
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          previousAccounts: [_testPreviousAccount],
        ),
        act: (bloc) => bloc.add(const WelcomeLogBackInRequested()),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.accepting,
            previousAccounts: [_testPreviousAccount],
            signingInPubkeyHex: _testPubkeyHex,
          ),
          const WelcomeState(
            status: WelcomeStatus.error,
            previousAccounts: [_testPreviousAccount],
            error: 'Failed to continue: Exception: Network error',
          ),
        ],
      );
    });

    group('$WelcomeAccountSelected', () {
      blocTest<WelcomeBloc, WelcomeState>(
        'emits updated selectedPubkeyHex',
        build: buildBloc,
        seed: () => const WelcomeState(
          status: WelcomeStatus.loaded,
          previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
        ),
        act: (bloc) =>
            bloc.add(const WelcomeAccountSelected(pubkeyHex: _testPubkeyHex2)),
        expect: () => [
          const WelcomeState(
            status: WelcomeStatus.loaded,
            previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
            selectedPubkeyHex: _testPubkeyHex2,
          ),
        ],
      );
    });

    group('$WelcomeCreateAccountRequested', () {
      blocTest<WelcomeBloc, WelcomeState>(
        'calls acceptTerms and emits navigating then loaded',
        build: buildBloc,
        seed: () => const WelcomeState(status: WelcomeStatus.loaded),
        act: (bloc) => bloc.add(const WelcomeCreateAccountRequested()),
        expect: () => [
          const WelcomeState(status: WelcomeStatus.navigatingToCreateAccount),
          const WelcomeState(status: WelcomeStatus.loaded),
        ],
        verify: (_) {
          verify(() => mockAuthService.acceptTerms()).called(1);
        },
      );
    });

    group('$WelcomeLoginOptionsRequested', () {
      blocTest<WelcomeBloc, WelcomeState>(
        'calls acceptTerms and emits navigating then loaded',
        build: buildBloc,
        seed: () => const WelcomeState(status: WelcomeStatus.loaded),
        act: (bloc) => bloc.add(const WelcomeLoginOptionsRequested()),
        expect: () => [
          const WelcomeState(status: WelcomeStatus.navigatingToLoginOptions),
          const WelcomeState(status: WelcomeStatus.loaded),
        ],
        verify: (_) {
          verify(() => mockAuthService.acceptTerms()).called(1);
        },
      );
    });
  });

  group('$WelcomeState', () {
    test('hasReturningUsers is true when previousAccounts is not empty', () {
      const state = WelcomeState(previousAccounts: [_testPreviousAccount]);
      expect(state.hasReturningUsers, isTrue);
    });

    test('hasReturningUsers is false when previousAccounts is empty', () {
      const state = WelcomeState();
      expect(state.hasReturningUsers, isFalse);
    });

    test('isAccepting is true when status is accepting', () {
      const state = WelcomeState(status: WelcomeStatus.accepting);
      expect(state.isAccepting, isTrue);
    });

    test('selectedAccount returns first when no selection', () {
      const state = WelcomeState(
        previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
      );
      expect(state.selectedAccount, equals(_testPreviousAccount));
    });

    test('selectedAccount returns matching account', () {
      const state = WelcomeState(
        previousAccounts: [_testPreviousAccount, _testPreviousAccount2],
        selectedPubkeyHex: _testPubkeyHex2,
      );
      expect(state.selectedAccount, equals(_testPreviousAccount2));
    });

    test('selectedAccount returns first when selection not found', () {
      const state = WelcomeState(
        previousAccounts: [_testPreviousAccount],
        selectedPubkeyHex: _testPubkeyHex2,
      );
      expect(state.selectedAccount, equals(_testPreviousAccount));
    });

    test('selectedAccount returns null when no accounts', () {
      const state = WelcomeState();
      expect(state.selectedAccount, isNull);
    });

    test('copyWith clearAccounts removes accounts', () {
      const state = WelcomeState(
        status: WelcomeStatus.loaded,
        previousAccounts: [_testPreviousAccount],
      );
      final cleared = state.copyWith(clearAccounts: true);
      expect(cleared.previousAccounts, isEmpty);
      expect(cleared.status, WelcomeStatus.loaded);
    });

    test('copyWith clearSelectedPubkey removes selection', () {
      const state = WelcomeState(selectedPubkeyHex: _testPubkeyHex);
      final cleared = state.copyWith(clearSelectedPubkey: true);
      expect(cleared.selectedPubkeyHex, isNull);
    });

    test('copyWith clearSigningIn removes signing in state', () {
      const state = WelcomeState(signingInPubkeyHex: _testPubkeyHex);
      final cleared = state.copyWith(clearSigningIn: true);
      expect(cleared.signingInPubkeyHex, isNull);
    });

    test('copyWith clearError removes error', () {
      const state = WelcomeState(
        status: WelcomeStatus.error,
        error: 'some error',
      );
      final cleared = state.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });
  });
}
