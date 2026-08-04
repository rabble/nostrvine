// ABOUTME: Provides one saved sounds BLoC for the current account across all routes.
// ABOUTME: Replaces and closes the BLoC whenever the account storage key changes.

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
    super.key,
  });

  final SavedSoundsService service;
  final SavedSoundMediaProbe? mediaProbe;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SavedSoundsBloc>(
      key: ValueKey(service.storageKey),
      lazy: false,
      create: (_) => SavedSoundsBloc(
        service: service,
        mediaProbe: mediaProbe ?? ProVideoEditorSavedSoundMediaProbe(),
      )..add(const SavedSoundsLoadRequested()),
      child: child,
    );
  }
}
