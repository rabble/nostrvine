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
 * Both edges have to reach zero for that join to be silent.
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
        channelCount: Int = 1,
    ): LoopDeclickAudioProcessor = processor(durationUs = durationUs).apply {
        configure(
            AudioProcessor.AudioFormat(sampleRate, channelCount, C.ENCODING_PCM_16BIT),
        )
    }

    private fun LoopDeclickAudioProcessor.flushPipeline() =
        flush(AudioProcessor.StreamMetadata.DEFAULT)

    /**
     * [frames] interleaved frames, each carrying one sample per entry of
     * [levels]. Native order is what media3 hands an [AudioProcessor] and what
     * `replaceOutputBuffer` allocates.
     */
    private fun pcm(frames: Int, levels: List<Short> = listOf(level)): ByteBuffer =
        ByteBuffer.allocateDirect(frames * levels.size * 2)
            .order(ByteOrder.nativeOrder())
            .apply {
                repeat(frames) { levels.forEach(::putShort) }
                flip()
            }

    /** Pushes [frames] mono frames through and returns the gain of the last. */
    private fun LoopDeclickAudioProcessor.play(frames: Int): Float {
        queueInput(pcm(frames))
        val out = output
        val last = out.getShort((frames - 1) * 2)
        return last.toFloat() / level
    }

    /** Pushes [frames] frames of [levels] through and returns every sample. */
    private fun LoopDeclickAudioProcessor.playInterleaved(
        frames: Int,
        levels: List<Short>,
    ): ShortArray {
        queueInput(pcm(frames, levels))
        val out = output
        return ShortArray(frames * levels.size) { out.getShort(it * 2) }
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
        // flush would leave this anchored at zero, fading in mid-video and
        // putting the fade out three seconds early.
        assertEquals(1f, subject.play(1), 0f)
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

        assertEquals(1f, subject.play(1), 0f)
    }

    @Test
    fun `a loop restart fades in again`() {
        val subject = configured()
        subject.flushPipeline()
        subject.play(1_000)

        subject.onStreamChanged()

        assertEquals(0f, subject.play(1), 0f)
    }

    @Test
    fun `the first loop falls back to the container's duration`() {
        // 100 ms at 48 kHz is 4800 frames, and nothing has been measured yet.
        val subject = configured(durationUs = 100_000L)
        subject.flushPipeline()

        assertEquals(1f, subject.play(4_800 - fadeFrames.toInt() + 1), 0f)
        assertTrue("fade out must start before the container's end", subject.play(1) < 1f)
    }

    @Test
    fun `later loops follow the frames one really delivered`() {
        // The container claims 100 ms (4800 frames) but the audio track only
        // ever delivers 3000. Trusting the container would put the fade out
        // 1800 frames past the join, so the loop would still click.
        val subject = configured(durationUs = 100_000L)
        subject.flushPipeline()
        subject.play(3_000)
        subject.onStreamChanged()

        assertEquals(1f, subject.play(3_000 - fadeFrames.toInt() + 1), 0f)
        assertTrue("fade out must start where the loop really ends", subject.play(1) < 1f)
    }

    @Test
    fun `a loop cut short by an unrelated flush is not measured`() {
        val subject = configured(durationUs = 100_000L)
        subject.flushPipeline()
        subject.play(1_000)
        // A route change or an underrun flushes mid-loop, which restarts the
        // count. What reaches the join is not the length of a loop.
        subject.flushPipeline()
        subject.play(1_000)
        subject.onStreamChanged()

        assertEquals(1f, subject.play(4_800 - fadeFrames.toInt() + 1), 0f)
        assertTrue("the container's estimate must survive", subject.play(1) < 1f)
    }

    @Test
    fun `most of a loop is still not a measurement of one`() {
        val subject = configured(durationUs = 100_000L)
        subject.flushPipeline()
        subject.play(1_000)
        // Mid-loop flush again, but this time what follows is 62% of the
        // container's 4800 frames. A guard that only rejects fragments under
        // half the estimate takes this one and puts the fade out 1800 frames
        // early for the rest of the video.
        subject.flushPipeline()
        subject.play(3_000)
        subject.onStreamChanged()

        assertEquals(1f, subject.play(4_800 - fadeFrames.toInt() + 1), 0f)
        assertTrue("the container's estimate must survive", subject.play(1) < 1f)
    }

    @Test
    fun `a new video drops the previous one's measurement`() {
        val subject = configured(durationUs = 100_000L)
        subject.flushPipeline()
        subject.play(3_000)
        subject.onStreamChanged()

        // What setClips does: clear the length, then publish the new one.
        subject.videoDurationUs = LoopDeclickAudioProcessor.DURATION_UNKNOWN
        subject.videoDurationUs = 200_000L
        subject.flushPipeline()

        // 9600 frames now. Reusing the 3000-frame measurement would wrap here
        // and silence the frame instead.
        assertEquals(1f, subject.play(3_001), 0f)
    }

    @Test
    fun `a new video of the same length drops it too`() {
        val subject = configured(durationUs = 100_000L)
        subject.flushPipeline()
        subject.play(3_000)
        subject.onStreamChanged()

        // A player is reused across videos and never reset between them, so
        // two videos that agree to the millisecond must not share a frame
        // count — they disagree by up to an AAC frame, which is wider than
        // the fade.
        subject.videoDurationUs = LoopDeclickAudioProcessor.DURATION_UNKNOWN
        subject.videoDurationUs = 100_000L
        subject.flushPipeline()

        assertEquals(1f, subject.play(3_001), 0f)
    }

    @Test
    fun `a stereo fade scales each channel by the frame's own gain`() {
        val leftLevel: Short = 20_000
        val rightLevel: Short = -12_000
        val subject = configured(channelCount = 2)
        subject.flushPipeline()

        val samples = subject.playInterleaved(
            fadeFrames.toInt(),
            listOf(leftLevel, rightLevel),
        )

        // Half way into the fade in, each channel carries half of its own
        // level — not half of the left one twice.
        val frame = fadeFrames.toInt() / 2
        val gain = frame.toFloat() / fadeFrames
        assertEquals((leftLevel * gain).toInt(), samples[frame * 2].toInt())
        assertEquals((rightLevel * gain).toInt(), samples[frame * 2 + 1].toInt())
    }

    @Test
    fun `stereo frames advance the position once per frame, not per sample`() {
        val subject = configured(durationUs = 100_000L, channelCount = 2)
        subject.flushPipeline()

        // 4800 frames. Counting interleaved samples instead would reach the
        // end of the video half way through it.
        val flat = subject.playInterleaved(
            4_800 - fadeFrames.toInt() + 1,
            listOf(level, level),
        )
        assertEquals(level.toInt(), flat.last().toInt())

        val fading = subject.playInterleaved(1, listOf(level, level))
        assertTrue("fade out must start at the video's end", fading.first() < level)
    }
}
