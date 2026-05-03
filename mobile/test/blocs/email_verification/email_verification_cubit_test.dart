// ABOUTME: Tests for EmailVerificationCubit
// ABOUTME: Verifies polling lifecycle, state transitions, and error handling

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart';
import 'package:openvine/services/auth_service.dart';

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

class _MockAuthService extends Mock implements AuthService {}

class _MockInviteApiClient extends Mock implements InviteApiClient {}

class _FakeKeycastSession extends Fake implements KeycastSession {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeKeycastSession());
    registerFallbackValue(
      const OAuthConfig(
        serverUrl: 'https://login.divine.video',
        clientId: 'client-id',
        redirectUri: 'divine://auth',
      ),
    );
  });

  group('EmailVerificationCubit', () {
    late _MockKeycastOAuth mockOAuth;
    late _MockAuthService mockAuthService;
    late _MockInviteApiClient mockInviteApiClient;

    const testDeviceCode = 'test-device-code-abc123';
    const testVerifier = 'test-verifier-xyz789';
    const testEmail = 'test@example.com';

    setUp(() {
      mockOAuth = _MockKeycastOAuth();
      mockAuthService = _MockAuthService();
      mockInviteApiClient = _MockInviteApiClient();
      // Reset static state to ensure test isolation
      EmailVerificationCubit.resetCompletedDeviceCode();
    });

    EmailVerificationCubit buildCubit() {
      return EmailVerificationCubit(
        oauthClient: mockOAuth,
        authService: mockAuthService,
        inviteApiClient: mockInviteApiClient,
      );
    }

    group('initial state', () {
      test('has correct initial state', () {
        final cubit = buildCubit();

        expect(cubit.state, const EmailVerificationState());
        expect(cubit.state.status, EmailVerificationStatus.initial);
        expect(cubit.state.isPolling, isFalse);
        expect(cubit.state.pendingEmail, isNull);
        expect(cubit.state.errorCode, isNull);

        cubit.close();
      });
    });

    group('startPolling', () {
      blocTest<EmailVerificationCubit, EmailVerificationState>(
        'emits polling state with email',
        build: buildCubit,
        act: (cubit) => cubit.startPolling(
          deviceCode: testDeviceCode,
          verifier: testVerifier,
          email: testEmail,
        ),
        expect: () => [
          const EmailVerificationState(
            status: EmailVerificationStatus.polling,
            pendingEmail: testEmail,
          ),
        ],
      );

      blocTest<EmailVerificationCubit, EmailVerificationState>(
        'sets isPolling to true',
        build: buildCubit,
        act: (cubit) => cubit.startPolling(
          deviceCode: testDeviceCode,
          verifier: testVerifier,
          email: testEmail,
        ),
        verify: (cubit) {
          expect(cubit.state.isPolling, isTrue);
          expect(cubit.state.pendingEmail, testEmail);
        },
      );
    });

    group('invite activation', () {
      const testCode = 'auth-code-from-server';

      test('consumes invite with exchanged session before sign in', () {
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isAnonymous).thenReturn(false);
        when(() => mockOAuth.config).thenReturn(
          const OAuthConfig(
            serverUrl: 'https://login.divine.video',
            clientId: 'client-id',
            redirectUri: 'divine://auth',
          ),
        );
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.complete(testCode));
        when(
          () => mockOAuth.exchangeCode(code: testCode, verifier: testVerifier),
        ).thenAnswer(
          (_) async => const TokenResponse(bunkerUrl: 'wss://relay.test'),
        );
        when(
          () => mockInviteApiClient.consumeInviteWithSession(
            code: any(named: 'code'),
            oauthConfig: any(named: 'oauthConfig'),
            session: any(named: 'session'),
          ),
        ).thenAnswer(
          (_) async =>
              const InviteConsumeResult(message: 'Welcome', codesAllocated: 5),
        );
        when(
          () => mockAuthService.signInWithDivineOAuth(any()),
        ).thenAnswer((_) async {});

        fakeAsync((fake) {
          final cubit = buildCubit();
          cubit.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
            inviteCode: 'ab12ef34',
          );

          fake.elapse(const Duration(seconds: 4));

          expect(cubit.state.status, EmailVerificationStatus.success);
          verifyInOrder([
            () =>
                mockOAuth.exchangeCode(code: testCode, verifier: testVerifier),
            () => mockInviteApiClient.consumeInviteWithSession(
              code: 'AB12-EF34',
              oauthConfig: any(named: 'oauthConfig'),
              session: any(named: 'session'),
            ),
            () => mockAuthService.signInWithDivineOAuth(any()),
          ]);

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('emits failure when invite activation fails', () {
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockOAuth.config).thenReturn(
          const OAuthConfig(
            serverUrl: 'https://login.divine.video',
            clientId: 'client-id',
            redirectUri: 'divine://auth',
          ),
        );
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.complete(testCode));
        when(
          () => mockOAuth.exchangeCode(code: testCode, verifier: testVerifier),
        ).thenAnswer(
          (_) async => const TokenResponse(bunkerUrl: 'wss://relay.test'),
        );
        when(
          () => mockInviteApiClient.consumeInviteWithSession(
            code: any(named: 'code'),
            oauthConfig: any(named: 'oauthConfig'),
            session: any(named: 'session'),
          ),
        ).thenThrow(const InviteApiException('Invite activation failed'));

        fakeAsync((fake) {
          final cubit = buildCubit();
          cubit.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
            inviteCode: 'ab12ef34',
          );

          fake.elapse(const Duration(seconds: 4));

          expect(cubit.state.status, EmailVerificationStatus.failure);
          expect(cubit.state.errorCode, EmailVerificationError.inviteUnknown);
          expect(cubit.state.showInviteGateRecovery, isTrue);
          expect(cubit.state.inviteRecoveryCode, 'AB12-EF34');
          verifyNever(() => mockAuthService.signInWithDivineOAuth(any()));

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      // Regression: server returns 409 "Another consumption is in progress;
      // retry" when invite consumption races (e.g. user double-taps the
      // verification link or the polling timer hits the same code twice).
      // The server message literally tells the client to retry, but the
      // cubit used to give up immediately, leaving the user stuck on the
      // verify-email screen.
      test(
        'retries invite consumption on 409 conflict and succeeds on retry',
        () {
          when(() => mockAuthService.isRegistered).thenReturn(false);
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
          when(() => mockAuthService.isAnonymous).thenReturn(false);
          when(() => mockOAuth.config).thenReturn(
            const OAuthConfig(
              serverUrl: 'https://login.divine.video',
              clientId: 'client-id',
              redirectUri: 'divine://auth',
            ),
          );
          when(
            () => mockOAuth.pollForCode(testDeviceCode),
          ).thenAnswer((_) async => PollResult.complete(testCode));
          when(
            () =>
                mockOAuth.exchangeCode(code: testCode, verifier: testVerifier),
          ).thenAnswer(
            (_) async => const TokenResponse(bunkerUrl: 'wss://relay.test'),
          );

          var consumeCallCount = 0;
          when(
            () => mockInviteApiClient.consumeInviteWithSession(
              code: any(named: 'code'),
              oauthConfig: any(named: 'oauthConfig'),
              session: any(named: 'session'),
            ),
          ).thenAnswer((_) async {
            consumeCallCount++;
            if (consumeCallCount == 1) {
              throw const InviteApiException(
                'Another consumption is in progress; retry',
                statusCode: 409,
              );
            }
            return const InviteConsumeResult(
              message: 'Welcome',
              codesAllocated: 5,
            );
          });
          when(
            () => mockAuthService.signInWithDivineOAuth(any()),
          ).thenAnswer((_) async {});

          fakeAsync((fake) {
            final cubit = buildCubit();
            cubit.startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
              inviteCode: 'ab12ef34',
            );

            // Poll fires after 3s; retry waits another ~500ms.
            fake.elapse(const Duration(seconds: 5));

            expect(cubit.state.status, EmailVerificationStatus.success);
            expect(
              consumeCallCount,
              equals(2),
              reason:
                  'Cubit should retry once on 409 before considering '
                  'invite consumption successful.',
            );
            verify(
              () => mockAuthService.signInWithDivineOAuth(any()),
            ).called(1);

            cubit.close();
            fake.flushMicrotasks();
          });
        },
      );

      test('gives up after exhausting retries on persistent 409', () {
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockOAuth.config).thenReturn(
          const OAuthConfig(
            serverUrl: 'https://login.divine.video',
            clientId: 'client-id',
            redirectUri: 'divine://auth',
          ),
        );
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.complete(testCode));
        when(
          () => mockOAuth.exchangeCode(code: testCode, verifier: testVerifier),
        ).thenAnswer(
          (_) async => const TokenResponse(bunkerUrl: 'wss://relay.test'),
        );

        var consumeCallCount = 0;
        when(
          () => mockInviteApiClient.consumeInviteWithSession(
            code: any(named: 'code'),
            oauthConfig: any(named: 'oauthConfig'),
            session: any(named: 'session'),
          ),
        ).thenAnswer((_) async {
          consumeCallCount++;
          throw const InviteApiException(
            'Another consumption is in progress; retry',
            statusCode: 409,
          );
        });

        fakeAsync((fake) {
          final cubit = buildCubit();
          cubit.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
            inviteCode: 'ab12ef34',
          );

          // Generous elapse so all retries can play out.
          fake.elapse(const Duration(seconds: 30));

          expect(cubit.state.status, EmailVerificationStatus.failure);
          expect(
            consumeCallCount,
            greaterThan(1),
            reason:
                'Cubit should retry at least once on 409 before giving '
                'up.',
          );
          verifyNever(() => mockAuthService.signInWithDivineOAuth(any()));

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('does NOT retry on non-conflict InviteApiException (e.g. 400)', () {
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockOAuth.config).thenReturn(
          const OAuthConfig(
            serverUrl: 'https://login.divine.video',
            clientId: 'client-id',
            redirectUri: 'divine://auth',
          ),
        );
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.complete(testCode));
        when(
          () => mockOAuth.exchangeCode(code: testCode, verifier: testVerifier),
        ).thenAnswer(
          (_) async => const TokenResponse(bunkerUrl: 'wss://relay.test'),
        );

        var consumeCallCount = 0;
        when(
          () => mockInviteApiClient.consumeInviteWithSession(
            code: any(named: 'code'),
            oauthConfig: any(named: 'oauthConfig'),
            session: any(named: 'session'),
          ),
        ).thenAnswer((_) async {
          consumeCallCount++;
          throw const InviteApiException(
            'Invite is not valid',
            statusCode: 400,
          );
        });

        fakeAsync((fake) {
          final cubit = buildCubit();
          cubit.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
            inviteCode: 'ab12ef34',
          );

          fake.elapse(const Duration(seconds: 5));

          expect(cubit.state.status, EmailVerificationStatus.failure);
          expect(
            consumeCallCount,
            equals(1),
            reason: 'Non-409 invite errors must not be retried.',
          );

          cubit.close();
          fake.flushMicrotasks();
        });
      });
    });

    group('stopPolling', () {
      blocTest<EmailVerificationCubit, EmailVerificationState>(
        'clears state and stops polling',
        build: buildCubit,
        seed: () => const EmailVerificationState(
          status: EmailVerificationStatus.polling,
          pendingEmail: testEmail,
        ),
        act: (cubit) => cubit.stopPolling(),
        expect: () => [const EmailVerificationState()],
        verify: (cubit) {
          expect(cubit.state.isPolling, isFalse);
          expect(cubit.state.pendingEmail, isNull);
          expect(cubit.state.errorCode, isNull);
        },
      );

      blocTest<EmailVerificationCubit, EmailVerificationState>(
        'preserves success state to avoid UI flash',
        build: buildCubit,
        seed: () => const EmailVerificationState(
          status: EmailVerificationStatus.success,
        ),
        act: (cubit) => cubit.stopPolling(),
        expect: () => <EmailVerificationState>[],
        verify: (cubit) {
          expect(cubit.state.status, EmailVerificationStatus.success);
        },
      );
    });

    group('reset', () {
      blocTest<EmailVerificationCubit, EmailVerificationState>(
        'resets from success state to initial',
        build: buildCubit,
        seed: () => const EmailVerificationState(
          status: EmailVerificationStatus.success,
        ),
        act: (cubit) => cubit.reset(),
        expect: () => [const EmailVerificationState()],
        verify: (cubit) {
          expect(cubit.state.status, EmailVerificationStatus.initial);
        },
      );

      blocTest<EmailVerificationCubit, EmailVerificationState>(
        'resets from polling state to initial',
        build: buildCubit,
        seed: () => const EmailVerificationState(
          status: EmailVerificationStatus.polling,
          pendingEmail: testEmail,
        ),
        act: (cubit) => cubit.reset(),
        expect: () => [const EmailVerificationState()],
        verify: (cubit) {
          expect(cubit.state.status, EmailVerificationStatus.initial);
          expect(cubit.state.pendingEmail, isNull);
        },
      );

      blocTest<EmailVerificationCubit, EmailVerificationState>(
        'resets from failure state to initial',
        build: buildCubit,
        seed: () => const EmailVerificationState(
          status: EmailVerificationStatus.failure,
          errorCode: EmailVerificationError.timeout,
        ),
        act: (cubit) => cubit.reset(),
        expect: () => [const EmailVerificationState()],
        verify: (cubit) {
          expect(cubit.state.status, EmailVerificationStatus.initial);
          expect(cubit.state.errorCode, isNull);
        },
      );
    });

    group('zombie cubit detection', () {
      const testCode = 'auth-code-from-server';

      test('zombie cubit stops polling when device code already completed', () {
        // Simulate cubit #1 (the one that completed verification)
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isAnonymous).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.complete(testCode));
        when(
          () => mockOAuth.exchangeCode(code: testCode, verifier: testVerifier),
        ).thenAnswer(
          (_) async => const TokenResponse(bunkerUrl: 'wss://relay.test'),
        );
        when(
          () => mockAuthService.signInWithDivineOAuth(any()),
        ).thenAnswer((_) async {});

        fakeAsync((fake) {
          final cubit1 = buildCubit();
          cubit1.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
          );

          // Let the first poll cycle complete (exchange succeeds)
          fake.elapse(const Duration(seconds: 4));

          // Cubit #1 should have completed and set the static field
          expect(cubit1.state.status, EmailVerificationStatus.success);

          // Simulate cubit #2 (zombie from engine restart, different
          // auth service that doesn't know about the sign-in)
          final zombieOAuth = _MockKeycastOAuth();
          final zombieAuthService = _MockAuthService();
          when(() => zombieAuthService.isAuthenticated).thenReturn(false);
          when(() => zombieAuthService.isRegistered).thenReturn(false);
          when(
            () => zombieOAuth.pollForCode(testDeviceCode),
          ).thenAnswer((_) async => PollResult.pending());

          final cubit2 = EmailVerificationCubit(
            oauthClient: zombieOAuth,
            authService: zombieAuthService,
          );
          cubit2.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
          );

          // Let the zombie's first poll cycle run
          fake.elapse(const Duration(seconds: 4));

          // Zombie should have emitted success (so the screen navigates)
          expect(cubit2.state.status, EmailVerificationStatus.success);

          // pollForCode should NOT have been called on the zombie
          // because the static guard fires before the network call
          verifyNever(() => zombieOAuth.pollForCode(any()));

          cubit1.close();
          cubit2.close();
          fake.flushMicrotasks();
        });
      });

      test('different device code is not affected by completed code', () {
        // Simulate cubit #1 completing with one device code
        when(() => mockAuthService.isAuthenticated).thenReturn(false);
        when(() => mockAuthService.isAnonymous).thenReturn(false);
        when(() => mockAuthService.isRegistered).thenReturn(false);
        when(
          () => mockOAuth.pollForCode(testDeviceCode),
        ).thenAnswer((_) async => PollResult.complete(testCode));
        when(
          () => mockOAuth.exchangeCode(code: testCode, verifier: testVerifier),
        ).thenAnswer(
          (_) async => const TokenResponse(bunkerUrl: 'wss://relay.test'),
        );
        when(
          () => mockAuthService.signInWithDivineOAuth(any()),
        ).thenAnswer((_) async {});

        fakeAsync((fake) {
          final cubit1 = buildCubit();
          cubit1.startPolling(
            deviceCode: testDeviceCode,
            verifier: testVerifier,
            email: testEmail,
          );
          fake.elapse(const Duration(seconds: 4));

          // Now a NEW registration with a different device code should
          // NOT be blocked
          const newDeviceCode = 'new-device-code-different';
          final newOAuth = _MockKeycastOAuth();
          final newAuthService = _MockAuthService();
          when(() => newAuthService.isAuthenticated).thenReturn(false);
          when(() => newAuthService.isRegistered).thenReturn(false);
          when(
            () => newOAuth.pollForCode(newDeviceCode),
          ).thenAnswer((_) async => PollResult.pending());

          final cubit2 = EmailVerificationCubit(
            oauthClient: newOAuth,
            authService: newAuthService,
          );
          cubit2.startPolling(
            deviceCode: newDeviceCode,
            verifier: testVerifier,
            email: testEmail,
          );
          fake.elapse(const Duration(seconds: 4));

          // pollForCode SHOULD have been called — different device code
          verify(() => newOAuth.pollForCode(newDeviceCode)).called(1);

          cubit1.close();
          cubit2.close();
          fake.flushMicrotasks();
        });
      });
    });

    group('stale authSource guard', () {
      // Regression test for: isRegistered returns true based on _authSource
      // which persists across sign-outs. On a device with a prior OAuth session,
      // _authSource stays divineOAuth even after auth state goes unauthenticated.
      // The polling guard must require isAuthenticated AND isRegistered or it
      // kills legitimate new-user registration polls on the first tick.
      test(
        'does not stop polling when isRegistered=true but isAuthenticated=false',
        () {
          // Simulate stale authSource: device had a prior OAuth session (signed
          // out), so isRegistered=true but isAuthenticated=false.
          when(() => mockAuthService.isAuthenticated).thenReturn(false);
          when(() => mockAuthService.isRegistered).thenReturn(true);
          when(
            () => mockOAuth.pollForCode(testDeviceCode),
          ).thenAnswer((_) async => PollResult.pending());

          fakeAsync((fake) {
            final cubit = buildCubit();
            cubit.startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

            // Advance past two poll cycles (fires at t=3s and t=6s)
            fake.elapse(const Duration(seconds: 7));

            // Polling should still be running — guard must NOT have fired
            expect(cubit.state.status, EmailVerificationStatus.polling);
            verify(
              () => mockOAuth.pollForCode(testDeviceCode),
            ).called(greaterThanOrEqualTo(2));

            // Cancel timers before fakeAsync exits
            cubit.close();
            fake.flushMicrotasks();
          });
        },
      );

      test(
        'stops polling when both isAuthenticated=true and isRegistered=true',
        () {
          // Guard should still fire for the legitimate zombie-cubit case:
          // user IS authenticated AND registered (completed sign-in elsewhere).
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(() => mockAuthService.isRegistered).thenReturn(true);
          when(
            () => mockOAuth.pollForCode(testDeviceCode),
          ).thenAnswer((_) async => PollResult.pending());

          fakeAsync((fake) {
            final cubit = buildCubit();
            cubit.startPolling(
              deviceCode: testDeviceCode,
              verifier: testVerifier,
              email: testEmail,
            );

            // Advance past first poll tick (fires at t=3s, guard cancels timers)
            fake.elapse(const Duration(seconds: 4));

            // Guard fires before the network call — pollForCode never called.
            // (The cubit stops its timer silently without emitting a state change.)
            verifyNever(() => mockOAuth.pollForCode(any()));

            cubit.close();
            fake.flushMicrotasks();
          });
        },
      );
    });

    group('close', () {
      test('cleans up timers on close', () async {
        final cubit = buildCubit();

        cubit.startPolling(
          deviceCode: testDeviceCode,
          verifier: testVerifier,
          email: testEmail,
        );

        expect(cubit.state.isPolling, isTrue);

        await cubit.close();

        // Cubit should be closed without errors
        // (verifying no lingering timers cause issues)
      });
    });
  });

  group('EmailVerificationState', () {
    test('creates with default values', () {
      const state = EmailVerificationState();

      expect(state.status, EmailVerificationStatus.initial);
      expect(state.isPolling, isFalse);
      expect(state.pendingEmail, isNull);
      expect(state.errorCode, isNull);
    });

    test('creates with custom values', () {
      const state = EmailVerificationState(
        status: EmailVerificationStatus.polling,
        pendingEmail: 'test@example.com',
        errorCode: EmailVerificationError.timeout,
      );

      expect(state.status, EmailVerificationStatus.polling);
      expect(state.isPolling, isTrue);
      expect(state.pendingEmail, 'test@example.com');
      expect(state.errorCode, EmailVerificationError.timeout);
    });

    test('isPolling returns true only when status is polling', () {
      expect(const EmailVerificationState().isPolling, isFalse);
      expect(
        const EmailVerificationState(
          status: EmailVerificationStatus.polling,
        ).isPolling,
        isTrue,
      );
      expect(
        const EmailVerificationState(
          status: EmailVerificationStatus.success,
        ).isPolling,
        isFalse,
      );
      expect(
        const EmailVerificationState(
          status: EmailVerificationStatus.failure,
        ).isPolling,
        isFalse,
      );
    });

    test('copyWith creates new state with updated values', () {
      const original = EmailVerificationState(
        status: EmailVerificationStatus.polling,
        pendingEmail: 'original@example.com',
      );

      final updated = original.copyWith(
        status: EmailVerificationStatus.success,
      );

      expect(updated.status, EmailVerificationStatus.success);
      expect(updated.pendingEmail, 'original@example.com');
      expect(updated.errorCode, isNull);
    });

    test('copyWith clears errorCode when not provided', () {
      const original = EmailVerificationState(
        status: EmailVerificationStatus.failure,
        errorCode: EmailVerificationError.timeout,
      );

      final updated = original.copyWith(
        status: EmailVerificationStatus.polling,
      );

      expect(updated.status, EmailVerificationStatus.polling);
      expect(updated.errorCode, isNull);
    });

    group('equality', () {
      test('states with same values are equal', () {
        expect(
          const EmailVerificationState(),
          equals(const EmailVerificationState()),
        );

        expect(
          const EmailVerificationState(
            status: EmailVerificationStatus.polling,
            pendingEmail: 'test@example.com',
          ),
          equals(
            const EmailVerificationState(
              status: EmailVerificationStatus.polling,
              pendingEmail: 'test@example.com',
            ),
          ),
        );
      });

      test('states with different values are not equal', () {
        expect(
          const EmailVerificationState(status: EmailVerificationStatus.polling),
          isNot(equals(const EmailVerificationState())),
        );

        expect(
          const EmailVerificationState(pendingEmail: 'a@example.com'),
          isNot(
            equals(const EmailVerificationState(pendingEmail: 'b@example.com')),
          ),
        );
      });
    });
  });

  group('EmailVerificationStatus', () {
    test('has all expected values', () {
      expect(EmailVerificationStatus.values, hasLength(4));
      expect(
        EmailVerificationStatus.values,
        containsAll([
          EmailVerificationStatus.initial,
          EmailVerificationStatus.polling,
          EmailVerificationStatus.success,
          EmailVerificationStatus.failure,
        ]),
      );
    });
  });
}
