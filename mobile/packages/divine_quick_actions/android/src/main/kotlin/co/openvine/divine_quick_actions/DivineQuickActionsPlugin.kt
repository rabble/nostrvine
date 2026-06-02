package co.openvine.divine_quick_actions

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon
import android.os.Build
import android.os.Bundle
import android.os.PersistableBundle
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry

/** DivineQuickActionsPlugin */
class DivineQuickActionsPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    PluginRegistry.NewIntentListener {
    // The MethodChannel that will the communication between Flutter and native Android
    //
    // This local reference serves to register the plugin with the Flutter Engine and unregister it
    // when the Flutter Engine is detached from the Activity
    private lateinit var channel: MethodChannel
    private var applicationContext: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingLaunchAction: Map<String, Any>? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "divine_quick_actions")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: Result
    ) {
        when (call.method) {
            "isSupported" -> result.success(isSupported())
            "setActions" -> setActions(call, result)
            "getActions" -> result.success(getActions())
            "clearActions" -> result.success(clearActions())
            "consumeLaunchAction" -> {
                result.success(pendingLaunchAction)
                pendingLaunchAction = null
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        applicationContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attachActivity(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detachActivity()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attachActivity(binding)
    }

    override fun onDetachedFromActivity() {
        detachActivity()
    }

    override fun onNewIntent(intent: Intent): Boolean {
        val action = actionFromIntent(intent) ?: return false
        clearShortcutIntent(intent)
        activity?.intent = intent
        channel.invokeMethod("onQuickAction", action)
        return true
    }

    private fun attachActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        activity = binding.activity
        binding.addOnNewIntentListener(this)
        val launchAction = actionFromIntent(binding.activity.intent)
        if (launchAction != null) {
            pendingLaunchAction = launchAction
            clearShortcutIntent(binding.activity.intent)
        }
    }

    private fun detachActivity() {
        activityBinding?.removeOnNewIntentListener(this)
        activityBinding = null
        activity = null
    }

    private fun setActions(call: MethodCall, result: Result) {
        val actions = readActions(call.arguments)
        if (actions == null) {
            result.error(
                "INVALID_ARGUMENTS",
                "setActions expects a list of quick action maps.",
                null
            )
            return
        }

        result.success(setShortcutActions(actions))
    }

    private fun isSupported(): Boolean {
        return applicationContext != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1
    }

    private fun setShortcutActions(actions: List<Map<*, *>>): Boolean {
        val context = applicationContext ?: return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return false

        val manager = context.getSystemService(ShortcutManager::class.java) ?: return false
        val shortcuts = actions.mapIndexed { index, action ->
            buildShortcutInfo(context, action, index) ?: return false
        }

        return runCatching {
            manager.setDynamicShortcuts(shortcuts)
        }.getOrDefault(false)
    }

    private fun getActions(): List<Map<String, Any?>> {
        val context = applicationContext ?: return emptyList()
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return emptyList()

        val manager = context.getSystemService(ShortcutManager::class.java) ?: return emptyList()
        return manager.dynamicShortcuts.map { shortcut ->
            mapOf(
                "type" to shortcut.id,
                "title" to shortcut.shortLabel.toString(),
                "subtitle" to shortcut.longLabel?.toString(),
                "rank" to shortcut.rank,
                "payload" to payloadFromPersistableBundle(shortcut.extras)
            )
        }
    }

    private fun clearActions(): Boolean {
        val context = applicationContext ?: return false
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return false

        val manager = context.getSystemService(ShortcutManager::class.java) ?: return false
        manager.removeAllDynamicShortcuts()
        return true
    }

    private fun buildShortcutInfo(
        context: Context,
        action: Map<*, *>,
        fallbackRank: Int
    ): ShortcutInfo? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N_MR1) return null

        val type = action["type"] as? String ?: return null
        val title = action["title"] as? String ?: return null
        if (type.isBlank() || title.isBlank()) return null

        val intent = buildLaunchIntent(context, type, payloadFromAction(action)) ?: return null
        val builder = ShortcutInfo.Builder(context, type)
            .setShortLabel(title)
            .setIntent(intent)
            .setRank(action["rank"] as? Int ?: fallbackRank)
            .setExtras(persistablePayloadFromAction(action))

        (action["subtitle"] as? String)?.takeIf { it.isNotBlank() }?.let {
            builder.setLongLabel(it)
        }

        (action["androidIconName"] as? String)?.takeIf { it.isNotBlank() }?.let {
            findIcon(context, it)?.also(builder::setIcon)
        }

        return builder.build()
    }

    private fun buildLaunchIntent(
        context: Context,
        type: String,
        payload: Map<String, String>
    ): Intent? {
        val component = activity?.componentName ?: findLaunchComponent(context) ?: return null
        val payloadBundle = Bundle()
        payload.forEach { (key, value) -> payloadBundle.putString(key, value) }

        return Intent(ACTION_QUICK_ACTION)
            .setComponent(component)
            .putExtra(EXTRA_ACTION_TYPE, type)
            .putExtra(EXTRA_ACTION_PAYLOAD, payloadBundle)
            .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
    }

    private fun findLaunchComponent(context: Context): ComponentName? {
        return context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.component
    }

    private fun findIcon(context: Context, iconName: String): Icon? {
        val resources = context.resources
        val packageName = context.packageName
        val cleanName = iconName
            .removePrefix("@drawable/")
            .removePrefix("@mipmap/")
        val resourceId = listOf("drawable", "mipmap")
            .firstNotNullOfOrNull { type ->
                resources.getIdentifier(cleanName, type, packageName)
                    .takeIf { it != 0 }
            } ?: return null

        return Icon.createWithResource(context, resourceId)
    }

    private fun actionFromIntent(intent: Intent?): Map<String, Any>? {
        if (intent?.action != ACTION_QUICK_ACTION) return null
        val type = intent.getStringExtra(EXTRA_ACTION_TYPE) ?: return null
        val payload = bundleToPayload(intent.getBundleExtra(EXTRA_ACTION_PAYLOAD))

        return mapOf(
            "type" to type,
            "payload" to payload
        )
    }

    private fun clearShortcutIntent(intent: Intent) {
        if (intent.action != ACTION_QUICK_ACTION) return
        intent.action = Intent.ACTION_MAIN
        intent.removeExtra(EXTRA_ACTION_TYPE)
        intent.removeExtra(EXTRA_ACTION_PAYLOAD)
    }

    private fun readActions(arguments: Any?): List<Map<*, *>>? {
        val rawActions = arguments as? List<*> ?: return null
        return rawActions.map { action -> action as? Map<*, *> ?: return null }
    }

    private fun payloadFromAction(action: Map<*, *>): Map<String, String> {
        val payload = action["payload"] as? Map<*, *> ?: return emptyMap()
        return payload.mapNotNull { entry ->
            val key = entry.key as? String
            val value = entry.value as? String
            if (key == null || value == null) null else key to value
        }.toMap()
    }

    private fun persistablePayloadFromAction(action: Map<*, *>): PersistableBundle {
        val bundle = PersistableBundle()
        payloadFromAction(action).forEach { (key, value) -> bundle.putString(key, value) }
        return bundle
    }

    private fun payloadFromPersistableBundle(bundle: PersistableBundle?): Map<String, String> {
        if (bundle == null) return emptyMap()
        return bundle.keySet().mapNotNull { key ->
            bundle.getString(key)?.let { value -> key to value }
        }.toMap()
    }

    private fun bundleToPayload(bundle: Bundle?): Map<String, String> {
        if (bundle == null) return emptyMap()
        return bundle.keySet().mapNotNull { key ->
            bundle.getString(key)?.let { value -> key to value }
        }.toMap()
    }

    companion object {
        private const val ACTION_QUICK_ACTION = "co.openvine.divine_quick_actions.ACTION_QUICK_ACTION"
        private const val EXTRA_ACTION_TYPE = "co.openvine.divine_quick_actions.extra.ACTION_TYPE"
        private const val EXTRA_ACTION_PAYLOAD = "co.openvine.divine_quick_actions.extra.ACTION_PAYLOAD"
    }
}
