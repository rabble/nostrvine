// ABOUTME: Riverpod wiring for the account email/password repository, bound to
// ABOUTME: the Keycast session of the signed-in account.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/repositories/account_credentials_repository.dart';

/// Repository for reading and changing the Keycast-held email and password.
///
/// What binds a call to an account is the token, not this instance:
/// `activeAccountKeycastToken` resolves one per call and refuses a session
/// owned by anyone else, so even a repository that outlived an account switch
/// cannot spend the previous account's session. The screens still key their
/// blocs on this instance, which is the `state_management.md` guard for the
/// day one of the watched dependencies starts rebuilding on auth changes —
/// today neither does.
final accountCredentialsRepositoryProvider =
    Provider<AccountCredentialsRepository>((ref) {
      final oauthClient = ref.watch(oauthClientProvider);
      return AccountCredentialsRepository(
        oauthClient: oauthClient,
        // Owner-bound rather than a bare getSessionOrRefresh(): a session left
        // behind by another account must never change this account's password.
        readAccessToken: ref
            .watch(authServiceProvider)
            .activeAccountKeycastToken,
      );
    });
