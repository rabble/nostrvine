package co.openvine.divine_quick_actions

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle

internal object QuickActionContract {
    const val ACTION_QUICK_ACTION = "co.openvine.divine_quick_actions.ACTION_QUICK_ACTION"
    const val EXTRA_ACTION_TYPE = "co.openvine.divine_quick_actions.extra.ACTION_TYPE"
    const val EXTRA_ACTION_PAYLOAD = "co.openvine.divine_quick_actions.extra.ACTION_PAYLOAD"
    const val TYPE_CAMERA = "camera"

    fun buildLaunchIntent(
        context: Context,
        type: String,
        payload: Map<String, String> = emptyMap()
    ): Intent? {
        val component = findLaunchComponent(context) ?: return null
        return buildLaunchIntent(component, type, payload)
    }

    fun buildLaunchIntent(
        component: ComponentName,
        type: String,
        payload: Map<String, String> = emptyMap()
    ): Intent {
        val payloadBundle = Bundle()
        payload.forEach { (key, value) -> payloadBundle.putString(key, value) }

        return Intent(ACTION_QUICK_ACTION)
            .setComponent(component)
            .putExtra(EXTRA_ACTION_TYPE, type)
            .putExtra(EXTRA_ACTION_PAYLOAD, payloadBundle)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
    }

    fun findLaunchComponent(context: Context): ComponentName? {
        return context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.component
    }

    fun actionFromIntent(intent: Intent?): Map<String, Any>? {
        if (intent?.action != ACTION_QUICK_ACTION) return null
        val type = intent.getStringExtra(EXTRA_ACTION_TYPE) ?: return null
        val payload = bundleToPayload(intent.getBundleExtra(EXTRA_ACTION_PAYLOAD))

        return mapOf(
            "type" to type,
            "payload" to payload
        )
    }

    fun clearShortcutIntent(intent: Intent) {
        if (intent.action != ACTION_QUICK_ACTION) return
        intent.action = Intent.ACTION_MAIN
        intent.removeExtra(EXTRA_ACTION_TYPE)
        intent.removeExtra(EXTRA_ACTION_PAYLOAD)
    }

    private fun bundleToPayload(bundle: Bundle?): Map<String, String> {
        if (bundle == null) return emptyMap()
        return bundle.keySet().mapNotNull { key ->
            bundle.getString(key)?.let { value -> key to value }
        }.toMap()
    }
}
