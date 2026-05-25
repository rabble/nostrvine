// ABOUTME: Provider for fetching the parent video of a NIP-71 video reply.
// ABOUTME: Keeps reply-parent lookup shared between feed and metadata UI.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/video_providers.dart';

final FutureProviderFamily<VideoEvent?, String> videoReplyParentProvider =
    FutureProvider.autoDispose.family<VideoEvent?, String>((ref, routeId) {
      final repository = ref.watch(videosRepositoryProvider);
      return repository.fetchVideoWithStatsForRouteId(routeId);
    });
