// ABOUTME: Riverpod providers for the protected-minor DM restriction (#176):
// ABOUTME: the discriminated NIP-05 resolver, the pin ∩ NIP-05 gate service, and
// ABOUTME: the DmSendPolicy that NIP17MessageService consults on every send.

import 'package:dm_repository/dm_repository.dart' show DmSendPolicy;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/nip05_resolver.dart';
import 'package:openvine/services/official_accounts_service.dart';

/// The discriminated NIP-05 resolver (its own Dio with timeouts).
final nip05ResolverProvider = Provider<Nip05Resolver>((ref) => Nip05Resolver());

/// The pin ∩ NIP-05 gate for whether a protected minor may DM a given pubkey.
final officialAccountsServiceProvider = Provider<OfficialAccountsService>((
  ref,
) {
  return OfficialAccountsService(
    resolver: ref.watch(nip05ResolverProvider),
    prefs: ref.watch(sharedPreferencesProvider),
  );
});

/// The outbound-DM policy injected into [NIP17MessageService] (#176).
///
/// A non-protected user is unrestricted. A protected minor may only send to an
/// account currently approved by [OfficialAccountsService] (pin ∩ live NIP-05).
/// Reads state at call time (send-time) so the decision is fresh: a mid-session
/// approval/revocation takes effect on the next send without rebuilding.
final dmSendPolicyProvider = Provider<DmSendPolicy>((ref) {
  return (String recipientPubkey) async {
    if (!ref.read(isProtectedMinorProvider)) return true;
    return ref
        .read(officialAccountsServiceProvider)
        .isApprovedMinorDmRecipient(recipientPubkey);
  };
});
