// ABOUTME: Unit tests for SettingsAccountCubit
// ABOUTME: Covers load, switchToAccount, addNewAccount, and state helpers

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/settings_account/settings_account_cubit.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/draft_storage_service.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockDraftStorageService extends Mock implements DraftStorageService {}

void main() {
  group(SettingsAccountCubit, () {
    late _MockAuthService mockAuthService;
    late _MockDraftStorageService mockDraftStorageService;

    final testAccounts = [
      KnownAccount(
        pubkeyHex:
            'aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa111aaa1',
        authSource: AuthenticationSource.automatic,
        addedAt: DateTime(2024),
        lastUsedAt: DateTime(2024),
      ),
      KnownAccount(
        pubkeyHex:
            'bbb222bbb222bbb222bbb222bbb222bbb222bbb222bbb222bbb222bbb222bbb2',
        authSource: AuthenticationSource.automatic,
        addedAt: DateTime(2024),
        lastUsedAt: DateTime(2024),
      ),
    ];

    setUp(() {
      mockAuthService = _MockAuthService();
      mockDraftStorageService = _MockDraftStorageService();

      when(
        () => mockAuthService.getKnownAccounts(),
      ).thenAnswer((_) async => testAccounts);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn(testAccounts.first.pubkeyHex);
      when(
        () => mockDraftStorageService.getDraftCount(),
      ).thenAnswer((_) async => 0);
    });

    SettingsAccountCubit buildCubit() => SettingsAccountCubit(
      authService: mockAuthService,
      draftStorageService: mockDraftStorageService,
    );

    test('initial state is correct', () {
      final cubit = buildCubit();
      expect(cubit.state.status, equals(SettingsAccountStatus.initial));
      expect(cubit.state.accounts, isEmpty);
      expect(cubit.state.draftCount, equals(0));
      expect(cubit.state.currentPubkey, isNull);
    });

    blocTest<SettingsAccountCubit, SettingsAccountState>(
      'load emits loading then loaded with accounts and draft count',
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const SettingsAccountState(status: SettingsAccountStatus.loading),
        SettingsAccountState(
          status: SettingsAccountStatus.loaded,
          accounts: testAccounts,
          currentPubkey: testAccounts.first.pubkeyHex,
        ),
      ],
    );

    blocTest<SettingsAccountCubit, SettingsAccountState>(
      'load emits loading then loaded with non-zero draft count',
      setUp: () {
        when(
          () => mockDraftStorageService.getDraftCount(),
        ).thenAnswer((_) async => 3);
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const SettingsAccountState(status: SettingsAccountStatus.loading),
        SettingsAccountState(
          status: SettingsAccountStatus.loaded,
          accounts: testAccounts,
          draftCount: 3,
          currentPubkey: testAccounts.first.pubkeyHex,
        ),
      ],
    );

    blocTest<SettingsAccountCubit, SettingsAccountState>(
      'load emits failure when getKnownAccounts throws',
      setUp: () {
        when(
          () => mockAuthService.getKnownAccounts(),
        ).thenThrow(Exception('test error'));
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const SettingsAccountState(status: SettingsAccountStatus.loading),
        const SettingsAccountState(status: SettingsAccountStatus.failure),
      ],
      errors: () => [isA<Exception>()],
    );

    blocTest<SettingsAccountCubit, SettingsAccountState>(
      'load emits failure when getDraftCount throws',
      setUp: () {
        when(
          () => mockDraftStorageService.getDraftCount(),
        ).thenThrow(Exception('draft error'));
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        const SettingsAccountState(status: SettingsAccountStatus.loading),
        const SettingsAccountState(status: SettingsAccountStatus.failure),
      ],
      errors: () => [isA<Exception>()],
    );

    group('switchToAccount', () {
      blocTest<SettingsAccountCubit, SettingsAccountState>(
        'sets pending pubkey and signs out for different account',
        seed: () => SettingsAccountState(
          status: SettingsAccountStatus.loaded,
          accounts: testAccounts,
          currentPubkey: testAccounts.first.pubkeyHex,
        ),
        setUp: () {
          when(() => mockAuthService.signOut()).thenAnswer((_) async {});
        },
        build: buildCubit,
        act: (cubit) => cubit.switchToAccount(testAccounts.last.pubkeyHex),
        verify: (_) {
          verify(
            () => mockAuthService.pendingAccountSwitchPubkey =
                testAccounts.last.pubkeyHex,
          ).called(1);
          verify(() => mockAuthService.signOut()).called(1);
        },
      );

      blocTest<SettingsAccountCubit, SettingsAccountState>(
        'does nothing when switching to current account',
        seed: () => SettingsAccountState(
          status: SettingsAccountStatus.loaded,
          accounts: testAccounts,
          currentPubkey: testAccounts.first.pubkeyHex,
        ),
        build: buildCubit,
        act: (cubit) => cubit.switchToAccount(testAccounts.first.pubkeyHex),
        verify: (_) {
          verifyNever(() => mockAuthService.signOut());
        },
      );
    });

    group('addNewAccount', () {
      blocTest<SettingsAccountCubit, SettingsAccountState>(
        'signs out without setting pending pubkey',
        setUp: () {
          when(() => mockAuthService.signOut()).thenAnswer((_) async {});
        },
        build: buildCubit,
        act: (cubit) => cubit.addNewAccount(),
        verify: (_) {
          verify(() => mockAuthService.signOut()).called(1);
          verifyNever(() => mockAuthService.pendingAccountSwitchPubkey = any());
        },
      );
    });

    group('state helpers', () {
      test('hasMultipleAccounts returns true with 2+ accounts', () {
        final state = SettingsAccountState(accounts: testAccounts);
        expect(state.hasMultipleAccounts, isTrue);
      });

      test('hasMultipleAccounts returns false with single account', () {
        final state = SettingsAccountState(accounts: [testAccounts.first]);
        expect(state.hasMultipleAccounts, isFalse);
      });

      test('hasMultipleAccounts returns false with empty accounts', () {
        const state = SettingsAccountState();
        expect(state.hasMultipleAccounts, isFalse);
      });

      test('hasDrafts returns true when draftCount > 0', () {
        const state = SettingsAccountState(draftCount: 5);
        expect(state.hasDrafts, isTrue);
      });

      test('hasDrafts returns false when draftCount is 0', () {
        const state = SettingsAccountState();
        expect(state.hasDrafts, isFalse);
      });

      test('copyWith replaces only specified fields', () {
        final original = SettingsAccountState(
          status: SettingsAccountStatus.loaded,
          accounts: testAccounts,
          draftCount: 2,
          currentPubkey: 'pubkey1',
        );

        final copied = original.copyWith(draftCount: 5);
        expect(copied.status, equals(SettingsAccountStatus.loaded));
        expect(copied.accounts, equals(testAccounts));
        expect(copied.draftCount, equals(5));
        expect(copied.currentPubkey, equals('pubkey1'));
      });
    });
  });
}
