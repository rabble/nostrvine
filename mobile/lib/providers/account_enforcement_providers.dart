// ABOUTME: Riverpod providers exposing the authenticated account's enforcement
// ABOUTME: state, so the client can tell a restricted user what happened.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/account_enforcement_status.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/repositories/account_enforcement_repository.dart';
import 'package:openvine/services/auth_service.dart';

/// Repository reading `account_status` from Keycast for the current session.
final accountEnforcementRepositoryProvider =
    Provider<AccountEnforcementRepository>((ref) {
      final oauthClient = ref.watch(oauthClientProvider);
      return AccountEnforcementRepository(
        oauthClient: oauthClient,
        // Owner-bound rather than a bare session read: a session left behind by
        // another account must not answer the enforcement question for this one.
        readAccessToken: ref
            .watch(authServiceProvider)
            .activeAccountKeycastToken,
      );
    });

/// Enforcement state for the authenticated account.
///
/// An unauthenticated app has no account to report on, so it resolves to
/// [AccountEnforcementKind.unknown] rather than [AccountEnforcementKind.none]:
/// "no signal" is the truth, and `none` is a positive claim of good standing
/// this provider is not entitled to make.
///
/// autoDispose so the status is re-read whenever nothing is listening any
/// more, rather than cached for the life of the app. An account suspended
/// after launch must not keep reading as being in good standing until the
/// user restarts — that is the failure this surface exists to fix. Call
/// `ref.invalidate(accountEnforcementStatusProvider)` to force a refresh
/// while it is still being watched.
final FutureProvider<AccountEnforcementStatus>
accountEnforcementStatusProvider =
    FutureProvider.autoDispose<AccountEnforcementStatus>((ref) async {
      final authState = ref.watch(currentAuthStateProvider);
      if (authState != AuthState.authenticated) {
        return AccountEnforcementStatus.unknown();
      }
      return ref
          .watch(accountEnforcementRepositoryProvider)
          .fetchCurrentStatus();
    });

/// Convenience seam: true only on a *confirmed* enforced account.
///
/// autoDispose so watching this seam cannot pin the status provider alive and
/// defeat its refetch.
///
/// Unknown resolves to false. Consumers that must fail safe should read
/// [accountEnforcementStatusProvider] and branch on the kind themselves rather
/// than relying on this.
final Provider<bool> isAccountEnforcedProvider = Provider.autoDispose<bool>((
  ref,
) {
  return ref
      .watch(accountEnforcementStatusProvider)
      .maybeWhen(data: (s) => s.isEnforced, orElse: () => false);
});
