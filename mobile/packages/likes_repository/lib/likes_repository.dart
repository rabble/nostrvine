/// Repository for managing user likes (Kind 7 reactions) with Nostr.
///
/// This package provides:
/// - `LikesRepository` - Repository for likes management using NostrClient
/// - `LikesLocalStorage` - Interface for local persistence
/// - `DbLikesLocalStorage` - db_client implementation of local storage
/// - `LikeRecord` - Model for like records
/// - Various typed exceptions for error handling
library;

export 'src/db_likes_local_storage.dart';
export 'src/exceptions.dart';
export 'src/likes_local_storage.dart';
export 'src/likes_repository.dart';
export 'src/models/models.dart';
