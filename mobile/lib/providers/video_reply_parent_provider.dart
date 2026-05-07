// ABOUTME: Provider for fetching the parent video of a NIP-71 video reply.
// ABOUTME: Keeps reply-parent lookup shared between feed and metadata UI.

import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:riverpod/src/providers/future_provider.dart';

final FutureProviderFamily<VideoEvent?, String> videoReplyParentProvider =
    FutureProvider.autoDispose.family<VideoEvent?, String>((ref, routeId) {
      final repository = ref.read(videosRepositoryProvider);
      return repository.fetchVideoWithStatsForRouteId(routeId);
    });
