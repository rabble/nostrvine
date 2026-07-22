package co.openvine.divine_camera

import kotlin.test.assertFalse
import kotlin.test.assertTrue
import org.junit.Test

/*
 * Pins the region/language gate for the JP/KR-mandated recording sound.
 * divine_camera records through CameraX (a custom pipeline), so the OS does
 * not auto-play the sound that phones sold in Japan/South Korea must emit —
 * this policy decides when the app plays it itself.
 */
internal class RecordingSoundPolicyTest {
    @Test
    fun requiresRecordingSound_trueForJapanRegion() {
        assertTrue(RecordingSoundPolicy.requiresRecordingSound("JP", "en"))
    }

    @Test
    fun requiresRecordingSound_trueForKoreaRegion() {
        assertTrue(RecordingSoundPolicy.requiresRecordingSound("KR", "en"))
    }

    @Test
    fun requiresRecordingSound_trueForJapaneseLanguageElsewhere() {
        assertTrue(RecordingSoundPolicy.requiresRecordingSound("US", "ja"))
    }

    @Test
    fun requiresRecordingSound_trueForKoreanLanguageElsewhere() {
        assertTrue(RecordingSoundPolicy.requiresRecordingSound("US", "ko"))
    }

    @Test
    fun requiresRecordingSound_caseInsensitive() {
        assertTrue(RecordingSoundPolicy.requiresRecordingSound("jp", null))
        assertTrue(RecordingSoundPolicy.requiresRecordingSound(null, "JA"))
    }

    @Test
    fun requiresRecordingSound_falseForOtherRegionAndLanguage() {
        assertFalse(RecordingSoundPolicy.requiresRecordingSound("US", "en"))
        assertFalse(RecordingSoundPolicy.requiresRecordingSound("DE", "de"))
    }

    @Test
    fun requiresRecordingSound_falseWhenBothUnknown() {
        assertFalse(RecordingSoundPolicy.requiresRecordingSound(null, null))
        assertFalse(RecordingSoundPolicy.requiresRecordingSound("", ""))
    }
}
