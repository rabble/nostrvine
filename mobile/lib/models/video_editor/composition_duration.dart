import 'package:openvine/models/divine_video_clip.dart';

/// Total wall-clock duration [clips] occupy on the editor timeline.
Duration compositionDuration(List<DivineVideoClip> clips) =>
    clips.fold(Duration.zero, (sum, clip) => sum + clip.playbackDuration);
