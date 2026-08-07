// ABOUTME: Provides one saved sounds BLoC for the current account across all routes.
// ABOUTME: Replaces and closes the BLoC whenever the account storage key changes.

import 'package:creator_sync/creator_sync.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/services/saved_sounds_service.dart';

class SavedSoundsScope extends StatelessWidget {
  const SavedSoundsScope({
    required this.service,
    required this.child,
    this.mediaProbe,
    this.syncRepository,
    super.key,
  });

  final SavedSoundsService service;
  final SavedSoundMediaProbe? mediaProbe;

  /// Cross-device sync, or null until the vault key resolves.
  final SoundSyncRepository? syncRepository;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SavedSoundsBloc>(
      // Also keyed on syncRepository: it resolves asynchronously after the
      // account storage key is already known, so without this the bloc
      // would be created before sync is available and never pick it up.
      key: ValueKey((service.storageKey, syncRepository)),
      lazy: false,
      create: (_) => SavedSoundsBloc(
        service: service,
        mediaProbe: mediaProbe ?? ProVideoEditorSavedSoundMediaProbe(),
        syncRepository: syncRepository,
      )..add(const SavedSoundsLoadRequested()),
      child: child,
    );
  }
}
