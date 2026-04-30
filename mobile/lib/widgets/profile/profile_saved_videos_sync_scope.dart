// ABOUTME: Dispatches ProfileSavedVideosSyncRequested when the profile saved
// ABOUTME: BLoC is available above [context] (own profile grid).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/profile_saved_videos/profile_saved_videos_bloc.dart';
import 'package:provider/provider.dart';

/// Triggers a fresh load of the Saved tab if [ProfileSavedVideosBloc] exists
/// above [context], e.g. after toggling bookmarks from share UI on profile.
///
/// No-ops when the bloc is not in the tree (home feed, other user profile).
void requestProfileSavedVideosSyncIfAvailable(BuildContext context) {
  try {
    context.read<ProfileSavedVideosBloc>().add(
      const ProfileSavedVideosSyncRequested(),
    );
  } on ProviderNotFoundException {
    // No saved tab bloc for this subtree.
  }
}
