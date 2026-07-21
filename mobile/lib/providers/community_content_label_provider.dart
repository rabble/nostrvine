// ABOUTME: Riverpod provider for CommunityContentLabelRepository (#4771).
// ABOUTME: Nullable-gated on profileRepositoryProvider readiness (Pattern A).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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
