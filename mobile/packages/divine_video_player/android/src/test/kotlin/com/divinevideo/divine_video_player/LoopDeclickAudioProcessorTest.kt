package com.divinevideo.divine_video_player

import androidx.media3.common.util.UnstableApi
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Guards the fade that keeps a looping video's join from clicking (#6468).
 *
 * A loop restart cuts from the video's last sample straight back to its first.
 * Both edges have to reach zero for that join to be silent.
 */
@UnstableApi
class LoopDeclickAudioProcessorTest {

    private val sampleRate = 48_000

    /** 10 ms at 48 kHz. */
    private val fadeFrames = 480L

    /** 6 s at 48 kHz. */
    private val durationFrames = 288_000L

    private fun processor(
        durationUs: Long = 6_000_000L,
        enabled: Boolean = true,
    ): LoopDeclickAudioProcessor = LoopDeclickAudioProcessor().apply {
        this.videoDurationUs = durationUs
        this.enabled = enabled
    }

    @Test
    fun `both edges of the video reach silence`() {
        val subject = processor()

        assertEquals(0f, subject.gainAt(0, fadeFrames, durationFrames), 0f)
        assertEquals(
            0f,
            subject.gainAt(durationFrames - 1, fadeFrames, durationFrames),
            1f / fadeFrames,
        )
    }

    @Test
    fun `the middle of the video is untouched`() {
        val subject = processor()

        assertEquals(1f, subject.gainAt(fadeFrames, fadeFrames, durationFrames), 0f)
        assertEquals(1f, subject.gainAt(durationFrames / 2, fadeFrames, durationFrames), 0f)
        assertEquals(
            1f,
            subject.gainAt(durationFrames - fadeFrames, fadeFrames, durationFrames),
            0f,
        )
    }

    @Test
    fun `the fade rises and falls monotonically`() {
        val subject = processor()

        var previous = -1f
        for (frame in 0 until fadeFrames) {
            val gain = subject.gainAt(frame, fadeFrames, durationFrames)
            assertTrue("fade in must not dip at frame $frame", gain > previous)
            previous = gain
        }

        previous = 2f
        for (frame in (durationFrames - fadeFrames + 1) until durationFrames) {
            val gain = subject.gainAt(frame, fadeFrames, durationFrames)
            assertTrue("fade out must not rise at frame $frame", gain < previous)
            previous = gain
        }
    }

    @Test
    fun `a video whose length is unknown still fades in`() {
        val subject = processor(durationUs = LoopDeclickAudioProcessor.DURATION_UNKNOWN)

        assertEquals(0f, subject.gainAt(0, fadeFrames, 0), 0f)
        assertEquals(1f, subject.gainAt(fadeFrames, fadeFrames, 0), 0f)
        // Nothing to fade out into, so the rest plays at full gain rather than
        // fading at a guessed end.
        assertEquals(1f, subject.gainAt(durationFrames, fadeFrames, 0), 0f)
    }

    @Test
    fun `a position past the end wraps instead of muting`() {
        val subject = processor()

        // A stream change that never arrives would leave the position running
        // past the video for good. Wrapping keeps the fade merely imprecise;
        // clamping would silence everything after the first loop.
        assertEquals(
            subject.gainAt(durationFrames / 2, fadeFrames, durationFrames),
            subject.gainAt(durationFrames + durationFrames / 2, fadeFrames, durationFrames),
            0f,
        )
        assertEquals(
            1f,
            subject.gainAt(durationFrames * 3 + fadeFrames, fadeFrames, durationFrames),
            0f,
        )
    }

    @Test
    fun `the two fades of a short video never overlap`() {
        // 12 ms cannot carry two 10 ms fades.
        val subject = processor(durationUs = 12_000L)
        val shortDurationFrames = 12L * sampleRate / 1000L
        val fade = subject.fadeFrames(sampleRate)

        assertTrue("fade must shrink to fit", fade * 2 <= shortDurationFrames)
        assertEquals(0f, subject.gainAt(0, fade, shortDurationFrames), 0f)
        assertEquals(
            0f,
            subject.gainAt(shortDurationFrames - 1, fade, shortDurationFrames),
            1f / fade,
        )
    }

    @Test
    fun `a multi-clip timeline is not faded`() {
        val subject = processor(enabled = false)

        assertEquals(0L, subject.fadeFrames(sampleRate))
        assertEquals(1f, subject.gainAt(0, subject.fadeFrames(sampleRate), durationFrames), 0f)
    }

    @Test
    fun `fade length matches the Apple player`() {
        val subject = processor()

        assertEquals(10_000L, LoopDeclickAudioProcessor.FADE_US)
        assertEquals(fadeFrames, subject.fadeFrames(sampleRate))
    }
}
