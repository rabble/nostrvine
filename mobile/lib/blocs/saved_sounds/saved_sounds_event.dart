// ABOUTME: Events accepted by the device-local saved sounds BLoC.
// ABOUTME: Keeps mutations ordered and exposes save completion to callers.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/services/saved_sounds_service.dart';

sealed class SavedSoundsEvent extends Equatable {
  const SavedSoundsEvent();
}

final class SavedSoundsLoadRequested extends SavedSoundsEvent {
  const SavedSoundsLoadRequested();

  @override
  List<Object?> get props => const [];
}

final class SavedSoundSaveRequested extends SavedSoundsEvent {
  const SavedSoundSaveRequested({
    required this.sound,
    required this.completer,
    this.sourceContext,
  });

  final AudioEvent sound;
  final SavedSoundSourceContext? sourceContext;
  final Completer<SavedSoundSaveResult> completer;

  @override
  List<Object?> get props => [sound, sourceContext, completer];
}

final class SavedSoundDetailsChanged extends SavedSoundsEvent {
  const SavedSoundDetailsChanged({
    required this.soundId,
    required this.label,
    required this.hashtags,
  });

  final String soundId;
  final String? label;
  final List<String> hashtags;

  @override
  List<Object?> get props => [soundId, label, hashtags];
}

final class SavedSoundRemoveRequested extends SavedSoundsEvent {
  const SavedSoundRemoveRequested(this.soundId, {this.completer});

  final String soundId;

  /// Completed once the removal has been persisted, or completed with an error
  /// when it could not be, so the caller can tell the user which happened.
  final Completer<void>? completer;

  @override
  List<Object?> get props => [soundId, completer];
}

final class SavedSoundsQueryChanged extends SavedSoundsEvent {
  const SavedSoundsQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class SavedSoundsHashtagSelected extends SavedSoundsEvent {
  const SavedSoundsHashtagSelected(this.hashtag);

  final String? hashtag;

  @override
  List<Object?> get props => [hashtag];
}

final class SavedSoundProbeCompleted extends SavedSoundsEvent {
  const SavedSoundProbeCompleted({
    required this.soundId,
    required this.result,
  });

  final String soundId;
  final SavedSoundMediaResult? result;

  @override
  List<Object?> get props => [soundId, result];
}
