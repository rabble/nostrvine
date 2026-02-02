// ABOUTME: Riverpod provider for VideoRepository
// ABOUTME: Provides singleton instance with proper lifecycle management

import 'package:openvine/repositories/video_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'video_repository_provider.g.dart';

/// Provider for VideoRepository instance.
///
/// Creates a VideoRepository as the single source of truth for video storage.
/// Uses keepAlive to ensure the repository persists across the app lifecycle.
///
/// The repository handles:
/// - Write-time deduplication with normalized IDs
/// - Subscription membership tracking
/// - Hashtag and author indexing
@Riverpod(keepAlive: true)
VideoRepository videoRepository(Ref ref) {
  final repo = VideoRepository();
  ref.onDispose(repo.dispose);
  return repo;
}
