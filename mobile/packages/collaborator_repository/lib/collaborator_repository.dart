/// Repository for collaborator confirmation status on Divine videos.
///
/// Drives per-video pending vs confirmed rendering for own-authored videos
/// and the current user's local invite-response fast-path. Third-party
/// rendering of collaborator p-tags is unchanged by this repository.
library;

export 'src/collaborator_confirmation_repository.dart';
export 'src/collaborator_visibility.dart';
export 'src/local_state_reader.dart';
