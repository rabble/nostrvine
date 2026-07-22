// ABOUTME: Unit tests for TranscriptionSession's word end-time derivation.
// ABOUTME: Pins the final-word fallback so it never stretches to clip end.

package co.openvine.caption_generator

import kotlin.test.assertEquals
import kotlin.test.assertNull
import org.junit.Test

// Pure timing logic with no Android framework dependency, so it runs on the
// plain JUnit runner rather than Robolectric.
internal class TranscriptionSegmentTimingTest {
    @Test
    fun nonFinalWord_endsAtNextWordStart() {
        val starts = listOf(0L, 500L, 1200L)

        assertEquals(
            500L,
            TranscriptionSession.wordEndMs(
                starts,
                index = 0,
                audioDurationMs = 30_000L,
                fallbackMs = 2_000L,
            ),
        )
    }

    @Test
    fun finalWord_usesBoundedFallbackNotClipEnd() {
        // 30s clip whose speech ends at 3.2s: the trailing word must not run to
        // 30s (which would strand a lone caption across the trailing silence).
        val starts = listOf(0L, 800L, 1600L, 2400L, 3200L)
        val fallback = TranscriptionSession.medianInterWordGapMs(starts)

        val end = TranscriptionSession.wordEndMs(
            starts,
            index = starts.lastIndex,
            audioDurationMs = 30_000L,
            fallbackMs = fallback!!,
        )

        // median gap is 800ms, so the last word ends at 3200 + 800 = 4000ms.
        assertEquals(4_000L, end)
    }

    @Test
    fun finalWord_fallbackClampedToAudioDuration() {
        val starts = listOf(0L, 4_500L)

        val end = TranscriptionSession.wordEndMs(
            starts,
            index = 1,
            audioDurationMs = 5_000L,
            fallbackMs = 2_000L,
        )

        // 4500 + 2000 would be 6500, past the 5000ms clip; clamp to 5000.
        assertEquals(5_000L, end)
    }

    @Test
    fun endNeverPrecedesStart_whenDurationShorterThanStart() {
        val starts = listOf(0L, 6_000L)

        val end = TranscriptionSession.wordEndMs(
            starts,
            index = 1,
            audioDurationMs = 3_000L,
            fallbackMs = 1_000L,
        )

        assertEquals(6_000L, end)
    }

    @Test
    fun medianInterWordGap_isNullForFewerThanTwoWords() {
        assertNull(TranscriptionSession.medianInterWordGapMs(emptyList()))
        assertNull(TranscriptionSession.medianInterWordGapMs(listOf(1_000L)))
    }

    @Test
    fun medianInterWordGap_averagesTheTwoMiddleGaps() {
        // Gaps: 200, 400, 1000, 1000 -> median of the middle two = 700.
        val starts = listOf(0L, 200L, 600L, 1_600L, 2_600L)

        assertEquals(700L, TranscriptionSession.medianInterWordGapMs(starts))
    }
}
