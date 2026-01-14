/// Videos Repository - manages video event storage and retrieval.
///
/// Follows the repository pattern with abstract interfaces for testability:
/// - `VideoLocalStorage` - abstract interface for local storage
/// - `DbVideoLocalStorage` - db_client implementation
/// - `VideosRepository` - main repository (orchestrates Nostr + Storage)
library;

export 'src/db_video_local_storage.dart';
export 'src/video_local_storage.dart';
export 'src/videos_repository.dart';
