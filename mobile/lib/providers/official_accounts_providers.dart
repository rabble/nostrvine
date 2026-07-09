// ABOUTME: Riverpod providers for the protected-minor DM restriction (#176):
// ABOUTME: the discriminated NIP-05 resolver, the pin ∩ NIP-05 gate service, and
// ABOUTME: the DmSendPolicy that NIP17MessageService consults on every send.

import 'package:dm_repository/dm_repository.dart' show DmSendPolicy;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/dm/conversation_list/protected_minor_inbox_gate.dart';
import 'package:openvine/blocs/dm/conversation_list/protected_minor_inbox_gate_impl.dart';
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
/// Keys off [isDmRestrictedProvider], the fail-closed seam: only a positive
/// not-protected verdict (trusted live or persisted) is unrestricted; a
/// restricted user may only send to an account currently approved by
/// [OfficialAccountsService] (pin ∩ live NIP-05). Reads state at call time
/// (send-time) so the decision is fresh: a mid-session approval/revocation
/// takes effect on the next send without rebuilding.
final dmSendPolicyProvider = Provider<DmSendPolicy>((ref) {
  return (String recipientPubkey) async {
    if (!ref.read(isDmRestrictedProvider)) return true;
    return ref
        .read(officialAccountsServiceProvider)
        .isApprovedMinorDmRecipient(recipientPubkey);
  };
});

/// Inbound DM filter for ConversationListBloc (#176). Reads the DM-restriction
/// status live (send/receive-time) and shares the single officials service, so
/// its receive-time revalidation + verdict-change stream stay consistent.
///
/// A flip of the restriction itself (mid-session approval/revocation via
/// `refreshMinorAccountState`, dev toggle) is pushed into the gate's `changes`
/// stream by [DmRestrictionGateSync] (always mounted at the app shell), so the
/// inbox list AND the unread badge re-filter immediately instead of waiting
/// for the next DM event. The push lives in a widget rather than a provider
/// `ref.listen` because an inactive provider's listener is paused (Riverpod 3
/// activity semantics) — the badge needs the tick while no DM surface is
/// mounted.
final protectedMinorInboxGateProvider = Provider<ProtectedMinorInboxGate>((
  ref,
) {
  final gate = ProtectedMinorInboxGateImpl(
    isRestricted: () => ref.read(isDmRestrictedProvider),
    officials: ref.read(officialAccountsServiceProvider),
  );
  ref.onDispose(gate.dispose);
  return gate;
});
