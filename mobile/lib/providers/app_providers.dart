// ABOUTME: Comprehensive Riverpod providers for all application services
// ABOUTME: Replaces Provider MultiProvider setup with pure Riverpod dependency injection

import 'dart:core';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/moderation_providers.dart';
import 'package:openvine/services/blocklist_content_filter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:videos_repository/videos_repository.dart';

export 'auth_providers.dart';
export 'moderation_providers.dart';
export 'nostr_apps_providers.dart';
export 'notifications_providers.dart';
export 'permissions_providers.dart';
export 'preferences_providers.dart';
export 'relay_providers.dart';
// TODO(#4506): Drop this compatibility export after consumers move off
// app_providers.dart.
export 'repository_providers.dart';
export 'social_providers.dart';
export 'upload_media_providers.dart';
export 'video_providers.dart';

BlockedVideoFilter createBlockedAuthorFilter(Ref ref) {
  final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
  final flagService = ref.watch(featureFlagServiceProvider);
  if (flagService.isEnabled(FeatureFlag.contentPolicyV2)) {
    final engine = ref.watch(contentPolicyEngineProvider);
    return createPolicyEngineFilter(
      engine,
      () => blocklistRepository.currentState,
    );
  }

  return createBlocklistFilter(blocklistRepository);
}
