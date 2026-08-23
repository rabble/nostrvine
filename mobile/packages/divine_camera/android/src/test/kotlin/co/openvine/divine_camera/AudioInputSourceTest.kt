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
    fun everyUsbInputType_switchesToMic() {
        // A mic or wireless receiver with a monitoring jack declares an output
        // terminal, and AOSP's hasMic() && hasSpeaker() rule scores that at the
        // full 0.75 headset trigger — so it arrives as USB_HEADSET rather than
        // USB_DEVICE. Excluding that type would drop most real external mics.
        val usbTypes = mapOf(
            "USB_DEVICE" to AudioDeviceInfo.TYPE_USB_DEVICE,
            "USB_HEADSET" to AudioDeviceInfo.TYPE_USB_HEADSET
        )
        for ((name, type) in usbTypes) {
            assertEquals(
                MediaRecorder.AudioSource.MIC,
                audioSourceForInputDeviceTypes(
                    intArrayOf(AudioDeviceInfo.TYPE_BUILTIN_MIC, type)
                ),
                "$name should route capture to MIC"
            )
        }
    }

    @Test
    fun wiredHeadset_doesNotBecomeTheRecordingMic() {
        // The jack is overwhelmingly earbuds and CAMCORDER does not select it
        // today, so plugging in to listen must not move the recording onto the
        // earbud mic. Same rule as the Bluetooth cases below, over a cable.
        assertEquals(
            AudioSpec.SOURCE_AUTO,
            audioSourceForInputDeviceTypes(
                intArrayOf(
                    AudioDeviceInfo.TYPE_BUILTIN_MIC,
                    AudioDeviceInfo.TYPE_WIRED_HEADSET
                )
            )
        )
    }

    @Test
    fun wiredHeadsetAlongsideUsb_keepsCameraXDefault() {
        // MIC ranks a wired headset ahead of USB. Switching merely because USB
        // is also attached would therefore record from the earbud microphone,
        // not from the USB device that triggered the switch.
        assertEquals(
            AudioSpec.SOURCE_AUTO,
            audioSourceForInputDeviceTypes(
                intArrayOf(
                    AudioDeviceInfo.TYPE_BUILTIN_MIC,
                    AudioDeviceInfo.TYPE_WIRED_HEADSET,
                    AudioDeviceInfo.TYPE_USB_DEVICE
                )
            )
        )
    }

    @Test
    fun usbAccessory_keepsCameraXDefault() {
        // AOSP's MIC and CAMCORDER policies do not select USB accessory inputs,
        // so switching source for this type would only leave the camera-tuned
        // path without making the accessory the capture device.
        assertEquals(
            AudioSpec.SOURCE_AUTO,
            audioSourceForInputDeviceTypes(
                intArrayOf(
                    AudioDeviceInfo.TYPE_BUILTIN_MIC,
                    AudioDeviceInfo.TYPE_USB_ACCESSORY
                )
            )
        )
    }

    @Test
    fun bluetoothAlone_doesNotBecomeTheRecordingMic() {
        // Wearing a headset to listen is not a request to record through it.
        // Under MIC, AOSP reaches Bluetooth only via LE Audio (ranked below
        // USB) or via SCO once Bluetooth is the communication device, which it
        // is not while recording — so switching would either change nothing or
        // silently hand the recording to the user's earbuds.
        val bluetoothTypes = mapOf(
            "BLUETOOTH_SCO" to AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
            "BLE_HEADSET" to AudioDeviceInfo.TYPE_BLE_HEADSET
        )
        for ((name, type) in bluetoothTypes) {
            assertEquals(
                AudioSpec.SOURCE_AUTO,
                audioSourceForInputDeviceTypes(
                    intArrayOf(AudioDeviceInfo.TYPE_BUILTIN_MIC, type)
                ),
                "$name alone should leave the camera-tuned default in place"
            )
        }
    }

    @Test
    fun bluetoothAlongsideAPluggedInMic_stillSwitches() {
        // Earbuds on, external mic in front of you. The switch still happens,
        // and AOSP ranks USB above LE Audio, so the attached mic wins.
        assertEquals(
            MediaRecorder.AudioSource.MIC,
            audioSourceForInputDeviceTypes(
                intArrayOf(
                    AudioDeviceInfo.TYPE_BUILTIN_MIC,
                    AudioDeviceInfo.TYPE_BLE_HEADSET,
                    AudioDeviceInfo.TYPE_USB_DEVICE
                )
            )
        )
    }

    @Test
    fun musicMode_capturesWithoutProcessingWhereSupported() {
        // The whole point of the preference: UNPROCESSED is the source Android
        // documents for capture with no AGC and no noise suppression.
        assertEquals(
            MediaRecorder.AudioSource.UNPROCESSED,
            audioSourceForInputDeviceTypes(
                intArrayOf(AudioDeviceInfo.TYPE_BUILTIN_MIC),
                preferUnprocessedAudio = true,
                unprocessedSourceSupported = true
            )
        )
    }

    @Test
    fun musicMode_fallsBackToVoiceRecognitionWhereUnprocessedIsUnsupported() {
        // Not every device supports UNPROCESSED. VOICE_RECOGNITION is
        // Android's own documented fallback, and drops AGC and noise
        // suppression — less than UNPROCESSED promises, more than doing
        // nothing, which is what Android did before #8079.
        assertEquals(
            MediaRecorder.AudioSource.VOICE_RECOGNITION,
            audioSourceForInputDeviceTypes(
                intArrayOf(AudioDeviceInfo.TYPE_BUILTIN_MIC),
                preferUnprocessedAudio = true,
                unprocessedSourceSupported = false
            )
        )
    }

    @Test
    fun musicMode_alongsideAUsbMicKeepsBoth() {
        // A musician with an external mic wants the mic AND the processing
        // gone. AOSP hands MIC, VOICE_RECOGNITION and UNPROCESSED the same
        // device list, so moving to UNPROCESSED for the processing does not
        // cost the USB device that #6171 was about.
        assertEquals(
            MediaRecorder.AudioSource.UNPROCESSED,
            audioSourceForInputDeviceTypes(
                intArrayOf(
                    AudioDeviceInfo.TYPE_BUILTIN_MIC,
                    AudioDeviceInfo.TYPE_USB_DEVICE
                ),
                preferUnprocessedAudio = true,
                unprocessedSourceSupported = true
            )
        )
    }

    @Test
    fun musicMode_withAWiredHeadsetKeepsCameraXDefault() {
        // A wired headset outranks everything under the unprocessed sources
        // just as it does under MIC, and CAMCORDER will not route to it at
        // all — so honouring Music mode here would move the recording onto
        // the earbud mic. Giving up on the processing is the smaller loss.
        assertEquals(
            AudioSpec.SOURCE_AUTO,
            audioSourceForInputDeviceTypes(
                intArrayOf(
                    AudioDeviceInfo.TYPE_BUILTIN_MIC,
                    AudioDeviceInfo.TYPE_WIRED_HEADSET
                ),
                preferUnprocessedAudio = true,
                unprocessedSourceSupported = true
            )
        )
    }

    @Test
    fun musicMode_withBluetoothEarbudsKeepsCameraXDefault() {
        // Same rule over the air. BLUETOOTH_BLE sits above the built-in mic
        // in the shared ordering but is absent from CAMCORDER's, so a switch
        // made purely for the processing would silently hand the recording to
        // the user's earbuds. That is the trade #7652 already refused.
        assertEquals(
            AudioSpec.SOURCE_AUTO,
            audioSourceForInputDeviceTypes(
                intArrayOf(
                    AudioDeviceInfo.TYPE_BUILTIN_MIC,
                    AudioDeviceInfo.TYPE_BLE_HEADSET
                ),
                preferUnprocessedAudio = true,
                unprocessedSourceSupported = true
            )
        )
    }

    @Test
    fun musicMode_withEarbudsAndAPluggedInMicStillSwitches() {
        // Monitoring on earbuds while an external mic records is the setup
        // Music mode exists for. USB outranks BLUETOOTH_BLE, so the mic wins
        // the device race and the switch is safe to make.
        assertEquals(
            MediaRecorder.AudioSource.UNPROCESSED,
            audioSourceForInputDeviceTypes(
                intArrayOf(
                    AudioDeviceInfo.TYPE_BUILTIN_MIC,
                    AudioDeviceInfo.TYPE_BLE_HEADSET,
                    AudioDeviceInfo.TYPE_USB_DEVICE
                ),
                preferUnprocessedAudio = true,
                unprocessedSourceSupported = true
            )
        )
    }

    @Test
    fun musicMode_offLeavesTheSupportPropertyIrrelevant() {
        // A device that supports UNPROCESSED must not drift off the
        // camera-tuned path for users who never asked for Music mode.
        assertEquals(
            AudioSpec.SOURCE_AUTO,
            audioSourceForInputDeviceTypes(
                intArrayOf(AudioDeviceInfo.TYPE_BUILTIN_MIC),
                preferUnprocessedAudio = false,
                unprocessedSourceSupported = true
            )
        )
        assertEquals(
            MediaRecorder.AudioSource.MIC,
            audioSourceForInputDeviceTypes(
                intArrayOf(
                    AudioDeviceInfo.TYPE_BUILTIN_MIC,
                    AudioDeviceInfo.TYPE_USB_DEVICE
                ),
                preferUnprocessedAudio = false,
                unprocessedSourceSupported = true
            )
        )
    }

    @Test
    fun musicMode_withNoReportedInputsStillSwitches() {
        // Music mode is a request about processing, not about devices, and an
        // empty input list is not evidence of earbuds. Nothing is captured
        // either way here, so the honest reading is to honour the setting.
        assertEquals(
            MediaRecorder.AudioSource.UNPROCESSED,
            audioSourceForInputDeviceTypes(
                intArrayOf(),
                preferUnprocessedAudio = true,
                unprocessedSourceSupported = true
            )
        )
    }

    @Test
    fun sourceNames_stayReadableAndKeepUnmappedSourcesVisible() {
        // These land in bug reports next to the input list; "Music mode did
        // nothing" is only diagnosable if the chosen source is named.
        assertEquals("camera default", audioSourceName(AudioSpec.SOURCE_AUTO))
        assertEquals("MIC", audioSourceName(MediaRecorder.AudioSource.MIC))
        assertEquals(
            "UNPROCESSED",
            audioSourceName(MediaRecorder.AudioSource.UNPROCESSED)
        )
        assertEquals(
            "VOICE_RECOGNITION",
            audioSourceName(MediaRecorder.AudioSource.VOICE_RECOGNITION)
        )
        assertEquals("SOURCE_9999", audioSourceName(9999))
    }

    @Test
    fun inputTypeNames_stayReadableAndKeepUnmappedTypesVisible() {
        // The names land in user bug reports, and an unmapped type is the case
        // worth reading: a device that calls its external mic something we do
        // not route on has to show up as a number rather than not at all.
        assertEquals("USB_DEVICE", audioInputTypeName(AudioDeviceInfo.TYPE_USB_DEVICE))
        assertEquals("BUILTIN_MIC", audioInputTypeName(AudioDeviceInfo.TYPE_BUILTIN_MIC))
        assertEquals("TYPE_9999", audioInputTypeName(9999))
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
    fun recorderRetainsEveryAudioSourceWeCanResolve() {
        // Every one of these is outside AudioSpec's declared domain
        // (SOURCE_AUTO and SOURCE_CAMCORDER), so all three depend on the
        // setter passing the value through unvalidated.
        val sources = mapOf(
            "MIC" to MediaRecorder.AudioSource.MIC,
            "VOICE_RECOGNITION" to MediaRecorder.AudioSource.VOICE_RECOGNITION,
            "UNPROCESSED" to MediaRecorder.AudioSource.UNPROCESSED
        )
        for ((name, source) in sources) {
            assertEquals(
                source,
                Recorder.Builder()
                    .setAudioSource(source)
                    .build()
                    .audioSource,
                "$name should survive into the built Recorder"
            )
        }
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
