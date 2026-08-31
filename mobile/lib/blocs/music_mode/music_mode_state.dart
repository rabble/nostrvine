// ABOUTME: State for MusicModeCubit — the Music mode recording preference.

import 'package:equatable/equatable.dart';

/// State for `MusicModeCubit`.
class MusicModeState extends Equatable {
  const MusicModeState({this.isEnabled = false});

  final bool isEnabled;

  MusicModeState copyWith({bool? isEnabled}) {
    return MusicModeState(isEnabled: isEnabled ?? this.isEnabled);
  }

  @override
  List<Object?> get props => [isEnabled];
}
