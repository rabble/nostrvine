# Invite Consume Retry Implementation Plan

Status: Current
Validated against: `invite_error_utils.dart`, `EmailVerificationCubit`, `DivineAuthCubit` on 2026-05-06.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retry transient invite consume failures with fresh NIP-98 timestamps, preserving the Keycast session before consume so it survives exhausted retries.

**Architecture:** Add `isRetryable()` and `retryConsume()` static helpers to `InviteErrorUtils`. Replace the existing 409-only retry loop in `EmailVerificationCubit` and the bare consume calls in `DivineAuthCubit` with `retryConsume()`. Persist `KeycastSession` immediately after token exchange, before consume, in both session-based paths.

**Tech Stack:** Dart, Flutter BLoC, `invite_api_client` package, `keycast_flutter` package

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `mobile/lib/utils/invite_error_utils.dart` | Modify | Add `isRetryable()` and `retryConsume()` static methods |
| `mobile/test/utils/invite_error_utils_test.dart` | Modify | Add tests for `isRetryable()` and `retryConsume()` |
| `mobile/lib/blocs/email_verification/email_verification_cubit.dart` | Modify | Replace 409 loop with `retryConsume()`, add `session.save()` |
| `mobile/lib/blocs/divine_auth/divine_auth_cubit.dart` | Modify | Wrap consume calls with `retryConsume()`, add `session.save()` |
| `mobile/test/blocs/email_verification/email_verification_cubit_test.dart` | Modify | Update retry tests for broader retry behavior |
| `mobile/test/blocs/divine_auth/divine_auth_cubit_test.dart` | Modify | Add retry and session persistence tests |

---

### Task 1: Add `isRetryable()` and `retryConsume()` to InviteErrorUtils

**Files:**
- Modify: `mobile/lib/utils/invite_error_utils.dart`
- Modify: `mobile/test/utils/invite_error_utils_test.dart`

- [ ] **Step 1: Write tests for `isRetryable()`**

Append to the end of `main()` in `mobile/test/utils/invite_error_utils_test.dart`, before the closing `}`:

```dart
  group('isRetryable', () {
    test('temporary is retryable', () {
      expect(
        InviteErrorUtils.isRetryable(
          makeException(code: InviteApiErrorCode.clientTimeout),
        ),
        isTrue,
      );
    });

    test('authFailure is retryable', () {
      expect(
        InviteErrorUtils.isRetryable(
          makeException(code: InviteApiErrorCode.authInvalid, statusCode: 401),
        ),
        isTrue,
      );
    });

    test('alreadyUsed is not retryable', () {
      expect(
        InviteErrorUtils.isRetryable(
          makeException(code: InviteApiErrorCode.inviteAlreadyUsed),
        ),
        isFalse,
      );
    });

    test('invalid is not retryable', () {
      expect(
        InviteErrorUtils.isRetryable(
          makeException(code: InviteApiErrorCode.inviteNotFound),
        ),
        isFalse,
      );
    });

    test('creatorFull is not retryable', () {
      expect(
        InviteErrorUtils.isRetryable(
          makeException(code: InviteApiErrorCode.creatorPageFull),
        ),
        isFalse,
      );
    });

    test('unknown is not retryable', () {
      expect(
        InviteErrorUtils.isRetryable(
          makeException(message: 'something unexpected'),
        ),
        isFalse,
      );
    });
  });
```

- [ ] **Step 2: Write tests for `retryConsume()`**

Add `import 'dart:async';` at the top of the test file. Then append another group inside `main()`:

```dart
  group('retryConsume', () {
    test('returns result on first success', () async {
      final result = await InviteErrorUtils.retryConsume(
        consume: () async =>
            const InviteConsumeResult(message: 'ok', codesAllocated: 5),
        log: (_) {},
      );
      expect(result.message, 'ok');
    });

    test('retries on retryable error and succeeds', () async {
      var calls = 0;
      final result = await InviteErrorUtils.retryConsume(
        consume: () async {
          calls++;
          if (calls == 1) {
            throw const InviteApiException(
              'timeout',
              code: InviteApiErrorCode.clientTimeout,
            );
          }
          return const InviteConsumeResult(message: 'ok', codesAllocated: 5);
        },
        log: (_) {},
        delay: Duration.zero,
      );
      expect(result.message, 'ok');
      expect(calls, 2);
    });

    test('rethrows terminal error immediately', () async {
      var calls = 0;
      await expectLater(
        () => InviteErrorUtils.retryConsume(
          consume: () async {
            calls++;
            throw const InviteApiException(
              'already used',
              code: InviteApiErrorCode.inviteAlreadyUsed,
            );
          },
          log: (_) {},
          delay: Duration.zero,
        ),
        throwsA(isA<InviteApiException>()),
      );
      expect(calls, 1);
    });

    test('rethrows after exhausting max attempts', () async {
      var calls = 0;
      await expectLater(
        () => InviteErrorUtils.retryConsume(
          consume: () async {
            calls++;
            throw const InviteApiException(
              'timeout',
              code: InviteApiErrorCode.clientTimeout,
            );
          },
          log: (_) {},
          maxAttempts: 3,
          delay: Duration.zero,
        ),
        throwsA(isA<InviteApiException>()),
      );
      expect(calls, 3);
    });

    test('logs warning on each retry', () async {
      final logs = <String>[];
      var calls = 0;
      await InviteErrorUtils.retryConsume(
        consume: () async {
          calls++;
          if (calls <= 2) {
            throw const InviteApiException(
              'timeout',
              code: InviteApiErrorCode.clientTimeout,
            );
          }
          return const InviteConsumeResult(message: 'ok', codesAllocated: 5);
        },
        log: logs.add,
        maxAttempts: 3,
        delay: Duration.zero,
      );
      expect(logs.length, 2);
      expect(logs[0], contains('attempt 1/3'));
      expect(logs[1], contains('attempt 2/3'));
    });

    test('respects maxAttempts parameter', () async {
      var calls = 0;
      await expectLater(
        () => InviteErrorUtils.retryConsume(
          consume: () async {
            calls++;
            throw const InviteApiException(
              'network',
              code: InviteApiErrorCode.clientNetworkError,
            );
          },
          log: (_) {},
          maxAttempts: 2,
          delay: Duration.zero,
        ),
        throwsA(isA<InviteApiException>()),
      );
      expect(calls, 2);
    });
  });
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd mobile && flutter test test/utils/invite_error_utils_test.dart
```
Expected: Compile error — `isRetryable` and `retryConsume` don't exist yet.

- [ ] **Step 4: Implement `isRetryable()` and `retryConsume()`**

In `mobile/lib/utils/invite_error_utils.dart`, add this import at the top:

```dart
import 'package:invite_api_client/invite_api_client.dart'
    show InviteApiException, InviteConsumeResult;
```

Wait — the file already imports `invite_api_client.dart`. We need to add `InviteConsumeResult` to the existing import. Replace the first import with:

```dart
import 'package:invite_api_client/invite_api_client.dart';
```

(This is already the case — the barrel export includes `InviteConsumeResult`.)

Add these two methods inside the `InviteErrorUtils` class, after `activationFailureMessage`:

```dart
  /// Whether the error is worth retrying (fresh NIP-98 timestamp may fix it).
  static bool isRetryable(InviteApiException error) {
    final reason = activationFailureReason(error);
    return reason == InviteActivationFailureReason.temporary ||
        reason == InviteActivationFailureReason.authFailure;
  }

  /// Retries [consume] up to [maxAttempts] times on retryable errors.
  ///
  /// Each retry generates a fresh NIP-98 timestamp (because the caller
  /// passes a closure that calls `consumeInviteWith*`, which internally
  /// calls `_createAuthorizationHeader` with `DateTime.now()`).
  ///
  /// Terminal errors are rethrown immediately. On the final attempt,
  /// any error is rethrown regardless of retryability.
  static Future<InviteConsumeResult> retryConsume({
    required Future<InviteConsumeResult> Function() consume,
    required void Function(String message) log,
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 2),
  }) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await consume();
      } on InviteApiException catch (e) {
        final isLastAttempt = attempt == maxAttempts;
        if (!isRetryable(e) || isLastAttempt) {
          rethrow;
        }
        log(
          'Invite consume failed (attempt $attempt/$maxAttempts), '
          'retrying in ${delay.inMilliseconds}ms: '
          '${e.message} [code=${e.code}]',
        );
        await Future<void>.delayed(delay);
      }
    }
    throw StateError('Unreachable');
  }
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
cd mobile && flutter test test/utils/invite_error_utils_test.dart
```
Expected: All tests PASS (existing + new isRetryable + retryConsume tests).

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/utils/invite_error_utils.dart mobile/test/utils/invite_error_utils_test.dart
git commit -m "feat(invites): add isRetryable and retryConsume helpers

Classifies temporary and authFailure errors as retryable. retryConsume
wraps a consume closure with configurable retry count and delay.
Part of #3795 consume retry work."
```

---

### Task 2: Replace EmailVerificationCubit 409 loop with `retryConsume()`

**Files:**
- Modify: `mobile/lib/blocs/email_verification/email_verification_cubit.dart`
- Modify: `mobile/test/blocs/email_verification/email_verification_cubit_test.dart`

- [ ] **Step 1: Update existing retry tests for broader retry behavior**

In `mobile/test/blocs/email_verification/email_verification_cubit_test.dart`, replace the three retry tests (the test named `'retries invite consumption on 409 conflict and succeeds on retry'`, the test named `'gives up after exhausting retries on persistent 409'`, and the test named `'does NOT retry on non-conflict InviteApiException (e.g. 400)'`) with these updated versions:

```dart
      test(
        'retries invite consumption on transient error and succeeds on retry',
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
                'timeout',
                code: InviteApiErrorCode.clientTimeout,
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

            // Poll fires after 3s; retry waits another 2s.
            fake.elapse(const Duration(seconds: 8));

            expect(cubit.state.status, EmailVerificationStatus.success);
            expect(
              consumeCallCount,
              equals(2),
              reason:
                  'Cubit should retry once on transient error before '
                  'succeeding.',
            );
            verify(
              () => mockAuthService.signInWithDivineOAuth(any()),
            ).called(1);

            cubit.close();
            fake.flushMicrotasks();
          });
        },
      );

      test('gives up after exhausting retries on persistent transient error',
          () {
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
            'timeout',
            code: InviteApiErrorCode.clientTimeout,
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
            equals(3),
            reason: 'Cubit should retry 3 times before giving up.',
          );
          verifyNever(() => mockAuthService.signInWithDivineOAuth(any()));

          cubit.close();
          fake.flushMicrotasks();
        });
      });

      test('does NOT retry on terminal InviteApiException', () {
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
            'Invite already used',
            code: InviteApiErrorCode.inviteAlreadyUsed,
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
            reason: 'Terminal invite errors must not be retried.',
          );

          cubit.close();
          fake.flushMicrotasks();
        });
      });
```

- [ ] **Step 2: Run tests to verify the updated tests fail**

```bash
cd mobile && flutter test test/blocs/email_verification/email_verification_cubit_test.dart
```
Expected: FAIL — the cubit still uses the old 409-only retry loop, so the transient retry test (which throws `clientTimeout`, not 409) will fail.

- [ ] **Step 3: Replace 409 loop with `retryConsume()` and add `session.save()`**

In `mobile/lib/blocs/email_verification/email_verification_cubit.dart`:

First, add the import for `InviteErrorUtils` if not already present. Check — it's already imported via `package:openvine/utils/invite_error_utils.dart`.

Remove the two constants `_maxConsumeRetries` and `_consumeRetryDelay` (lines 319-326).

Replace `_consumeInviteWithSessionIfNeeded` (the entire method from line 468 to 498) with:

```dart
  Future<void> _consumeInviteWithSessionIfNeeded(KeycastSession session) async {
    final inviteCode = _pendingInviteCode;
    final inviteApiClient = _inviteApiClient;
    if (inviteCode == null || inviteApiClient == null) {
      return;
    }

    await session.save();

    await InviteErrorUtils.retryConsume(
      consume: () => inviteApiClient.consumeInviteWithSession(
        code: inviteCode,
        oauthConfig: _oauthClient.config,
        session: session,
      ),
      log: (message) => Log.warning(
        message,
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      ),
    );
  }
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd mobile && flutter test test/blocs/email_verification/email_verification_cubit_test.dart
```
Expected: All tests PASS. The updated retry tests exercise the new `retryConsume()` path.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/blocs/email_verification/email_verification_cubit.dart mobile/test/blocs/email_verification/email_verification_cubit_test.dart
git commit -m "feat(invites): replace 409 retry loop with retryConsume in EmailVerificationCubit

Broader retry covers timeout, network, and auth errors (not just 409).
Session saved before consume so it survives exhausted retries.
Removes _maxConsumeRetries and _consumeRetryDelay constants.
Part of #3795 consume retry work."
```

---

### Task 3: Wrap DivineAuthCubit consume calls with `retryConsume()`

**Files:**
- Modify: `mobile/lib/blocs/divine_auth/divine_auth_cubit.dart`
- Modify: `mobile/test/blocs/divine_auth/divine_auth_cubit_test.dart`

- [ ] **Step 1: Add retry and session persistence tests for `_exchangeCodeAndLogin`**

In `mobile/test/blocs/divine_auth/divine_auth_cubit_test.dart`, find the test group for sign-in invite consumption (look for the `blocTest` named `'emits invite recovery error when invite activation fails during sign in'`). After that test, add:

```dart
        blocTest<DivineAuthCubit, DivineAuthState>(
          'retries invite consumption on transient error during sign in',
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
                  'timeout',
                  code: InviteApiErrorCode.clientTimeout,
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
          },
          build: () => buildCubit(inviteCode: 'ab12ef34'),
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
              () => mockInviteApiClient.consumeInviteWithSession(
                code: any(named: 'code'),
                oauthConfig: any(named: 'oauthConfig'),
                session: any(named: 'session'),
              ),
            ).called(2);
          },
        );
```

- [ ] **Step 2: Add retry test for `skipWithAnonymousAccount`**

After the existing `'emits invite recovery error when anonymous invite activation fails'` test, add:

```dart
      blocTest<DivineAuthCubit, DivineAuthState>(
        'retries anonymous invite consumption on transient error',
        setUp: () {
          var consumeCallCount = 0;
          when(
            () => mockInviteApiClient.consumeInviteWithKeyContainer(
              code: any(named: 'code'),
              keyContainer: any(named: 'keyContainer'),
            ),
          ).thenAnswer((_) async {
            consumeCallCount++;
            if (consumeCallCount == 1) {
              throw const InviteApiException(
                'network error',
                code: InviteApiErrorCode.clientNetworkError,
              );
            }
            return const InviteConsumeResult(
              message: 'Welcome',
              codesAllocated: 5,
            );
          });
          when(
            () => mockAuthService.createAnonymousAccountFromKeyContainer(any()),
          ).thenAnswer((_) async {});
        },
        build: () => buildCubit(inviteCode: 'ab12ef34'),
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
          verify(
            () => mockInviteApiClient.consumeInviteWithKeyContainer(
              code: any(named: 'code'),
              keyContainer: any(named: 'keyContainer'),
            ),
          ).called(2);
        },
      );
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
cd mobile && flutter test test/blocs/divine_auth/divine_auth_cubit_test.dart
```
Expected: FAIL — consume is only called once (no retry yet).

- [ ] **Step 4: Add `retryConsume()` to `_consumeInviteWithSessionIfNeeded` with `session.save()`**

In `mobile/lib/blocs/divine_auth/divine_auth_cubit.dart`, replace `_consumeInviteWithSessionIfNeeded` (lines 494-506) with:

```dart
  Future<void> _consumeInviteWithSessionIfNeeded(KeycastSession session) async {
    final inviteCode = _inviteCode;
    final inviteApiClient = _inviteApiClient;
    if (inviteCode == null || inviteApiClient == null) {
      return;
    }

    await session.save();

    await InviteErrorUtils.retryConsume(
      consume: () => inviteApiClient.consumeInviteWithSession(
        code: inviteCode,
        oauthConfig: _oauthClient.config,
        session: session,
      ),
      log: (message) => Log.warning(
        message,
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      ),
    );
  }
```

- [ ] **Step 5: Add `retryConsume()` to `skipWithAnonymousAccount`**

In `mobile/lib/blocs/divine_auth/divine_auth_cubit.dart`, in `skipWithAnonymousAccount`, replace the bare `consumeInviteWithKeyContainer` call (lines 435-438):

```dart
          await inviteApiClient.consumeInviteWithKeyContainer(
            code: inviteCode,
            keyContainer: pendingKey,
          );
```

with:

```dart
          await InviteErrorUtils.retryConsume(
            consume: () => inviteApiClient.consumeInviteWithKeyContainer(
              code: inviteCode,
              keyContainer: pendingKey,
            ),
            log: (message) => Log.warning(
              message,
              name: 'DivineAuthCubit',
              category: LogCategory.auth,
            ),
          );
```

- [ ] **Step 6: Run tests to verify they pass**

```bash
cd mobile && flutter test test/blocs/divine_auth/divine_auth_cubit_test.dart
```
Expected: All tests PASS, including new retry tests.

- [ ] **Step 7: Commit**

```bash
git add mobile/lib/blocs/divine_auth/divine_auth_cubit.dart mobile/test/blocs/divine_auth/divine_auth_cubit_test.dart
git commit -m "feat(invites): add consume retry and session persistence to DivineAuthCubit

Both session-based and anonymous consume paths now retry transient
errors via retryConsume(). Session saved before consume in
_exchangeCodeAndLogin path. Part of #3795 consume retry work."
```

---

### Task 4: Final verification and cleanup

- [ ] **Step 1: Run all three test suites**

```bash
cd mobile && flutter test test/utils/invite_error_utils_test.dart test/blocs/email_verification/email_verification_cubit_test.dart test/blocs/divine_auth/divine_auth_cubit_test.dart
```
Expected: All tests PASS.

- [ ] **Step 2: Run invite_api_client package tests**

```bash
cd mobile && flutter test packages/invite_api_client/test/
```
Expected: All tests PASS (no changes to the package in this PR).

- [ ] **Step 3: Run analyzer**

```bash
cd mobile && flutter analyze
```
Expected: No issues introduced by these changes.

- [ ] **Step 4: Verify the old 409 retry constants are removed**

```bash
grep -rn "_maxConsumeRetries\|_consumeRetryDelay" mobile/ --include="*.dart"
```
Expected: No results. Both constants were removed from `EmailVerificationCubit`.

- [ ] **Step 5: Verify `session.save()` is called before consume in both session paths**

```bash
grep -A3 "session.save()" mobile/lib/blocs/ -r --include="*.dart"
```
Expected: Two occurrences — one in `email_verification_cubit.dart` and one in `divine_auth_cubit.dart`, each followed by `retryConsume`.
