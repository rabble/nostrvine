// ABOUTME: State for MusicModeCubit — the Music mode recording preference.

import 'package:equatable/equatable.dart';

/// Load lifecycle of the Music mode tile.
enum MusicModeStatus { loading, ready }

/// State for `MusicModeCubit`.
class MusicModeState extends Equatable {
  const MusicModeState({
    this.status = MusicModeStatus.loading,
    this.isEnabled = false,
  });

  final MusicModeStatus status;
  final bool isEnabled;

  MusicModeState copyWith({
    MusicModeStatus? status,
    bool? isEnabled,
  }) {
    return MusicModeState(
      status: status ?? this.status,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  @override
  List<Object?> get props => [status, isEnabled];
}
