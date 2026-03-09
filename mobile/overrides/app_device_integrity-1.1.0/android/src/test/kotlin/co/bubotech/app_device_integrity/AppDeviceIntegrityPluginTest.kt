package co.bubotech.app_device_integrity

import kotlin.test.Test

class AppDeviceIntegrityPluginTest {

    @Test
    fun onDetachedFromActivity_doesNotThrowBeforeAttach() {
        val plugin = AppDeviceIntegrityPlugin()

        plugin.onDetachedFromActivity()
    }

    @Test
    fun onDetachedFromActivityForConfigChanges_doesNotThrowBeforeAttach() {
        val plugin = AppDeviceIntegrityPlugin()

        plugin.onDetachedFromActivityForConfigChanges()
    }
}
