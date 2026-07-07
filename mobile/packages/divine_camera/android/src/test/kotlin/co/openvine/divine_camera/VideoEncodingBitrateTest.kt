package co.openvine.divine_camera

import androidx.camera.video.Quality
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals

/*
 * Pins the quality → target-bitrate table used by the recording Recorder.
 * Without an explicit target bitrate, CameraX falls back to device encoder
 * defaults (15–25 Mbit/s for FHD). The values must stay in sync with the
 * Dart `DivineVideoQuality` enum in lib/src/models/video_quality.dart.
 */
@RunWith(RobolectricTestRunner::class)
internal class VideoEncodingBitrateTest {
    @Test
    fun videoEncodingBitRate_matchesDivineVideoQualityTable() {
        assertEquals(2_000_000, videoEncodingBitRate(Quality.SD))
        assertEquals(2_000_000, videoEncodingBitRate(Quality.LOWEST))
        assertEquals(4_000_000, videoEncodingBitRate(Quality.HD))
        assertEquals(8_000_000, videoEncodingBitRate(Quality.FHD))
        assertEquals(20_000_000, videoEncodingBitRate(Quality.UHD))
        assertEquals(20_000_000, videoEncodingBitRate(Quality.HIGHEST))
    }
}
