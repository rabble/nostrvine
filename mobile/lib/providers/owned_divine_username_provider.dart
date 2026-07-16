// ABOUTME: Provides the signed-in user's active @divine.video username, if any.
// ABOUTME: Gates whether the delete-account flow offers the opt-in burn toggle.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/repository_providers.dart';

/// The active `@divine.video` username owned by the signed-in user, or `null`
/// if they own none or it cannot be resolved.
///
/// Drives whether the delete-account flow offers the opt-in "burn my username"
/// toggle: the toggle is shown only when this resolves to a non-null name.
final FutureProvider<String?> ownedDivineUsernameProvider =
    FutureProvider.autoDispose<String?>((ref) async {
      final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
      if (pubkey == null || pubkey.isEmpty) return null;
      final repository = ref.watch(profileRepositoryProvider);
      if (repository == null) return null;
      return repository.getUsernameByPubkey(pubkeyHex: pubkey);
    });
