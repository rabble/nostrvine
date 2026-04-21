part of 'video_volume_cubit.dart';

/// State for [VideoVolumeCubit].
///
/// Volume is binary: `1.0` (unmuted) or `0.0` (muted). The actual loudness
/// is controlled by the device's hardware volume — media_kit only sees
/// `0` or `100`.
class VideoVolumeState extends Equatable {
  const VideoVolumeState({this.volume = 1.0});

  /// Desired playback volume (0.0 = muted, 1.0 = full).
  final double volume;

  /// Whether playback is currently muted.
  bool get isMuted => volume == 0;

  @override
  List<Object?> get props => [volume];
}
