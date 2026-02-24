// ABOUTME: Tests for DivineAuthCubit
// ABOUTME: Verifies form state, validation, sign-in, sign-up, and error handling

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/divine_auth/divine_auth_cubit.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/pending_verification_service.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockAuthService extends Mock implements AuthService {}

class _MockPendingVerificationService extends Mock
    implements PendingVerificationService {}

class _FakeKeycastSession extends Fake implements KeycastSession {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeKeycastSession());
  });

  group(DivineAuthCubit, () {
    late _MockKeycastOAuth mockOAuth;
    late _MockAuthService mockAuthService;
    late _MockPendingVerificationService mockPendingVerification;

    const testEmail = 'test@example.com';
    const testPassword = 'password123';
    const testVerifier = 'test-verifier-xyz789';
    const testDeviceCode = 'test-device-code-abc123';
    const testCode = 'auth-code-456';

    setUp(() {
      mockOAuth = _MockKeycastOAuth();
      mockAuthService = _MockAuthService();
      mockPendingVerification = _MockPendingVerificationService();
    });

    DivineAuthCubit buildCubit() {
      return DivineAuthCubit(
        oauthClient: mockOAuth,
        authService: mockAuthService,
        pendingVerificationService: mockPendingVerification,
      );
    }

    group('initial state', () {
      test('is $DivineAuthInitial', () {
        final cubit = buildCubit();
        expect(cubit.state, isA<DivineAuthInitial>());
        cubit.close();
      });
    });

    group('initialize', () {
      blocTest<DivineAuthCubit, DivineAuthState>(
        'emits $DivineAuthFormState in sign-up mode by default',
        build: buildCubit,
        act: (cubit) => cubit.initialize(),
        expect: () => [const DivineAuthFormState()],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'emits $DivineAuthFormState in sign-in mode when isSignIn is true',
        build: buildCubit,
        act: (cubit) => cubit.initialize(isSignIn: true),
        expect: () => [const DivineAuthFormState(isSignIn: true)],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'emits $DivineAuthFormState with initial email when provided',
        build: buildCubit,
        act: (cubit) =>
            cubit.initialize(initialEmail: testEmail, isSignIn: true),
        expect: () => [
          const DivineAuthFormState(email: testEmail, isSignIn: true),
        ],
      );
    });

    group('updateEmail', () {
      blocTest<DivineAuthCubit, DivineAuthState>(
        'updates email and clears email and general errors',
        build: buildCubit,
        seed: () => const DivineAuthFormState(
          emailError: 'old error',
          generalError: 'old general error',
        ),
        act: (cubit) => cubit.updateEmail(testEmail),
        expect: () => [const DivineAuthFormState(email: testEmail)],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'does nothing when state is not $DivineAuthFormState',
        build: buildCubit,
        act: (cubit) => cubit.updateEmail(testEmail),
        expect: () => <DivineAuthState>[],
      );
    });

    group('updatePassword', () {
      blocTest<DivineAuthCubit, DivineAuthState>(
        'updates password and clears password and general errors',
        build: buildCubit,
        seed: () => const DivineAuthFormState(
          passwordError: 'old error',
          generalError: 'old general error',
        ),
        act: (cubit) => cubit.updatePassword(testPassword),
        expect: () => [const DivineAuthFormState(password: testPassword)],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'does nothing when state is not $DivineAuthFormState',
        build: buildCubit,
        act: (cubit) => cubit.updatePassword(testPassword),
        expect: () => <DivineAuthState>[],
      );
    });

    group('togglePasswordVisibility', () {
      blocTest<DivineAuthCubit, DivineAuthState>(
        'toggles obscurePassword from true to false',
        build: buildCubit,
        seed: () => const DivineAuthFormState(obscurePassword: true),
        act: (cubit) => cubit.togglePasswordVisibility(),
        expect: () => [const DivineAuthFormState(obscurePassword: false)],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'toggles obscurePassword from false to true',
        build: buildCubit,
        seed: () => const DivineAuthFormState(obscurePassword: false),
        act: (cubit) => cubit.togglePasswordVisibility(),
        expect: () => [const DivineAuthFormState(obscurePassword: true)],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'does nothing when state is not $DivineAuthFormState',
        build: buildCubit,
        act: (cubit) => cubit.togglePasswordVisibility(),
        expect: () => <DivineAuthState>[],
      );
    });

    group('submit', () {
      group('validation', () {
        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits email error when email is empty',
          build: buildCubit,
          seed: () => const DivineAuthFormState(password: testPassword),
          act: (cubit) => cubit.submit(),
          expect: () => [
            isA<DivineAuthFormState>().having(
              (s) => s.emailError,
              'emailError',
              isNotNull,
            ),
          ],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits email error when email is invalid',
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: 'not-an-email',
            password: testPassword,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            isA<DivineAuthFormState>().having(
              (s) => s.emailError,
              'emailError',
              isNotNull,
            ),
          ],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits password error when password is empty',
          build: buildCubit,
          seed: () => const DivineAuthFormState(email: testEmail),
          act: (cubit) => cubit.submit(),
          expect: () => [
            isA<DivineAuthFormState>().having(
              (s) => s.passwordError,
              'passwordError',
              isNotNull,
            ),
          ],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits password error when password is too short',
          build: buildCubit,
          seed: () =>
              const DivineAuthFormState(email: testEmail, password: 'short'),
          act: (cubit) => cubit.submit(),
          expect: () => [
            isA<DivineAuthFormState>().having(
              (s) => s.passwordError,
              'passwordError',
              isNotNull,
            ),
          ],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits both errors when email and password are empty',
          build: buildCubit,
          seed: () => const DivineAuthFormState(),
          act: (cubit) => cubit.submit(),
          expect: () => [
            isA<DivineAuthFormState>()
                .having((s) => s.emailError, 'emailError', isNotNull)
                .having((s) => s.passwordError, 'passwordError', isNotNull),
          ],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'does nothing when state is not $DivineAuthFormState',
          build: buildCubit,
          act: (cubit) => cubit.submit(),
          expect: () => <DivineAuthState>[],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'does nothing when already submitting',
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSubmitting: true,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => <DivineAuthState>[],
        );
      });

      group('sign in', () {
        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits submitting then $DivineAuthSuccess on successful sign in',
          setUp: () {
            when(
              () => mockOAuth.headlessLogin(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessLoginResult(success: true, code: testCode),
                testVerifier,
              ),
            );
            when(
              () => mockOAuth.exchangeCode(
                code: any(named: 'code'),
                verifier: any(named: 'verifier'),
              ),
            ).thenAnswer(
              (_) async => const TokenResponse(bunkerUrl: 'bunker://test'),
            );
            when(
              () => mockAuthService.signInWithDivineOAuth(any()),
            ).thenAnswer((_) async {});
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSignIn: true,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              isSubmitting: true,
            ),
            isA<DivineAuthSuccess>(),
          ],
          verify: (_) {
            verify(
              () => mockOAuth.headlessLogin(
                email: testEmail,
                password: testPassword,
                scope: 'policy:full',
              ),
            ).called(1);
            verify(
              () => mockOAuth.exchangeCode(
                code: testCode,
                verifier: testVerifier,
              ),
            ).called(1);
            verify(
              () => mockAuthService.signInWithDivineOAuth(any()),
            ).called(1);
          },
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits general error when login returns unsuccessful result',
          setUp: () {
            when(
              () => mockOAuth.headlessLogin(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessLoginResult(
                  success: false,
                  errorDescription: 'Invalid credentials',
                ),
                testVerifier,
              ),
            );
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSignIn: true,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              isSubmitting: true,
            ),
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              generalError: 'Invalid credentials',
            ),
          ],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits general error when login returns success but no code',
          setUp: () {
            when(
              () => mockOAuth.headlessLogin(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (HeadlessLoginResult(success: true), testVerifier),
            );
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSignIn: true,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              isSubmitting: true,
            ),
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              generalError: 'Sign in failed',
            ),
          ],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'uses error field as fallback when errorDescription is null',
          setUp: () {
            when(
              () => mockOAuth.headlessLogin(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessLoginResult(
                  success: false,
                  error: 'invalid_credentials',
                ),
                testVerifier,
              ),
            );
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSignIn: true,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              isSubmitting: true,
            ),
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              generalError: 'invalid_credentials',
            ),
          ],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits general error when code exchange throws $OAuthException',
          setUp: () {
            when(
              () => mockOAuth.headlessLogin(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessLoginResult(success: true, code: testCode),
                testVerifier,
              ),
            );
            when(
              () => mockOAuth.exchangeCode(
                code: any(named: 'code'),
                verifier: any(named: 'verifier'),
              ),
            ).thenThrow(OAuthException('Token exchange failed'));
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSignIn: true,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              isSubmitting: true,
            ),
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              generalError: 'Token exchange failed',
            ),
          ],
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits generic error when code exchange throws unexpected exception',
          setUp: () {
            when(
              () => mockOAuth.headlessLogin(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessLoginResult(success: true, code: testCode),
                testVerifier,
              ),
            );
            when(
              () => mockOAuth.exchangeCode(
                code: any(named: 'code'),
                verifier: any(named: 'verifier'),
              ),
            ).thenThrow(Exception('network timeout'));
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSignIn: true,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              isSubmitting: true,
            ),
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSignIn: true,
              generalError: 'Failed to complete authentication',
            ),
          ],
        );
      });

      group('sign up', () {
        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits $DivineAuthEmailVerification when verification is required',
          setUp: () {
            when(
              () => mockOAuth.headlessRegister(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessRegisterResult(
                  success: true,
                  pubkey: 'test-pubkey',
                  verificationRequired: true,
                  deviceCode: testDeviceCode,
                  email: testEmail,
                ),
                testVerifier,
              ),
            );
            when(
              () => mockPendingVerification.save(
                deviceCode: any(named: 'deviceCode'),
                verifier: any(named: 'verifier'),
                email: any(named: 'email'),
              ),
            ).thenAnswer((_) async {});
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSubmitting: true,
            ),
            const DivineAuthEmailVerification(
              email: testEmail,
              deviceCode: testDeviceCode,
              verifier: testVerifier,
            ),
          ],
          verify: (_) {
            verify(
              () => mockPendingVerification.save(
                deviceCode: testDeviceCode,
                verifier: testVerifier,
                email: testEmail,
              ),
            ).called(1);
          },
        );

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits general message when registration succeeds '
          'without verification required',
          setUp: () {
            when(
              () => mockOAuth.headlessRegister(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenAnswer(
              (_) async => (
                HeadlessRegisterResult(
                  success: true,
                  pubkey: 'test-pubkey',
                  verificationRequired: false,
                ),
                testVerifier,
              ),
            );
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSubmitting: true,
            ),
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              generalError: 'Registration complete. Please check your email.',
            ),
          ],
        );

        group('registration error codes', () {
          blocTest<DivineAuthCubit, DivineAuthState>(
            'maps email_exists error code to localized message',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult.error('Email taken', code: 'CONFLICT'),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              isA<DivineAuthFormState>().having(
                (s) => s.generalError,
                'generalError',
                contains('already registered'),
              ),
            ],
          );

          blocTest<DivineAuthCubit, DivineAuthState>(
            'maps invalid_email error code to localized message',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult.error(
                    'Bad email',
                    code: 'invalid_email',
                  ),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              isA<DivineAuthFormState>().having(
                (s) => s.generalError,
                'generalError',
                contains('valid email'),
              ),
            ],
          );

          blocTest<DivineAuthCubit, DivineAuthState>(
            'maps weak_password error code to localized message',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult.error('Weak', code: 'weak_password'),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              isA<DivineAuthFormState>().having(
                (s) => s.generalError,
                'generalError',
                contains('too weak'),
              ),
            ],
          );

          blocTest<DivineAuthCubit, DivineAuthState>(
            'maps rate_limited error code to localized message',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult.error(
                    'Slow down',
                    code: 'rate_limited',
                  ),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              isA<DivineAuthFormState>().having(
                (s) => s.generalError,
                'generalError',
                contains('Too many attempts'),
              ),
            ],
          );

          blocTest<DivineAuthCubit, DivineAuthState>(
            'maps server_error code to localized message',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult.error(
                    'Internal error',
                    code: 'server_error',
                  ),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              isA<DivineAuthFormState>().having(
                (s) => s.generalError,
                'generalError',
                contains('Server error'),
              ),
            ],
          );

          blocTest<DivineAuthCubit, DivineAuthState>(
            'maps connection_error code to localized message',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult.error(
                    'No network',
                    code: 'connection_error',
                  ),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              isA<DivineAuthFormState>().having(
                (s) => s.generalError,
                'generalError',
                contains('check your internet'),
              ),
            ],
          );

          blocTest<DivineAuthCubit, DivineAuthState>(
            'maps network_error code to localized message',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult.error(
                    'No network',
                    code: 'network_error',
                  ),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              isA<DivineAuthFormState>().having(
                (s) => s.generalError,
                'generalError',
                contains('check your internet'),
              ),
            ],
          );

          blocTest<DivineAuthCubit, DivineAuthState>(
            'falls back to server description for unknown error codes',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult(
                    success: false,
                    pubkey: '',
                    verificationRequired: false,
                    errorCode: 'unknown_code_xyz',
                    errorDescription: 'A server-provided description',
                  ),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                generalError: 'A server-provided description',
              ),
            ],
          );

          blocTest<DivineAuthCubit, DivineAuthState>(
            'falls back to generic message when error code and '
            'description are null',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult(
                    success: false,
                    pubkey: '',
                    verificationRequired: false,
                  ),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              isA<DivineAuthFormState>().having(
                (s) => s.generalError,
                'generalError',
                contains('Registration failed'),
              ),
            ],
          );

          blocTest<DivineAuthCubit, DivineAuthState>(
            'uses generic fallback for registration_failed error code',
            setUp: () {
              when(
                () => mockOAuth.headlessRegister(
                  email: any(named: 'email'),
                  password: any(named: 'password'),
                  scope: any(named: 'scope'),
                ),
              ).thenAnswer(
                (_) async => (
                  HeadlessRegisterResult.error(
                    'Failed',
                    code: 'registration_failed',
                  ),
                  testVerifier,
                ),
              );
            },
            build: buildCubit,
            seed: () => const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
            ),
            act: (cubit) => cubit.submit(),
            expect: () => [
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                isSubmitting: true,
              ),
              const DivineAuthFormState(
                email: testEmail,
                password: testPassword,
                generalError: 'Failed',
              ),
            ],
          );
        });

        blocTest<DivineAuthCubit, DivineAuthState>(
          'emits general error when headlessRegister throws',
          setUp: () {
            when(
              () => mockOAuth.headlessRegister(
                email: any(named: 'email'),
                password: any(named: 'password'),
                scope: any(named: 'scope'),
              ),
            ).thenThrow(Exception('network failure'));
          },
          build: buildCubit,
          seed: () => const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
          ),
          act: (cubit) => cubit.submit(),
          expect: () => [
            const DivineAuthFormState(
              email: testEmail,
              password: testPassword,
              isSubmitting: true,
            ),
            isA<DivineAuthFormState>().having(
              (s) => s.generalError,
              'generalError',
              contains('unexpected error'),
            ),
          ],
        );
      });
    });

    group('sendPasswordResetEmail', () {
      blocTest<DivineAuthCubit, DivineAuthState>(
        'calls sendPasswordResetEmail on oauth client',
        setUp: () {
          when(
            () => mockOAuth.sendPasswordResetEmail(any()),
          ).thenAnswer((_) async => ForgotPasswordResult(success: true));
        },
        build: buildCubit,
        act: (cubit) => cubit.sendPasswordResetEmail(testEmail),
        expect: () => <DivineAuthState>[],
        verify: (_) {
          verify(() => mockOAuth.sendPasswordResetEmail(testEmail)).called(1);
        },
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'handles failed password reset without emitting error state',
        setUp: () {
          when(() => mockOAuth.sendPasswordResetEmail(any())).thenAnswer(
            (_) async =>
                ForgotPasswordResult(success: false, error: 'Not found'),
          );
        },
        build: buildCubit,
        act: (cubit) => cubit.sendPasswordResetEmail(testEmail),
        expect: () => <DivineAuthState>[],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'handles exception without emitting error state',
        setUp: () {
          when(
            () => mockOAuth.sendPasswordResetEmail(any()),
          ).thenThrow(Exception('network error'));
        },
        build: buildCubit,
        act: (cubit) => cubit.sendPasswordResetEmail(testEmail),
        expect: () => <DivineAuthState>[],
      );
    });

    group('skipWithAnonymousAccount', () {
      blocTest<DivineAuthCubit, DivineAuthState>(
        'emits isSkipping then $DivineAuthSuccess on success',
        setUp: () {
          when(
            () => mockAuthService.createAnonymousAccount(),
          ).thenAnswer((_) async {});
        },
        build: buildCubit,
        seed: () =>
            const DivineAuthFormState(email: testEmail, password: testPassword),
        act: (cubit) => cubit.skipWithAnonymousAccount(),
        expect: () => [
          const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSkipping: true,
          ),
          isA<DivineAuthSuccess>(),
        ],
        verify: (_) {
          verify(() => mockAuthService.createAnonymousAccount()).called(1);
        },
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'emits isSkipping then generalError on failure',
        setUp: () {
          when(
            () => mockAuthService.createAnonymousAccount(),
          ).thenThrow(Exception('identity creation failed'));
        },
        build: buildCubit,
        seed: () =>
            const DivineAuthFormState(email: testEmail, password: testPassword),
        act: (cubit) => cubit.skipWithAnonymousAccount(),
        expect: () => [
          const DivineAuthFormState(
            email: testEmail,
            password: testPassword,
            isSkipping: true,
          ),
          isA<DivineAuthFormState>()
              .having((s) => s.isSkipping, 'isSkipping', isFalse)
              .having((s) => s.generalError, 'generalError', isNotNull),
        ],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'does nothing when state is not $DivineAuthFormState',
        build: buildCubit,
        act: (cubit) => cubit.skipWithAnonymousAccount(),
        expect: () => <DivineAuthState>[],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'does nothing when already skipping',
        build: buildCubit,
        seed: () => const DivineAuthFormState(isSkipping: true),
        act: (cubit) => cubit.skipWithAnonymousAccount(),
        expect: () => <DivineAuthState>[],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'does nothing when already submitting',
        build: buildCubit,
        seed: () => const DivineAuthFormState(isSubmitting: true),
        act: (cubit) => cubit.skipWithAnonymousAccount(),
        expect: () => <DivineAuthState>[],
      );
    });

    group('returnToForm', () {
      blocTest<DivineAuthCubit, DivineAuthState>(
        'returns to form with email preserved from '
        '$DivineAuthEmailVerification state',
        build: buildCubit,
        seed: () => const DivineAuthEmailVerification(
          email: testEmail,
          deviceCode: testDeviceCode,
          verifier: testVerifier,
        ),
        act: (cubit) => cubit.returnToForm(),
        expect: () => [const DivineAuthFormState(email: testEmail)],
      );

      blocTest<DivineAuthCubit, DivineAuthState>(
        'returns to default form state from non-verification state',
        build: buildCubit,
        seed: () => const DivineAuthSuccess(),
        act: (cubit) => cubit.returnToForm(),
        expect: () => [const DivineAuthFormState()],
      );
    });

    group('$DivineAuthFormState', () {
      test('canSubmit returns true when form is valid and not submitting', () {
        const state = DivineAuthFormState(
          email: testEmail,
          password: testPassword,
        );
        expect(state.canSubmit, isTrue);
      });

      test('canSubmit returns false when email is empty', () {
        const state = DivineAuthFormState(password: testPassword);
        expect(state.canSubmit, isFalse);
      });

      test('canSubmit returns false when password is empty', () {
        const state = DivineAuthFormState(email: testEmail);
        expect(state.canSubmit, isFalse);
      });

      test('canSubmit returns false when there is an email error', () {
        const state = DivineAuthFormState(
          email: testEmail,
          password: testPassword,
          emailError: 'Invalid',
        );
        expect(state.canSubmit, isFalse);
      });

      test('canSubmit returns false when there is a password error', () {
        const state = DivineAuthFormState(
          email: testEmail,
          password: testPassword,
          passwordError: 'Too short',
        );
        expect(state.canSubmit, isFalse);
      });

      test('canSubmit returns false when submitting', () {
        const state = DivineAuthFormState(
          email: testEmail,
          password: testPassword,
          isSubmitting: true,
        );
        expect(state.canSubmit, isFalse);
      });

      test('canSubmit returns false when skipping', () {
        const state = DivineAuthFormState(
          email: testEmail,
          password: testPassword,
          isSkipping: true,
        );
        expect(state.canSubmit, isFalse);
      });

      test('copyWith preserves values when no arguments provided', () {
        const original = DivineAuthFormState(
          email: testEmail,
          password: testPassword,
          isSignIn: true,
          emailError: 'err',
          passwordError: 'perr',
          generalError: 'gerr',
          obscurePassword: false,
          isSubmitting: true,
        );
        final copied = original.copyWith();
        expect(copied, equals(original));
      });

      test('copyWith clears errors when clear flags are set', () {
        const original = DivineAuthFormState(
          email: testEmail,
          emailError: 'err',
          passwordError: 'perr',
          generalError: 'gerr',
        );
        final cleared = original.copyWith(
          clearEmailError: true,
          clearPasswordError: true,
          clearGeneralError: true,
        );
        expect(cleared.emailError, isNull);
        expect(cleared.passwordError, isNull);
        expect(cleared.generalError, isNull);
      });

      test('props contains all fields', () {
        const state = DivineAuthFormState(
          email: testEmail,
          password: testPassword,
          isSignIn: true,
          emailError: 'e',
          passwordError: 'p',
          generalError: 'g',
          obscurePassword: false,
          isSubmitting: true,
        );
        expect(state.props, hasLength(9));
      });
    });

    group('$DivineAuthEmailVerification', () {
      test('props contains all fields', () {
        const state = DivineAuthEmailVerification(
          email: testEmail,
          deviceCode: testDeviceCode,
          verifier: testVerifier,
        );
        expect(state.props, equals([testEmail, testDeviceCode, testVerifier]));
      });

      test('two states with same values are equal', () {
        const a = DivineAuthEmailVerification(
          email: testEmail,
          deviceCode: testDeviceCode,
          verifier: testVerifier,
        );
        const b = DivineAuthEmailVerification(
          email: testEmail,
          deviceCode: testDeviceCode,
          verifier: testVerifier,
        );
        expect(a, equals(b));
      });
    });
  });
}
