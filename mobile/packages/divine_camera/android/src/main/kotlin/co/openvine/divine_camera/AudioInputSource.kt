// ABOUTME: Picks the recording audio source from the connected input devices
// ABOUTME: CAMCORDER ranks USB below the built-in mic, so an attached USB mic uses MIC

package co.openvine.divine_camera

import android.media.AudioDeviceInfo
import android.media.MediaRecorder
import androidx.camera.video.AudioSpec

/**
 * Input device types that mean the user attached something to record with.
 *
 * Only devices reported by `AudioManager.GET_DEVICES_INPUTS` are ever tested
 * against this set, so every entry is a real capture device.
 *
 * The set is deliberately one entry wide. Android reports an input-only USB
 * audio device as `TYPE_USB_DEVICE`, which is what a microphone or a wireless
 * receiver is; a device that also has an output leg — headphones with a mic,
 * over USB (`TYPE_USB_HEADSET`), over the jack (`TYPE_WIRED_HEADSET`) or over
 * Bluetooth — is something the user put on to *listen*. Routing capture to
 * those would silently turn monitoring earbuds into the recording microphone,
 * which is the surprise this fix is supposed to avoid, not create. Wearing
 * headphones is not asking to record through them, and the cable does not
 * change that.
 *
 * If a report ever shows a real external microphone enumerating as
 * `TYPE_USB_HEADSET` — a combo device exposing a monitoring output — that
 * type can be added back on the evidence. The diagnostic line in
 * `CameraController.resolveAudioSource` names the types it saw, so such a
 * report will say so.
 */
private val EXTERNAL_MIC_TYPES = setOf(
    AudioDeviceInfo.TYPE_USB_DEVICE
)

/**
 * The audio source a new Recorder should capture from, given the connected
 * input device [types].
 *
 * CameraX leaves the source at [AudioSpec.SOURCE_AUTO], which resolves to
 * `MediaRecorder.AudioSource.CAMCORDER`. AOSP's audio policy ranks input
 * devices per source, and for CAMCORDER the order is back mic, built-in mic,
 * then USB — USB is reachable only on a device with no built-in mic, so on a
 * phone an attached USB microphone is never selected (#6171). MIC ranks USB
 * ahead of the built-in mic, which is what someone who just plugged in a
 * microphone expects.
 *
 * Returns [AudioSpec.SOURCE_AUTO] when nothing is attached, leaving the
 * camera-tuned default untouched for everyone else.
 */
internal fun audioSourceForInputDeviceTypes(types: IntArray): Int =
    if (types.any { it in EXTERNAL_MIC_TYPES }) {
        MediaRecorder.AudioSource.MIC
    } else {
        AudioSpec.SOURCE_AUTO
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
