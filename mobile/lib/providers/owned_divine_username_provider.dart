// ABOUTME: Provides the signed-in user's Divine username lookup for deletion.
// ABOUTME: Preserves the found / confirmed-not-found / unknown tri-state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:profile_repository/profile_repository.dart';

/// The signed-in user's active `@divine.video` name lookup as a
/// [DivineUsernameLookup] tri-state: [DivineUsernameFound] (owns a name),
/// [DivineUsernameNotFound] (confirmed none), or [DivineUsernameUnknown]
/// (could not be determined).
///
/// The deletion flow must fail closed on [DivineUsernameUnknown] rather than
/// treat an undetermined lookup as "no name", so the tri-state is preserved
/// here instead of being collapsed to a nullable record. A missing pubkey or
/// an unready repository is [DivineUsernameUnknown], not a confirmed absence.
final FutureProvider<DivineUsernameLookup> ownedDivineUsernameProvider =
    FutureProvider.autoDispose<DivineUsernameLookup>((ref) async {
      final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
      if (pubkey == null || pubkey.isEmpty) {
        return const DivineUsernameUnknown();
      }
      final repository = ref.watch(profileRepositoryProvider);
      if (repository == null) return const DivineUsernameUnknown();
      return repository.lookupUsernameByPubkey(pubkeyHex: pubkey);
    });
