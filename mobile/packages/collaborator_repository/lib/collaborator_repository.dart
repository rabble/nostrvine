/// Repository for collaborator confirmation status on Divine videos.
///
/// Drives per-video pending vs confirmed rendering for authors, the current
/// user's local invite-response fast-path, and confirmed-only third-party
/// collaborator visibility.
library;

export 'src/collaborator_confirmation_repository.dart';
export 'src/collaborator_visibility.dart';
export 'src/local_state_reader.dart';
