// ABOUTME: Riverpod provider for CommunityContentLabelRepository (#4771).
// ABOUTME: Nullable-gated on profileRepositoryProvider readiness (Pattern A).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/repositories/community_content_label_repository.dart';
import 'package:openvine/services/community_content_label_service.dart';

/// Provides the [CommunityContentLabelRepository], or `null` until the
/// signer-backed profile repository is ready for the active identity.
///
/// Gated on [profileRepositoryProvider] (Pattern A): consumers render a
/// disabled affordance while this is `null`, so the repository never captures
/// a stale, pre-auth NostrClient.
final communityContentLabelRepositoryProvider =
    Provider<CommunityContentLabelRepository?>((ref) {
      final profileRepository = ref.watch(profileRepositoryProvider);
      if (profileRepository == null) return null;
      return CommunityContentLabelRepository(
        nostrClient: ref.watch(nostrServiceProvider),
        profileRepository: profileRepository,
      );
    });

/// Long-lived cache of community content-warning labels per video.
///
/// A [ChangeNotifierProvider] so feed items rebuild when a background
/// [CommunityContentLabelService.prefetch] resolves. The repository is passed
/// through nullable; the service no-ops until it is ready.
final communityContentLabelServiceProvider =
    ChangeNotifierProvider<CommunityContentLabelService>((ref) {
      return CommunityContentLabelService(
        repository: ref.watch(communityContentLabelRepositoryProvider),
        contentFilterService: ref.watch(contentFilterServiceProvider),
      );
    });

/// Whether the "Help classify this" action can be offered right now: the
/// kill-switch is on and both the signer-backed repository and the viewer's
/// pubkey are ready.
///
/// The action column watches this to decide whether to insert the slot at
/// all. Returning a zero-size widget from the button is not enough — the
/// child still consumes a `Column(spacing: 20)` gap, leaving a hole between
/// Report and More (#7475).
final helpClassifyActionAvailableProvider = Provider<bool>((ref) {
  final flagEnabled = ref.watch(
    isFeatureEnabledProvider(FeatureFlag.communityContentWarnings),
  );
  if (!flagEnabled) return false;
  if (ref.watch(communityContentLabelRepositoryProvider) == null) return false;
  // The AuthService instance is stable, so watching it alone would never
  // re-evaluate; the auth state is what moves on sign-in / account switch.
  ref.watch(currentAuthStateProvider);
  final myPubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
  return myPubkey != null && myPubkey.isNotEmpty;
});
