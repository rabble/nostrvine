// ABOUTME: Cubit for profile-saved hashtag labels (Saved tab → Tags).
// ABOUTME: Subscribes to FollowedHashtagsRepository.profileSavedHashtagsStream.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:followed_hashtags_repository/followed_hashtags_repository.dart';

/// Exposes the device-local list of hashtags saved on the user profile
/// (Saved tab, Tags filter).
///
/// Subscribes to [FollowedHashtagsRepository.profileSavedHashtagsStream] and
/// mirrors updates (add/remove from hashtag menu, etc.).
class ProfileSavedHashtagsCubit extends Cubit<List<String>> {
  ProfileSavedHashtagsCubit({required FollowedHashtagsRepository repository})
    : _repository = repository,
      super(List<String>.from(repository.profileSavedHashtags)) {
    _subscription = _repository.profileSavedHashtagsStream.listen(
      (tags) => emit(List<String>.from(tags)),
      onError: addError,
    );
  }

  final FollowedHashtagsRepository _repository;
  StreamSubscription<List<String>>? _subscription;

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
