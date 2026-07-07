// ABOUTME: Maps CameraX video quality to a target encoder bitrate
// ABOUTME: Mirrors DivineVideoQuality.bitrate in lib/src/models/video_quality.dart

package co.openvine.divine_camera

import androidx.camera.video.Quality

/**
 * Target video encoding bitrate in bits per second for [quality].
 *
 * Without an explicit target, CameraX falls back to the device encoder's
 * default, which for FHD typically lands at 15–25 Mbit/s — roughly twice
 * the intended file size. Values must stay in sync with the Dart
 * `DivineVideoQuality` enum (`lib/src/models/video_quality.dart`).
 */
internal fun videoEncodingBitRate(quality: Quality): Int = when (quality) {
    Quality.SD, Quality.LOWEST -> 2_000_000
    Quality.HD -> 4_000_000
    Quality.FHD -> 8_000_000
    Quality.UHD, Quality.HIGHEST -> 20_000_000
    else -> 8_000_000
}
