// ABOUTME: Picks the recording audio source from the connected input devices
// ABOUTME: CAMCORDER ranks USB below the built-in mic, so an attached USB mic uses MIC

package co.openvine.divine_camera

import android.media.AudioDeviceInfo
import android.media.MediaRecorder
import androidx.camera.video.AudioSpec

/**
 * The order AOSP picks an input device in for every source this file can
 * choose — `MIC`, `VOICE_RECOGNITION` and `UNPROCESSED`.
 *
 * `Engine::getDeviceForInputSource` keeps two separate `case` blocks, one for
 * `MIC`/`DEFAULT` and one shared by `VOICE_RECOGNITION`/`UNPROCESSED`, but
 * hands both the same list, and has since Android 13. So switching *between*
 * these three sources changes the processing and never the device — which is
 * what makes Music mode composable with the external-mic fix below.
 *
 * `CAMCORDER`, which [AudioSpec.SOURCE_AUTO] resolves to, is the odd one out:
 * `BACK_MIC, BUILTIN_MIC, USB_DEVICE`. It is the only source that will not
 * route to a wired headset or to Bluetooth, and the only one that prefers the
 * rear mic.
 */
private val MIC_FAMILY_DEVICE_PRIORITY = intArrayOf(
    AudioDeviceInfo.TYPE_WIRED_HEADSET,
    AudioDeviceInfo.TYPE_USB_HEADSET,
    AudioDeviceInfo.TYPE_USB_DEVICE,
    AudioDeviceInfo.TYPE_BLE_HEADSET,
    AudioDeviceInfo.TYPE_BUILTIN_MIC
)

/**
 * Input device types that mean the user attached something to record with.
 *
 * Only devices reported by `AudioManager.GET_DEVICES_INPUTS` are ever tested
 * against this set, so every entry is a real capture device.
 *
 * USB covers both of its input types, because the split between them is not
 * the split it looks like. AOSP scores a USB peripheral in
 * `UsbDescriptorParser.getInputHeadsetProbability()`, where `hasMic() &&
 * hasSpeaker()` alone contributes the full `IN_HEADSET_TRIGGER` of 0.75, and
 * `hasSpeaker()` counts a `TERMINAL_OUT_HEADPHONES` terminal. A microphone or
 * wireless receiver with a **monitoring jack** therefore enumerates as
 * `TYPE_USB_HEADSET`, not `TYPE_USB_DEVICE` — and monitoring output is
 * standard on the receivers #6171 is about. Excluding that type would drop
 * most of the hardware this exists to fix.
 *
 * Monitoring earbuds land on the same type and cannot be told apart:
 * `AudioDeviceInfo` carries only type, id, address, product name and channel
 * counts, and the output-device list matches both. So USB is treated as
 * intent to record — plugging a USB peripheral into a phone you are filming
 * on is a deliberate act.
 */
private val EXTERNAL_MIC_TYPES = setOf(
    AudioDeviceInfo.TYPE_USB_DEVICE,
    AudioDeviceInfo.TYPE_USB_HEADSET
)

/**
 * Input types someone is wearing to listen, not holding to record.
 *
 * Both outrank the built-in mic in [MIC_FAMILY_DEVICE_PRIORITY], and neither
 * appears in `CAMCORDER`'s list at all. So whenever one of these would be the
 * captured device, leaving the source alone is the only way to keep the
 * recording off the user's earbuds — see [audioSourceForInputDeviceTypes].
 */
private val LISTENING_ONLY_TYPES = setOf(
    AudioDeviceInfo.TYPE_WIRED_HEADSET,
    AudioDeviceInfo.TYPE_BLE_HEADSET
)

/**
 * The audio source a new Recorder should capture from, given the connected
 * input device [types], whether the user turned on Music mode
 * ([preferUnprocessedAudio]) and whether this device reports support for the
 * unprocessed source ([unprocessedSourceSupported]).
 *
 * CameraX leaves the source at [AudioSpec.SOURCE_AUTO], which resolves to
 * `MediaRecorder.AudioSource.CAMCORDER`. Two independent things can pull us
 * off that default, and they compose because every source we can move to
 * shares one device ordering (see [MIC_FAMILY_DEVICE_PRIORITY]):
 *
 *  - **An attached USB microphone (#6171).** `CAMCORDER` ranks USB behind the
 *    built-in mic, so it is reachable only on a device with no built-in mic —
 *    on a phone, never. The MIC-family ordering puts USB ahead of the built-in
 *    mic, which is what someone who just plugged a microphone in expects.
 *  - **Music mode (#7796, #8079).** The CDD requires `UNPROCESSED` to carry
 *    no gain control, filtering or echo cancellation (§5.11 [C-1-8]) — that
 *    processing is what flattens a sustained instrument. Support is opt-in per
 *    device, and where it is missing the constant is documented to "behave
 *    like DEFAULT", i.e. silently give back the processing we were escaping.
 *    So an unsupported device falls to `VOICE_RECOGNITION`, Android's own
 *    recommended substitute, which the CDD separately requires to disable
 *    automatic gain control and noise reduction (§5.4.2 [C-1-2], [C-1-3]).
 *
 * The one thing that stops both is a device the user is only listening on.
 * `CAMCORDER` is the sole source that will not route to a wired headset or to
 * Bluetooth, so if either would win the device race, *any* switch moves the
 * recording onto their earbud mic — worse than the processing or the built-in
 * mic we were trying to escape. Those cases keep [AudioSpec.SOURCE_AUTO] and
 * give up on both goals deliberately.
 *
 * Music mode with nothing attached still switches. It is a request about
 * processing rather than about devices, and the only device it can cost is
 * `BACK_MIC`, which `CAMCORDER` prefers and the MIC family does not list —
 * an accepted trade on the phones that declare one, since a gated instrument
 * is the louder complaint than a front-facing mic.
 *
 * Two limits worth knowing, neither of them reachable from here. On Android 12
 * only, `BLE_HEADSET` is prepended to the shared ordering, so earbuds outrank
 * a USB mic there and the last case above picks the wrong device; Android 13
 * onward ranks USB first, and there is no runtime handle on the ordering to
 * branch off. And while the phone is in a telephony *or VoIP* call, AOSP
 * rewrites every source here to `VOICE_COMMUNICATION` before selecting a
 * device, so none of this applies for the duration of the call.
 */
internal fun audioSourceForInputDeviceTypes(
    types: IntArray,
    preferUnprocessedAudio: Boolean = false,
    unprocessedSourceSupported: Boolean = false
): Int {
    val captured = MIC_FAMILY_DEVICE_PRIORITY.firstOrNull { it in types }
    if (captured != null && captured in LISTENING_ONLY_TYPES) {
        return AudioSpec.SOURCE_AUTO
    }
    return when {
        preferUnprocessedAudio && unprocessedSourceSupported ->
            MediaRecorder.AudioSource.UNPROCESSED
        preferUnprocessedAudio -> MediaRecorder.AudioSource.VOICE_RECOGNITION
        captured != null && captured in EXTERNAL_MIC_TYPES ->
            MediaRecorder.AudioSource.MIC
        else -> AudioSpec.SOURCE_AUTO
    }
}

/**
 * Short readable name for an `AudioDeviceInfo` input [type], used by the
 * diagnostic line the camera writes when it resolves the recording source.
 *
 * Unknown types fall back to the raw constant on purpose: a device reporting
 * an input we do not map is the exact failure mode behind #6171, and it has to
 * survive into the bug report rather than disappear.
 */
internal fun audioInputTypeName(type: Int): String = when (type) {
    AudioDeviceInfo.TYPE_BUILTIN_MIC -> "BUILTIN_MIC"
    AudioDeviceInfo.TYPE_USB_DEVICE -> "USB_DEVICE"
    AudioDeviceInfo.TYPE_USB_HEADSET -> "USB_HEADSET"
    AudioDeviceInfo.TYPE_USB_ACCESSORY -> "USB_ACCESSORY"
    AudioDeviceInfo.TYPE_WIRED_HEADSET -> "WIRED_HEADSET"
    AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "BLUETOOTH_SCO"
    AudioDeviceInfo.TYPE_BLE_HEADSET -> "BLE_HEADSET"
    AudioDeviceInfo.TYPE_TELEPHONY -> "TELEPHONY"
    AudioDeviceInfo.TYPE_REMOTE_SUBMIX -> "REMOTE_SUBMIX"
    else -> "TYPE_$type"
}

/**
 * Short readable name for a resolved audio [source], for the same diagnostic.
 *
 * A report that Music mode or an external mic did nothing is only actionable
 * if the log says which source was actually chosen.
 */
internal fun audioSourceName(source: Int): String = when (source) {
    AudioSpec.SOURCE_AUTO -> "camera default"
    MediaRecorder.AudioSource.MIC -> "MIC"
    MediaRecorder.AudioSource.VOICE_RECOGNITION -> "VOICE_RECOGNITION"
    MediaRecorder.AudioSource.UNPROCESSED -> "UNPROCESSED"
    else -> "SOURCE_$source"
}
