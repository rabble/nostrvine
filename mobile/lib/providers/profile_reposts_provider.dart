// ABOUTME: Provider for fetching videos that a user has reposted
// ABOUTME: Gets reposts directly from videoEventService for a specific user

import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_reposts_provider.g.dart';

/// Provider that returns only the videos a user has reposted
///
/// Gets videos directly from videoEventService and filters for:
/// - isRepost == true
/// - reposterPubkey == userIdHex
///
/// This is independent from profileFeedProvider which only returns originals.
@riverpod
Future<List<VideoEvent>> profileReposts(Ref ref, String userIdHex) async {
  final videoEventService = ref.watch(videoEventServiceProvider);

  // Get all videos by this author and filter for reposts only
  final reposts = videoEventService
      .authorVideos(userIdHex)
      .where((video) => video.isRepost && video.reposterPubkey == userIdHex)
      .toList();

  return reposts;
}
