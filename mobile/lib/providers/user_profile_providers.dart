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

const _blockedProfileFetchChunkSize = 50;

final _vanishedProfilePubkeysProvider = StreamProvider<Set<String>>((ref) {
  return ref
      .watch(databaseProvider)
      .vanishedProfilesDao
      .watchAllPubkeys()
      .map((pubkeys) => pubkeys.toSet());
});

/// One-shot durable vanish lookup for imperative paths such as gesture
/// handlers, where no mounted widget keeps [profileVanishedProvider] warm.
// ignore: specify_nonobvious_property_types
final profileVanishedSnapshotProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, pubkey) {
      return ref.watch(databaseProvider).vanishedProfilesDao.isVanished(pubkey);
    });

// ignore: specify_nonobvious_property_types
final userProfileStatsReactiveProvider =
    StreamProvider.family<ProfileStats?, String>((ref, pubkey) {
      // Counts come from a public funnelcake REST call + Drift; they need only
      // an identity-known session, not the full nostrReady relay-connect settle.
      // Using the identity-known-gated read repo lets counts render as soon as
      // REST returns instead of stalling on "—" until relays connect (#5863).
      final repo = ref.watch(profileReadRepositoryProvider);
      if (repo == null) {
        // Match userProfileReactiveProvider: emit null instead of an empty
        // stream so callers get AsyncData(null), not permanent AsyncLoading.
        return _nullProfileStatsStream();
      }

      return _watchProfileStats(repo, pubkey);
    });

Stream<ProfileStats?> _nullProfileStatsStream() async* {
  yield null;
}

Stream<ProfileStats?> _watchProfileStats(
  ProfileReader repo,
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
///
/// Reads through [profileReadRepositoryProvider], which is available at the
/// identity-known phase. Waiting for the relay-connect settle here is what
/// made the signed-in user's own header render a generated fallback name for
/// the whole cold-start window (#6423); nothing on this path signs.
@riverpod
Stream<UserProfile?> userProfileReactive(Ref ref, String pubkey) {
  final repo = ref.watch(profileReadRepositoryProvider);
  if (repo == null) {
    // Resolve to AsyncData(null) rather than an empty stream: a stream that
    // closes without emitting leaves the StreamProvider in AsyncLoading
    // forever, which callers cannot tell apart from "still fetching".
    return Stream<UserProfile?>.value(null);
  }

  return _watchUserProfile(repo, pubkey);
}

Stream<UserProfile?> _watchUserProfile(
  ProfileReader repo,
  String pubkey,
) async* {
  // Kick off a background fetch if nothing is cached yet.
  final cached = await repo.getCachedProfile(pubkey: pubkey);
  if (cached == null) {
    unawaited(repo.fetchFreshProfile(pubkey: pubkey));
  }

  yield* repo.watchProfile(pubkey: pubkey);
}

/// Resolves profiles for the accounts the viewer has blocked.
///
/// Fetching the set in bounded batches avoids starting a REST request plus two
/// relay queries for every uncached row when a synced mute list is large.
@riverpod
Future<Map<String, UserProfile>> blockedUserProfiles(
  Ref ref,
  Set<String> pubkeys,
) async {
  final repo = ref.watch(profileReadRepositoryProvider);
  if (repo == null || pubkeys.isEmpty) return const {};

  final profiles = <String, UserProfile>{};
  final pending = pubkeys.toList();
  for (var i = 0; i < pending.length; i += _blockedProfileFetchChunkSize) {
    final chunk = pending.skip(i).take(_blockedProfileFetchChunkSize).toList();
    profiles.addAll(
      await repo.fetchBatchProfiles(
        pubkeys: chunk,
        ignoreBlockFilter: true,
      ),
    );
  }
  return profiles;
}

/// Watches a blocked account's cached profile without starting another fetch.
///
/// [blockedUserProfiles] hydrates the cache in bounded batches; this provider
/// keeps each tile reactive to that hydration and later profile updates.
@riverpod
Stream<UserProfile?> blockedUserProfile(Ref ref, String pubkey) {
  final repo = ref.watch(profileReadRepositoryProvider);
  if (repo == null) return Stream.value(null);

  return repo.watchProfile(pubkey: pubkey);
}

/// One-shot provider: returns cached profile or fetches fresh.
///
/// Use this when you need a single read (e.g., building a share sheet)
/// rather than a reactive stream.
///
/// Same read gate as [userProfileReactive] — both paths are signer-free.
@riverpod
Future<UserProfile?> fetchUserProfile(Ref ref, String pubkey) async {
  final repo = ref.watch(profileReadRepositoryProvider);
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
  final pubkeys =
      ref.watch(_vanishedProfilePubkeysProvider).value ?? const <String>{};
  return Stream.value(pubkeys.contains(pubkey));
}
