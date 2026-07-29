package com.divinevideo.divine_video_player

import androidx.media3.common.C
import androidx.media3.common.audio.AudioProcessor
import androidx.media3.common.util.UnstableApi
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Guards the fade that keeps a looping video's join from clicking (#6468).
 *
 * A loop restart cuts from the video's last sample straight back to its first.
 * Both edges have to reach zero for that join to be silent — and the last one
 * has to reach zero where the audio really ends, not where the container says
 * it does.
 */
@UnstableApi
class LoopDeclickAudioProcessorTest {

    private val sampleRate = 48_000

    /** 10 ms at 48 kHz. */
    private val fadeFrames = 480L

    /** 6 s at 48 kHz. */
    private val durationFrames = 288_000L

    /** Full-scale mono sample the buffer-level tests feed. */
    private val level: Short = 20_000

    private fun processor(
        durationUs: Long = 6_000_000L,
        enabled: Boolean = true,
    ): LoopDeclickAudioProcessor = LoopDeclickAudioProcessor().apply {
        this.videoDurationUs = durationUs
        this.enabled = enabled
    }

    /** A processor already through `configure`, ready to be flushed. */
    private fun configured(
        durationUs: Long = 6_000_000L,
        enabled: Boolean = true,
        channelCount: Int = 1,
    ): LoopDeclickAudioProcessor =
        processor(durationUs = durationUs, enabled = enabled).apply {
            configure(
                AudioProcessor.AudioFormat(sampleRate, channelCount, C.ENCODING_PCM_16BIT),
            )
        }

    private fun LoopDeclickAudioProcessor.flushPipeline() =
        flush(AudioProcessor.StreamMetadata.DEFAULT)

    /**
     * [frames] interleaved frames, one sample per entry of [levels]. Native
     * order is what media3 hands an `AudioProcessor` and what
     * `replaceOutputBuffer` allocates.
     */
    private fun pcm(frames: Int, levels: List<Short> = listOf(level)): ByteBuffer =
        ByteBuffer.allocateDirect(frames * levels.size * 2)
            .order(ByteOrder.nativeOrder())
            .apply {
                repeat(frames) { levels.forEach(::putShort) }
                flip()
            }

    private fun ByteBuffer.samples(): ShortArray =
        ShortArray(remaining() / 2) { short }

    /** Pushes [frames] frames through and returns the samples that came out. */
    private fun LoopDeclickAudioProcessor.push(
        frames: Int,
        levels: List<Short> = listOf(level),
    ): ShortArray {
        queueInput(pcm(frames, levels))
        return output.samples()
    }

    /**
     * What `DefaultAudioSink.drainToEndOfStream()` does at a loop join: tell
     * the pipeline the stream ended, then read until the processor is done.
     */
    private fun LoopDeclickAudioProcessor.drainToEnd(): ShortArray {
        queueEndOfStream()
        val drained = mutableListOf<Short>()
        var guard = 0
        while (!isEnded && guard++ < 8) {
            drained += output.samples().toList()
        }
        return drained.toShortArray()
    }

    @Test
    fun `the video starts at silence and reaches full gain`() {
        val subject = processor()

        assertEquals(0f, subject.fadeInGainAt(0, fadeFrames), 0f)
        assertEquals(1f, subject.fadeInGainAt(fadeFrames, fadeFrames), 0f)
        assertEquals(1f, subject.fadeInGainAt(durationFrames, fadeFrames), 0f)
    }

    @Test
    fun `the fade in rises monotonically`() {
        val subject = processor()

        var previous = -1f
        for (frame in 0 until fadeFrames) {
            val gain = subject.fadeInGainAt(frame, fadeFrames)
            assertTrue("fade in must not dip at frame $frame", gain > previous)
            previous = gain
        }
    }

    @Test
    fun `a multi-clip timeline is not faded`() {
        val subject = processor(enabled = false)

        assertEquals(0L, subject.fadeFrames(sampleRate))
        assertEquals(1f, subject.fadeInGainAt(0, subject.fadeFrames(sampleRate)), 0f)
    }

    @Test
    fun `the two fades of a short video never overlap`() {
        // 12 ms cannot carry two 10 ms fades.
        val subject = processor(durationUs = 12_000L)
        val shortDurationFrames = 12L * sampleRate / 1000L

        assertTrue(
            "fade must shrink to fit",
            subject.fadeFrames(sampleRate) * 2 <= shortDurationFrames,
        )
    }

    @Test
    fun `the fade is ten milliseconds, which is also the added latency`() {
        assertEquals(fadeFrames, processor().fadeFrames(sampleRate))
    }

    @Test
    fun `the stream fades out where it ends, not where the container says`() {
        // The container claims 100 ms — 4800 frames — and the audio track
        // delivers 3000. Timing the fade out off the declared length put it
        // 1800 frames past the join, so the first lap of such a video clicked
        // until a whole loop had been measured. Nothing is timed off it now.
        val subject = configured(durationUs = 100_000L)
        subject.flushPipeline()
        subject.push(3_000)

        val tail = subject.drainToEnd()

        assertEquals(fadeFrames.toInt(), tail.size)
        assertEquals("the join must be silent", 0, tail.last().toInt())
        assertTrue("the ramp must start at full gain", tail.first() > level * 0.99)
    }

    @Test
    fun `a video whose length is unknown still fades out`() {
        val subject = configured(durationUs = LoopDeclickAudioProcessor.DURATION_UNKNOWN)
        subject.flushPipeline()
        subject.push(2_000)

        val tail = subject.drainToEnd()

        assertEquals(fadeFrames.toInt(), tail.size)
        assertEquals(0, tail.last().toInt())
    }

    @Test
    fun `the fade out falls monotonically into the join`() {
        val subject = configured()
        subject.flushPipeline()
        subject.push(2_000)

        val tail = subject.drainToEnd()

        var previous = Short.MAX_VALUE
        for ((index, sample) in tail.withIndex()) {
            assertTrue("fade out must not rise at frame $index", sample < previous)
            previous = sample
        }
    }

    @Test
    fun `the fade holds the last ten milliseconds back`() {
        val subject = configured()
        subject.flushPipeline()

        assertEquals(1_000 - fadeFrames.toInt(), subject.push(1_000).size)
    }

    @Test
    fun `a flush drops the tail rather than playing it late`() {
        val subject = configured()
        subject.flushPipeline()
        subject.push(1_000)

        // A seek discards these frames; they must not surface at the next end
        // of stream.
        subject.flushPipeline()

        assertEquals(0, subject.drainToEnd().size)
    }

    @Test
    fun `a multi-clip timeline is passed through without delay`() {
        val subject = configured(enabled = false)
        subject.flushPipeline()

        val out = subject.push(1_000)

        assertEquals(1_000, out.size)
        assertEquals(level.toInt(), out.first().toInt())
        assertEquals(level.toInt(), out.last().toInt())
        assertEquals(0, subject.drainToEnd().size)
    }

    @Test
    fun `the seek offset survives the second flush a seek triggers`() {
        val subject = configured()
        subject.nextStreamStartUs = 3_000_000L

        // media3 flushes the pipeline twice before the first frame of a seek
        // arrives: once from DefaultAudioSink.flush(), which releases the audio
        // output, and again when the next buffer rebuilds it.
        subject.flushPipeline()
        subject.flushPipeline()

        // Half way in is in neither fade. An offset consumed by the first
        // flush would leave this anchored at zero and fade in mid-video.
        assertEquals(level.toInt(), subject.push(1_000).first().toInt())
    }

    @Test
    fun `the buffers a seek discards do not anchor a loop`() {
        val subject = configured()
        subject.nextStreamStartUs = 3_000_000L
        subject.flushPipeline()

        // MediaCodecAudioRenderer reports every buffer it drops on the way to
        // the seek target as a discontinuity. None of them is a loop restart.
        subject.onStreamChanged()
        subject.onStreamChanged()

        assertEquals(level.toInt(), subject.push(1_000).first().toInt())
    }

    @Test
    fun `a loop restart fades in again`() {
        val subject = configured()
        subject.flushPipeline()
        subject.push(1_000)

        subject.onStreamChanged()
        // media3 resyncs the pipeline before the first buffer of the new lap.
        subject.flushPipeline()

        assertEquals(0, subject.push(1_000).first().toInt())
    }

    @Test
    fun `a stereo fade scales each channel by the frame's own gain`() {
        val leftLevel: Short = 20_000
        val rightLevel: Short = -12_000
        val subject = configured(channelCount = 2)
        subject.flushPipeline()

        val out = subject.push(fadeFrames.toInt() * 2, listOf(leftLevel, rightLevel))

        // Half way into the fade in, each channel carries half of its own
        // level — not half of the left one twice.
        val frame = fadeFrames.toInt() / 2
        val gain = frame.toFloat() / fadeFrames
        assertEquals((leftLevel * gain).toInt(), out[frame * 2].toInt())
        assertEquals((rightLevel * gain).toInt(), out[frame * 2 + 1].toInt())
    }

    @Test
    fun `a stereo stream holds back frames, not samples`() {
        val subject = configured(channelCount = 2)
        subject.flushPipeline()
        subject.push(2_000, listOf(level, level))

        val tail = subject.drainToEnd()

        // 480 frames of two channels. Counting interleaved samples as frames
        // would hold back half a fade and end it in the wrong place.
        assertEquals(fadeFrames.toInt() * 2, tail.size)
        assertEquals(0, tail[tail.size - 2].toInt())
        assertEquals(0, tail[tail.size - 1].toInt())
    }
}
