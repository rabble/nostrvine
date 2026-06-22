package co.openvine.divine_quick_actions

import android.app.Activity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

/*
 * This demonstrates a simple unit test of the Kotlin portion of this plugin's implementation.
 *
 * Once you have built the plugin's example app, you can run these tests from the command
 * line by running `./gradlew testDebugUnitTest` in the `example/android/` directory, or
 * you can run them directly from IDEs that support JUnit such as Android Studio.
 */

internal class DivineQuickActionsPluginTest {
    @Test
    fun onMethodCall_isSupportedWithoutContext_returnsFalse() {
        val plugin = DivineQuickActionsPlugin()

        val call = MethodCall("isSupported", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).success(false)
    }

    @Test
    fun onMethodCall_setActionsWithoutContext_returnsFalse() {
        val plugin = DivineQuickActionsPlugin()

        val call = MethodCall(
            "setActions",
            listOf(
                mapOf(
                    "type" to "record",
                    "title" to "Record"
                )
            )
        )
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(mockResult).success(false)
    }

    @Test
    fun handleLaunchCover_cameraAction_showsCover() {
        val cover = Mockito.mock(CameraLaunchCover::class.java)
        val plugin = DivineQuickActionsPlugin(cover)
        val activity = Mockito.mock(Activity::class.java)

        plugin.handleLaunchCover(mapOf("type" to "camera"), activity)

        Mockito.verify(cover).show(activity)
    }

    @Test
    fun handleLaunchCover_nonCameraAction_doesNotShowCover() {
        val cover = Mockito.mock(CameraLaunchCover::class.java)
        val plugin = DivineQuickActionsPlugin(cover)
        val activity = Mockito.mock(Activity::class.java)

        plugin.handleLaunchCover(mapOf("type" to "notifications"), activity)

        Mockito.verify(cover, Mockito.never()).show(activity)
    }

    @Test
    fun onMethodCall_dismissLaunchCover_dismissesCover() {
        val cover = Mockito.mock(CameraLaunchCover::class.java)
        val plugin = DivineQuickActionsPlugin(cover)

        val call = MethodCall("dismissLaunchCover", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)

        Mockito.verify(cover).dismiss()
        Mockito.verify(mockResult).success(null)
    }
}
