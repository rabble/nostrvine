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
 *
 * The 3.5mm jack is left out for the opposite reason. `TYPE_WIRED_HEADSET`
 * is overwhelmingly earbuds, CAMCORDER does not select it today, and adding
 * it would change recording for people who plugged in only to listen.
 * Bluetooth is out for the same reason — see below.
 */
private val EXTERNAL_MIC_TYPES = setOf(
    AudioDeviceInfo.TYPE_USB_DEVICE,
    AudioDeviceInfo.TYPE_USB_HEADSET
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
