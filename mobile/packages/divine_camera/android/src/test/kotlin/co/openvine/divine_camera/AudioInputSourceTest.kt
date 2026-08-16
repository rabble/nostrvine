package co.openvine.divine_camera

import android.annotation.SuppressLint
import android.media.AudioDeviceInfo
import android.media.MediaRecorder
import androidx.camera.video.AudioSpec
import androidx.camera.video.Recorder
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import kotlin.test.assertEquals

/*
 * Pins the input-device → audio-source mapping used when building the
 * recording Recorder (#6171). CameraX resolves its own default,
 * AudioSpec.SOURCE_AUTO, to MediaRecorder.AudioSource.CAMCORDER, and AOSP's
 * audio policy ranks USB last for CAMCORDER — behind the built-in mic — so an
 * attached USB microphone is never captured from on a phone.
 */
@RunWith(RobolectricTestRunner::class)
internal class AudioInputSourceTest {
    @Test
    fun builtInMicOnly_keepsCameraXDefault() {
        assertEquals(
            AudioSpec.SOURCE_AUTO,
            audioSourceForInputDeviceTypes(intArrayOf(AudioDeviceInfo.TYPE_BUILTIN_MIC))
        )
    }

    @Test
    fun noInputDevices_keepsCameraXDefault() {
        assertEquals(AudioSpec.SOURCE_AUTO, audioSourceForInputDeviceTypes(intArrayOf()))
    }

    @Test
    fun telephonyAndSubmix_areNotTreatedAsExternalMics() {
        assertEquals(
            AudioSpec.SOURCE_AUTO,
            audioSourceForInputDeviceTypes(
                intArrayOf(
                    AudioDeviceInfo.TYPE_BUILTIN_MIC,
                    AudioDeviceInfo.TYPE_TELEPHONY,
                    AudioDeviceInfo.TYPE_REMOTE_SUBMIX
                )
            )
        )
    }

    @Test
    fun usbMicAlongsideBuiltIn_switchesToMic() {
        // The reported case: the built-in mic is always present, so the
        // external device has to win rather than merely be present.
        assertEquals(
            MediaRecorder.AudioSource.MIC,
            audioSourceForInputDeviceTypes(
                intArrayOf(
                    AudioDeviceInfo.TYPE_BUILTIN_MIC,
                    AudioDeviceInfo.TYPE_USB_DEVICE
                )
            )
        )
    }

    @Test
    fun everyExternalMicType_switchesToMic() {
        val externalTypes = mapOf(
            "USB_DEVICE" to AudioDeviceInfo.TYPE_USB_DEVICE,
            "USB_HEADSET" to AudioDeviceInfo.TYPE_USB_HEADSET,
            "USB_ACCESSORY" to AudioDeviceInfo.TYPE_USB_ACCESSORY,
            "WIRED_HEADSET" to AudioDeviceInfo.TYPE_WIRED_HEADSET,
            "BLUETOOTH_SCO" to AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            "BLE_HEADSET" to AudioDeviceInfo.TYPE_BLE_HEADSET
        )
        for ((name, type) in externalTypes) {
            assertEquals(
                MediaRecorder.AudioSource.MIC,
                audioSourceForInputDeviceTypes(
                    intArrayOf(AudioDeviceInfo.TYPE_BUILTIN_MIC, type)
                ),
                "$name should route capture to MIC"
            )
        }
    }

    /*
     * Recorder.Builder.setAudioSource and Recorder.getAudioSource are both
     * @RestrictTo(LIBRARY) — the only lever CameraX offers, since it publishes
     * no way to route capture to a specific AudioDeviceInfo. This asserts the
     * value we set survives into the built Recorder, so a CameraX bump that
     * drops, renames or starts validating the setter fails here rather than
     * silently reverting Android to the built-in mic.
     */
    @SuppressLint("RestrictedApi")
    @Test
    fun recorderRetainsTheConfiguredAudioSource() {
        assertEquals(
            MediaRecorder.AudioSource.MIC,
            Recorder.Builder()
                .setAudioSource(MediaRecorder.AudioSource.MIC)
                .build()
                .audioSource
        )
    }

    @SuppressLint("RestrictedApi")
    @Test
    fun sourceAutoLeavesTheRecorderAtItsUntouchedDefault() {
        // The no-external-mic branch must be indistinguishable from never
        // having called setAudioSource, so devices without an attached mic keep
        // the camera-tuned capture path exactly as it was before this fix.
        assertEquals(
            Recorder.Builder().build().audioSource,
            Recorder.Builder()
                .setAudioSource(AudioSpec.SOURCE_AUTO)
                .build()
                .audioSource
        )
    }
}
