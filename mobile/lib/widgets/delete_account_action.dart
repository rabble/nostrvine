// ABOUTME: Shared entry point for the account-deletion flow, used by every screen
// ABOUTME: that offers it so there is exactly one deletion implementation.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/owned_divine_username_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/delete_account_confirmation.dart';
import 'package:openvine/widgets/delete_account_dialog.dart';
import 'package:openvine/widgets/modal_progress_overlay.dart';

const Duration _profileResolveTimeout = Duration(seconds: 3);

/// Open the account-deletion confirmation flow.
///
/// This is the single implementation shared by every surface that offers
/// deletion, so the confirmation gate, the username-burn opt-in, and the
/// irreversible-step ordering cannot drift between entry points. Callers supply
/// only [screenName], used for log attribution.
///
/// Does nothing when no account is signed in.
Future<void> startAccountDeletionFlow({
  required BuildContext context,
  required WidgetRef ref,
  required String screenName,
}) async {
  final deletionService = ref.read(accountDeletionServiceProvider);
  final authService = ref.read(authServiceProvider);
  final profileRepository = ref.read(profileRepositoryProvider);
  final pubkey = authService.currentPublicKeyHex;
  if (pubkey == null || pubkey.isEmpty) return;

  // Kick off the burnable-handle lookup but do not await it: the dialog opens
  // immediately and reveals the opt-in burn toggle once this resolves, so a
  // slow name-server call never blocks the tap.
  final ownedUsernameFuture = ref.read(ownedDivineUsernameProvider.future);

  // Resolve the local profile up front so the identity + username gate are
  // ready when the dialog opens. Cache-first (usually instant) with a bounded
  // network fallback; a timeout or miss degrades to npub + DELETE, never hangs.
  final overlay = ModalProgressOverlay.show(context);
  UserProfile? profile;
  try {
    profile = await ref
        .read(fetchUserProfileProvider(pubkey).future)
        .timeout(_profileResolveTimeout, onTimeout: () => null);
  } catch (_) {
    profile = null;
  } finally {
    overlay.dismiss();
  }
  if (!context.mounted) return;

  // The gate anchors on the shown profile identity (displayNip05) to confirm
  // *which account* is being erased — deliberately distinct from the burn
  // target (the owned @divine.video handle, which the burn toggle names for
  // itself). The two can differ for an external-NIP-05 user who also owns a
  // divine username; that divergence is intended, not a mismatch to reconcile.
  final confirmation = DeleteAccountConfirmation(
    pubkeyHex: pubkey,
    displayName:
        profile?.bestDisplayName ?? UserProfile.defaultDisplayNameFor(pubkey),
    avatarUrl: profile?.picture,
    handle: profile?.displayNip05,
  );

  await showDeleteAllContentWarningDialog(
    context: context,
    confirmation: confirmation,
    ownedUsernameFuture: ownedUsernameFuture,
    onConfirm:
        ({
          required bool burnUsername,
          ({String name, String canonical})? ownedUsername,
        }) => executeAccountDeletion(
          context: context,
          deletionService: deletionService,
          authService: authService,
          profileRepository: profileRepository,
          burnUsername: burnUsername,
          ownedUsername: ownedUsername,
          confirmedPubkey: pubkey,
          screenName: screenName,
        ),
  );
}
