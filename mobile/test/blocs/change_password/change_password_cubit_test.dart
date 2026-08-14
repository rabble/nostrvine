// ABOUTME: Tests for ChangePasswordCubit
// ABOUTME: Covers field validation, the success path, and refusal mapping

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/change_password/change_password_cubit.dart';
import 'package:openvine/repositories/account_credentials_repository.dart';
import 'package:openvine/utils/validators.dart';

class _MockAccountCredentialsRepository extends Mock
    implements AccountCredentialsRepository {}

void main() {
  group(ChangePasswordCubit, () {
    late _MockAccountCredentialsRepository repository;

    setUp(() {
      repository = _MockAccountCredentialsRepository();
    });

    ChangePasswordCubit buildSubject() =>
        ChangePasswordCubit(repository: repository);

    void stubResult(ChangePasswordResult result) {
      when(
        () => repository.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ).thenAnswer((_) async => result);
    }

    blocTest<ChangePasswordCubit, ChangePasswordState>(
      'reports the empty fields instead of calling the repository',
      build: buildSubject,
      act: (cubit) => cubit.submit(),
      expect: () => [
        isA<ChangePasswordState>()
            .having(
              (s) => s.currentPasswordMissing,
              'currentPasswordMissing',
              isTrue,
            )
            .having(
              (s) => s.newPasswordError,
              'newPasswordError',
              PasswordValidationError.missing,
            )
            .having(
              (s) => s.confirmPasswordError,
              'confirmPasswordError',
              ConfirmPasswordValidationError.missing,
            ),
      ],
      verify: (_) => verifyNever(
        () => repository.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ),
    );

    blocTest<ChangePasswordCubit, ChangePasswordState>(
      'refuses to submit a confirmation that does not match',
      build: buildSubject,
      act: (cubit) async {
        cubit
          ..updateCurrentPassword('hunter2')
          ..updateNewPassword('hunter22')
          ..updateConfirmPassword('hunter23');
        await cubit.submit();
      },
      skip: 3,
      expect: () => [
        isA<ChangePasswordState>()
            .having(
              (s) => s.confirmPasswordError,
              'confirmPasswordError',
              ConfirmPasswordValidationError.mismatch,
            )
            .having((s) => s.status, 'status', ChangePasswordStatus.editing),
      ],
      verify: (_) => verifyNever(
        () => repository.changePassword(
          currentPassword: any(named: 'currentPassword'),
          newPassword: any(named: 'newPassword'),
        ),
      ),
    );

    blocTest<ChangePasswordCubit, ChangePasswordState>(
      'sends both passwords and reports success',
      build: buildSubject,
      setUp: () => stubResult(ChangePasswordResult.success()),
      act: (cubit) async {
        cubit
          ..updateCurrentPassword('hunter2')
          ..updateNewPassword('hunter22')
          ..updateConfirmPassword('hunter22');
        await cubit.submit();
      },
      skip: 3,
      expect: () => [
        isA<ChangePasswordState>().having(
          (s) => s.status,
          'status',
          ChangePasswordStatus.submitting,
        ),
        isA<ChangePasswordState>().having(
          (s) => s.status,
          'status',
          ChangePasswordStatus.success,
        ),
      ],
      verify: (_) => verify(
        () => repository.changePassword(
          currentPassword: 'hunter2',
          newPassword: 'hunter22',
        ),
      ).called(1),
    );

    blocTest<ChangePasswordCubit, ChangePasswordState>(
      'surfaces a rejected current password as a recoverable reason',
      build: buildSubject,
      setUp: () => stubResult(
        ChangePasswordResult.failure(ChangePasswordFailure.wrongPassword),
      ),
      act: (cubit) async {
        cubit
          ..updateCurrentPassword('wrong')
          ..updateNewPassword('hunter22')
          ..updateConfirmPassword('hunter22');
        await cubit.submit();
      },
      skip: 4,
      expect: () => [
        isA<ChangePasswordState>()
            .having((s) => s.status, 'status', ChangePasswordStatus.failure)
            .having(
              (s) => s.failureReason,
              'failureReason',
              ChangePasswordFailureReason.wrongCurrentPassword,
            ),
      ],
    );

    blocTest<ChangePasswordCubit, ChangePasswordState>(
      'reads a server fault as the generic reason, not as a network problem',
      build: buildSubject,
      setUp: () => stubResult(
        ChangePasswordResult.failure(ChangePasswordFailure.server),
      ),
      act: (cubit) async {
        cubit
          ..updateCurrentPassword('hunter2')
          ..updateNewPassword('hunter22')
          ..updateConfirmPassword('hunter22');
        await cubit.submit();
      },
      skip: 4,
      expect: () => [
        isA<ChangePasswordState>().having(
          (s) => s.failureReason,
          'failureReason',
          ChangePasswordFailureReason.unknown,
        ),
      ],
    );

    blocTest<ChangePasswordCubit, ChangePasswordState>(
      'clears the refusal as soon as a field is edited again',
      build: buildSubject,
      setUp: () => stubResult(
        ChangePasswordResult.failure(ChangePasswordFailure.wrongPassword),
      ),
      act: (cubit) async {
        cubit
          ..updateCurrentPassword('wrong')
          ..updateNewPassword('hunter22')
          ..updateConfirmPassword('hunter22');
        await cubit.submit();
        cubit.updateCurrentPassword('hunter2');
      },
      skip: 5,
      expect: () => [
        isA<ChangePasswordState>()
            .having((s) => s.failureReason, 'failureReason', isNull)
            .having((s) => s.status, 'status', ChangePasswordStatus.editing),
      ],
    );

    test('never stringifies the passwords it is holding', () {
      const state = ChangePasswordState(
        currentPassword: 'old-secret-value',
        newPassword: 'new-secret-value',
        confirmPassword: 'new-secret-value',
      );

      // Equatable stringifies props by default in debug builds, and anything
      // that prints a state — DivineBlocObserver's `bloc.lastState` crash key
      // above all — would carry the plaintext with it.
      expect(state.toString(), isNot(contains('secret-value')));
    });
  });
}
