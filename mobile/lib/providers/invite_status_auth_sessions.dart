// ABOUTME: Bridges the app-wide Nostr readiness contract into invite status.
// ABOUTME: Feeds InviteStatusCubit the signer-ready phase, not raw auth state.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/providers/nostr_client_provider.dart';

/// Maps a [NostrSessionReadiness] snapshot onto the cubit's session type.
///
/// `identityKnown` carries a pubkey but no usable signer, so it maps to a
/// session that is addressed to an account yet not allowed to call the invite
/// API. Only `nostrReady` reports a signer.
InviteStatusAuthSession inviteStatusAuthSessionOf(
  NostrSessionReadiness readiness,
) => InviteStatusAuthSession(
  accountId: readiness.pubkey,
  isSignerReady: readiness.isReadyForActiveClient,
);

/// Session updates for [InviteStatusCubit].
///
/// Reads from [nostrSessionProvider] rather than `authStateStream`: auth state
/// only says the identity is known, and a Keycast signer with no local key
/// becomes usable *after* that (#6977). The cubit asks once and then waits for
/// a push, so watching the wrong signal strands it forever.
final inviteStatusAuthSessionsProvider =
    Provider<Stream<InviteStatusAuthSession>>((ref) {
      final controller = StreamController<InviteStatusAuthSession>.broadcast();
      final subscription = ref.listen<NostrSessionReadiness>(
        nostrSessionProvider,
        (_, next) => controller.add(inviteStatusAuthSessionOf(next)),
      );

      ref.onDispose(() {
        subscription.close();
        unawaited(controller.close());
      });

      return controller.stream;
    });
