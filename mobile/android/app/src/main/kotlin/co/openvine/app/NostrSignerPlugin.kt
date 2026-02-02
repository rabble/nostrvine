// ABOUTME: NIP-55 Android Signer plugin for communication with external signing apps
// ABOUTME: Provides platform channel methods for checking signer availability and launching intents

package co.openvine.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class NostrSignerPlugin(
    private val activity: Activity,
    flutterEngine: FlutterEngine
) : MethodChannel.MethodCallHandler, PluginRegistry.ActivityResultListener {

    companion object {
        private const val CHANNEL = "nostrmoPlugin"
        private const val TAG = "NostrSignerPlugin"
        private const val NOSTRSIGNER_SCHEME = "nostrsigner"
        private const val REQUEST_CODE_SIGNER = 9876
    }

    private val methodChannel: MethodChannel =
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

    private var pendingResult: MethodChannel.Result? = null

    init {
        methodChannel.setMethodCallHandler(this)
        Log.d(TAG, "NostrSignerPlugin initialized")
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }

            "existAndroidNostrSigner" -> {
                val exists = checkSignerExists()
                Log.d(TAG, "existAndroidNostrSigner: $exists")
                result.success(exists)
            }

            "startActivityForResult" -> {
                startActivityForResult(call, result)
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    private fun checkSignerExists(): Boolean {
        return try {
            val intent = Intent(Intent.ACTION_VIEW).apply {
                data = Uri.parse("$NOSTRSIGNER_SCHEME:")
                addCategory(Intent.CATEGORY_BROWSABLE)
            }
            val activities = activity.packageManager.queryIntentActivities(intent, 0)
            activities.isNotEmpty()
        } catch (e: Exception) {
            Log.e(TAG, "Error checking for signer: ${e.message}")
            false
        }
    }

    private fun startActivityForResult(call: MethodCall, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("ALREADY_PENDING", "Another activity result is pending", null)
            return
        }

        try {
            val args = call.arguments as? Map<*, *>
            if (args == null) {
                result.error("INVALID_ARGS", "Arguments must be a map", null)
                return
            }

            val intent = buildIntentFromArgs(args)
            pendingResult = result

            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_CODE_SIGNER)
            Log.d(TAG, "Launched intent for result")
        } catch (e: Exception) {
            Log.e(TAG, "Error starting activity: ${e.message}")
            pendingResult = null
            result.error("LAUNCH_ERROR", e.message, null)
        }
    }

    private fun buildIntentFromArgs(args: Map<*, *>): Intent {
        val intent = Intent()

        // Set action
        (args["action"] as? String)?.let {
            intent.action = it
        }

        // Set data URI
        (args["data"] as? String)?.let {
            intent.data = Uri.parse(it)
        }

        // Set package
        (args["package"] as? String)?.let {
            intent.setPackage(it)
        }

        // Set type
        (args["type"] as? String)?.let {
            intent.type = it
        }

        // Add categories
        @Suppress("UNCHECKED_CAST")
        (args["category"] as? List<String>)?.forEach {
            intent.addCategory(it)
        }

        // Add flags
        @Suppress("UNCHECKED_CAST")
        (args["flag"] as? List<Int>)?.forEach {
            intent.addFlags(it)
        }

        // Add extras with type info
        @Suppress("UNCHECKED_CAST")
        val extras = args["extra"] as? Map<String, Any?>
        @Suppress("UNCHECKED_CAST")
        val typeInfo = args["typeInfo"] as? Map<String, String>

        extras?.forEach { (key, value) ->
            val type = typeInfo?.get(key)
            putExtraWithType(intent, key, value, type)
        }

        return intent
    }

    private fun putExtraWithType(intent: Intent, key: String, value: Any?, type: String?) {
        when (type) {
            "boolean" -> intent.putExtra(key, value as? Boolean ?: false)
            "int" -> intent.putExtra(key, (value as? Number)?.toInt() ?: 0)
            "double" -> intent.putExtra(key, (value as? Number)?.toDouble() ?: 0.0)
            "String" -> intent.putExtra(key, value as? String)
            "boolean[]" -> {
                @Suppress("UNCHECKED_CAST")
                val list = value as? List<Boolean>
                intent.putExtra(key, list?.toBooleanArray())
            }
            "int[]" -> {
                @Suppress("UNCHECKED_CAST")
                val list = value as? List<Number>
                intent.putExtra(key, list?.map { it.toInt() }?.toIntArray())
            }
            "double[]" -> {
                @Suppress("UNCHECKED_CAST")
                val list = value as? List<Number>
                intent.putExtra(key, list?.map { it.toDouble() }?.toDoubleArray())
            }
            "String[]" -> {
                @Suppress("UNCHECKED_CAST")
                val list = value as? List<String>
                intent.putExtra(key, list?.toTypedArray())
            }
            else -> {
                // Fallback: try to infer type
                when (value) {
                    is Boolean -> intent.putExtra(key, value)
                    is Int -> intent.putExtra(key, value)
                    is Long -> intent.putExtra(key, value)
                    is Double -> intent.putExtra(key, value)
                    is String -> intent.putExtra(key, value)
                    else -> Log.w(TAG, "Unknown type for extra '$key': ${value?.javaClass?.name}")
                }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE_SIGNER) {
            return false
        }

        val currentResult = pendingResult
        pendingResult = null

        if (currentResult == null) {
            Log.w(TAG, "Activity result received but no pending result")
            return true
        }

        val resultMap = mutableMapOf<String, Any?>()
        resultMap["resultCode"] = resultCode

        if (data != null) {
            val intentMap = mutableMapOf<String, Any?>()

            data.action?.let { intentMap["action"] = it }
            data.dataString?.let { intentMap["data"] = it }
            data.`package`?.let { intentMap["package"] = it }
            data.type?.let { intentMap["type"] = it }

            // Extract extras
            val extras = data.extras
            if (extras != null) {
                val extrasMap = mutableMapOf<String, Any?>()
                for (key in extras.keySet()) {
                    val value = extras.get(key)
                    // Only include serializable types
                    when (value) {
                        is String, is Boolean, is Int, is Long, is Double, is Float -> {
                            extrasMap[key] = value
                        }
                        is Array<*> -> {
                            @Suppress("UNCHECKED_CAST")
                            if (value.isArrayOf<String>()) {
                                extrasMap[key] = (value as Array<String>).toList()
                            }
                        }
                        else -> {
                            // Try toString for other types
                            value?.let { extrasMap[key] = it.toString() }
                        }
                    }
                }
                if (extrasMap.isNotEmpty()) {
                    intentMap["extras"] = extrasMap
                }
            }

            resultMap["intent"] = intentMap
        }

        Log.d(TAG, "Returning activity result: resultCode=$resultCode")
        currentResult.success(resultMap)
        return true
    }
}
