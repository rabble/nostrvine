// ABOUTME: Picks the recording audio source from the connected input devices
// ABOUTME: CAMCORDER never selects an attached USB mic, so external inputs use MIC

package co.openvine.divine_camera

import android.media.AudioDeviceInfo
import android.media.MediaRecorder
import androidx.camera.video.AudioSpec

/**
 * Input device types that mean the user deliberately plugged in a microphone.
 *
 * Only devices reported by `AudioManager.GET_DEVICES_INPUTS` are ever tested
 * against this set, so every entry is a real capture device.
 *
 * Bluetooth is deliberately absent. Under MIC, AOSP reaches a Bluetooth input
 * only via LE Audio (`BLUETOOTH_BLE`, ranked below USB), or via SCO when
 * Bluetooth is already the communication device — which during recording it is
 * not. So listing it here would either change nothing (SCO) or quietly promote
 * a headset the user wore for listening into the recording microphone (LE
 * Audio). Wearing headphones is not asking to record through them.
 */
private val EXTERNAL_MIC_TYPES = setOf(
    AudioDeviceInfo.TYPE_USB_DEVICE,
    AudioDeviceInfo.TYPE_USB_HEADSET,
    AudioDeviceInfo.TYPE_USB_ACCESSORY,
    AudioDeviceInfo.TYPE_WIRED_HEADSET
)

/**
 * The audio source a new Recorder should capture from, given the connected
 * input device [types].
 *
 * CameraX leaves the source at [AudioSpec.SOURCE_AUTO], which resolves to
 * `MediaRecorder.AudioSource.CAMCORDER`. AOSP's audio policy ranks input
 * devices per source, and for CAMCORDER the order is back mic, built-in mic,
 * then USB — USB is reachable only on a device with no built-in mic, so on a
 * phone an attached USB microphone is never selected (#6171). MIC ranks wired
 * and USB ahead of the built-in mic, which is what someone who just plugged in
 * a microphone expects.
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
