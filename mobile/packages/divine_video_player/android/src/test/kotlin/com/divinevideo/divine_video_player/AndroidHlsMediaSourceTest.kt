package com.divinevideo.divine_video_player

import androidx.media3.exoplayer.hls.HlsMediaSource
import org.junit.Assert.assertTrue
import org.junit.Test

class AndroidHlsMediaSourceTest {

    @Test
    fun `HLS media source classes are available on Android classpath`() {
        val hlsClass = Class.forName(
            "androidx.media3.exoplayer.hls.HlsMediaSource",
        )

        assertTrue(HlsMediaSource::class.java.isAssignableFrom(hlsClass))
    }
}
