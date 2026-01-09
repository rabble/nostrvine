import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:video_player/video_player.dart';

/// Service for managing sound selection and playback in the video editor
class VideoEditorSoundService {
  VideoEditorSoundService({
    required this.videoController,
    required this.onStateChanged,
  });

  final VideoPlayerController videoController;
  final VoidCallback onStateChanged;

  /// Audio player for sound preview
  AudioPlayer? _audioPlayer;

  /// The ID of the currently selected sound for the video
  String? selectedSoundId;

  /// The ID of the currently playing sound
  String? _currentSoundId;

  /// Initialize the audio player
  Future<void> initialize() async {
    _audioPlayer = AudioPlayer();
  }

  /// Select a sound for the video
  void selectSound(String? soundId) {
    selectedSoundId = soundId;
    onStateChanged();
  }

  /// Load and play the selected sound, synced with video
  Future<void> loadAndPlaySound(String? soundId) async {
    if (soundId == _currentSoundId) return;
    _currentSoundId = soundId;

    // Stop current audio
    await _audioPlayer?.stop();

    if (soundId == null) {
      // No sound selected - unmute video
      await videoController.setVolume(1.0);
      return;
    }

    // Mute video's original audio when playing selected sound
    await videoController.setVolume(0.0);

    // For now, we'll need to pass in the sound service from outside
    // This will be called from the screen with the sound object
    Log.info('Loading sound: $soundId', category: LogCategory.video);
  }

  /// Actually play the sound file
  Future<void> playSound(String filePath, String soundTitle) async {
    try {
      await _audioPlayer?.setUrl('file:$filePath');

      // Set looping to match video
      await _audioPlayer?.setLoopMode(.all);

      // Play the audio
      await resumeAudio();

      Log.info('Playing sound: $soundTitle', category: LogCategory.video);
    } catch (e) {
      Log.error('Failed to play sound: $e', category: LogCategory.video);
      // Unmute video on error
      await videoController.setVolume(1.0);
    }
  }

  /// Stop the audio player
  Future<void> stopAudio() async {
    await _audioPlayer?.stop();
  }

  /// Pause the audio player
  Future<void> pauseAudio() async {
    await _audioPlayer?.pause();
  }

  /// Resume the audio player
  Future<void> resumeAudio() async {
    await _audioPlayer?.play();
  }

  /// Dispose of the audio player
  void dispose() {
    _audioPlayer?.dispose();
  }
}
