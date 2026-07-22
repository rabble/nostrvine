// ABOUTME: Pure region/language policy for the mandatory recording start/stop
// ABOUTME: sound (Japan JEITA/carrier + Korea KCC rules); shared decision logic

package co.openvine.divine_camera

/**
 * Pure decision logic for the region-mandated recording sound.
 *
 * divine_camera records through a custom CameraX pipeline instead of the
 * system camera, so Android does not automatically emit the record start/stop
 * sound that phones sold in Japan and South Korea must play. Japan enforces
 * this via JEITA/carrier device certification; South Korea via KCC
 * type-approval (a ~65 dB, non-silenceable tone). A custom pipeline is
 * responsible for replicating the behavior.
 *
 * The decision is region-first with the device language as a widening
 * safeguard: the hardware region lock is not exposed by API, so a JP/KR device
 * whose owner switched their region away is missed by region alone. Falling
 * back to the `ja`/`ko` device language catches that case, at the cost of also
 * firing for JP/KR-language users elsewhere.
 */
object RecordingSoundPolicy {
    /** Region codes whose devices must play a non-silenceable recording sound. */
    val mandatorySoundRegionCodes: Set<String> = setOf("JP", "KR")

    /** Device language codes that also mandate the sound, as a widening safeguard. */
    val mandatorySoundLanguageCodes: Set<String> = setOf("ja", "ko")

    /**
     * Whether a device with this [regionCode] or [languageCode] must play the
     * recording start/stop sound. Either match is sufficient; null/blank values
     * are ignored; matching is case-insensitive.
     */
    fun requiresRecordingSound(regionCode: String?, languageCode: String?): Boolean {
        if (!regionCode.isNullOrEmpty() &&
            mandatorySoundRegionCodes.contains(regionCode.uppercase())
        ) {
            return true
        }
        if (!languageCode.isNullOrEmpty() &&
            mandatorySoundLanguageCodes.contains(languageCode.lowercase())
        ) {
            return true
        }
        return false
    }
}
