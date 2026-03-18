// ABOUTME: Riverpod providers for user profile fetching via ProfileRepository.
// ABOUTME: Reactive stream provider + simple cache-or-fetch provider.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'user_profile_providers.g.dart';

// ignore: specify_nonobvious_property_types
final userProfileStatsReactiveProvider =
    StreamProvider.family<ProfileStats?, String>((ref, pubkey) {
      final repo = ref.watch(profileRepositoryProvider);
      if (repo == null) {
        return const Stream<ProfileStats?>.empty();
      }

      return repo.watchProfileStats(pubkey: pubkey);
    });

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
Stream<UserProfile?> userProfileReactive(Ref ref, String pubkey) async* {
  final repo = ref.watch(profileRepositoryProvider);
  if (repo == null) return;

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

  return await repo.getCachedProfile(pubkey: pubkey) ??
      await repo.fetchFreshProfile(pubkey: pubkey);
}
