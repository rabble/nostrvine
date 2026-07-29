// ABOUTME: Riverpod providers for user profile fetching via ProfileRepository.
// ABOUTME: Reactive stream provider + simple cache-or-fetch provider.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_profile_providers.g.dart';

// ignore: specify_nonobvious_property_types
final userProfileStatsReactiveProvider =
    StreamProvider.family<ProfileStats?, String>((ref, pubkey) {
      // Counts come from a public funnelcake REST call + Drift; they need only
      // an identity-known session, not the full nostrReady relay-connect settle.
      // Using the identity-known-gated stats repo lets counts render as soon as
      // REST returns instead of stalling on "—" until relays connect (#5863).
      final repo = ref.watch(profileStatsRepositoryProvider);
      if (repo == null) {
        return const Stream<ProfileStats?>.empty();
      }

      return _watchProfileStats(repo, pubkey);
    });

Stream<ProfileStats?> _watchProfileStats(
  ProfileRepository repo,
  String pubkey,
) async* {
  unawaited(
    repo
        .fetchFreshProfile(pubkey: pubkey)
        .catchError((Object _, StackTrace _) => null),
  );

  yield* repo.watchProfileStats(pubkey: pubkey);
}

/// Reactive profile provider backed by Drift's watchProfile stream.
///
/// On first access for a pubkey:
/// 1. Checks Drift cache — if missing, fires a background fetchFreshProfile
/// 2. Yields from the Drift watch stream, so any cache update (from fetch,
///    profile edit, or batch prefetch) automatically flows to consumers.
///
/// Consumers get `AsyncValue<UserProfile?>` — same API as the old
/// FutureProvider, so widget code changes are minimal.
@riverpod
Stream<UserProfile?> userProfileReactive(Ref ref, String pubkey) {
  final repo = ref.watch(profileRepositoryProvider);
  if (repo == null) {
    return const Stream<UserProfile?>.empty();
  }

  return _watchUserProfile(repo, pubkey);
}

Stream<UserProfile?> _watchUserProfile(
  ProfileRepository repo,
  String pubkey,
) async* {
  // Kick off a background fetch if nothing is cached yet.
  final cached = await repo.getCachedProfile(pubkey: pubkey);
  if (cached == null) {
    unawaited(repo.fetchFreshProfile(pubkey: pubkey));
  }

  yield* repo.watchProfile(pubkey: pubkey);
}

/// One-shot provider: returns cached profile or fetches fresh.
///
/// Use this when you need a single read (e.g., building a share sheet)
/// rather than a reactive stream.
@riverpod
Future<UserProfile?> fetchUserProfile(Ref ref, String pubkey) async {
  final repo = ref.watch(profileRepositoryProvider);
  if (repo == null) return null;

  final cached = await repo.getCachedProfile(pubkey: pubkey);
  if (cached != null) {
    return cached;
  }

  return repo.fetchFreshProfile(pubkey: pubkey);
}

/// Whether the account behind [pubkey] has requested NIP-62 deletion.
///
/// Backed by the durable `vanished_profiles` table, so a cold start resolves
/// without a network round trip, and it flips live when a fetch discovers a
/// new deletion. This — not the profile provider — drives the deleted-account
/// treatment in the inbox and the following bar.
@riverpod
Stream<bool> profileVanished(Ref ref, String pubkey) {
  return ref
      .watch(databaseProvider)
      .vanishedProfilesDao
      .watchIsVanished(pubkey);
}
