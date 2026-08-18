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
/// This only recomputes when auth state changes. An account suspended
/// mid-session will not refetch until the provider is invalidated, so call
/// `ref.invalidate(accountEnforcementStatusProvider)` where fresh state
/// matters — notably after a publish is refused.
final accountEnforcementStatusProvider =
    FutureProvider<AccountEnforcementStatus>((ref) async {
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
/// Unknown resolves to false. Consumers that must fail safe should read
/// [accountEnforcementStatusProvider] and branch on the kind themselves rather
/// than relying on this.
final isAccountEnforcedProvider = Provider<bool>((ref) {
  return ref
      .watch(accountEnforcementStatusProvider)
      .maybeWhen(data: (s) => s.isEnforced, orElse: () => false);
});
