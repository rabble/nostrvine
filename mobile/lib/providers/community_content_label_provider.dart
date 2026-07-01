// ABOUTME: Riverpod provider for CommunityContentLabelRepository (#4771).
// ABOUTME: Nullable-gated on profileRepositoryProvider readiness (Pattern A).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/repositories/community_content_label_repository.dart';

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
