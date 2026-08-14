// ABOUTME: Riverpod wiring for the account email/password repository, bound to
// ABOUTME: the Keycast session of the signed-in account.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/repositories/account_credentials_repository.dart';

/// Repository for reading and changing the Keycast-held email and password.
///
/// Rebuilds whenever [authServiceProvider] does, which is what the screens key
/// their blocs on — a bloc holding the previous account's repository must not
/// survive an account switch.
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
