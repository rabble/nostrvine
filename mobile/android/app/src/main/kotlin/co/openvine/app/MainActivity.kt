package co.openvine.app

import android.net.Uri
import android.os.Build
import android.util.Log
import android.window.OnBackInvokedCallback
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.witness.proofmode.ProofMode
import java.io.File
import zendesk.core.Zendesk
import zendesk.core.Identity
import zendesk.core.AnonymousIdentity
import zendesk.support.Support
import zendesk.support.requestlist.RequestListActivity
import zendesk.support.request.RequestActivity
import zendesk.support.RequestProvider
import zendesk.support.CreateRequest
import zendesk.support.Request
import com.zendesk.service.ZendeskCallback
import com.zendesk.service.ErrorResponse

class MainActivity : FlutterActivity() {
    companion object {
        private const val NAVIGATION_CHANNEL = "org.openvine/navigation"
        private const val NAV_TAG = "OpenVineNavigation"
    }

    private var navigationChannel: MethodChannel? = null
    private var backCallback: OnBackInvokedCallback? = null
    private val PROOFMODE_CHANNEL = "org.openvine/proofmode"
    private val ZENDESK_CHANNEL = "com.openvine/zendesk_support"
    private val PROOFMODE_TAG = "OpenVineProofMode"
    private val ZENDESK_TAG = "OpenVineZendesk"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        try {
            super.configureFlutterEngine(flutterEngine)
        } catch (e: Exception) {
            Log.e(PROOFMODE_TAG, "Exception during FlutterEngine configuration", e)
            Log.e(PROOFMODE_TAG, "Exception message: ${e.message}")
            Log.e(PROOFMODE_TAG, "Exception cause: ${e.cause?.message}")

            // Handle FFmpegKit initialization failure on Android (not needed - using continuous recording)
            // FFmpegKit is only used on iOS/macOS for video processing
            if (e.message?.contains("FFmpegKit") == true || e.cause?.message?.contains("ffmpegkit") == true) {
                Log.w(PROOFMODE_TAG, "FFmpegKit plugin failed to initialize (expected on Android)", e)
                // Continue without FFmpegKit - Android uses camera-based continuous recording
            } else {
                // Re-throw other exceptions
                throw e
            }
        }

        // Set up ProofMode platform channel
        setupProofModeChannel(flutterEngine)

        // Set up Zendesk platform channel
        setupZendeskChannel(flutterEngine)

        // Set up navigation channel for back button handling
        setupNavigationChannel(flutterEngine)
    }

    override fun onBackPressed() {
        Log.d(NAV_TAG, "onBackPressed() called")

        // Notify Flutter about back button press via MethodChannel
        navigationChannel?.invokeMethod("onBackPressed", null, object : MethodChannel.Result {
            override fun success(result: Any?) {
                val handled = result as? Boolean ?: false
                Log.d(NAV_TAG, "Flutter handled back: $handled")

                if (!handled) {
                    // Flutter didn't handle it, use default behavior (exit app)
                    Log.d(NAV_TAG, "Flutter didn't handle back, calling super.onBackPressed()")
                    super@MainActivity.onBackPressed()
                }
            }

            override fun error(error: String, message: String?, details: Any?) {
                Log.e(NAV_TAG, "Error from Flutter: $error - $message")
                // On error, use default behavior
                super@MainActivity.onBackPressed()
            }

            override fun notImplemented() {
                Log.w(NAV_TAG, "Back handling not implemented in Flutter")
                // If not implemented, use default behavior
                super@MainActivity.onBackPressed()
            }
        })
    }

    private fun setupNavigationChannel(flutterEngine: FlutterEngine) {
        navigationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NAVIGATION_CHANNEL)

        // Register OnBackInvokedCallback for Android 13+ (API 33+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            backCallback = OnBackInvokedCallback {
                handleBackPress()
            }
            onBackInvokedDispatcher.registerOnBackInvokedCallback(
                android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT,
                backCallback!!
            )
        }
    }

    private fun handleBackPress() {
        // Notify Flutter about back button press via MethodChannel
        navigationChannel?.invokeMethod("onBackPressed", null, object : MethodChannel.Result {
            override fun success(result: Any?) {
                val handled = result as? Boolean ?: false

                if (!handled) {
                    // Flutter didn't handle it, finish activity (exit app)
                    finish()
                }
            }

            override fun error(error: String, message: String?, details: Any?) {
                // On error, finish activity
                finish()
            }

            override fun notImplemented() {
                // If not implemented, finish activity
                finish()
            }
        })
    }

    override fun onDestroy() {
        super.onDestroy()
        // Unregister callback when activity is destroyed
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU && backCallback != null) {
            onBackInvokedDispatcher.unregisterOnBackInvokedCallback(backCallback!!)
        }
    }

    private fun setupProofModeChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PROOFMODE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "generateProof" -> {
                    val mediaPath = call.argument<String>("mediaPath")
                    if (mediaPath == null) {
                        result.error("INVALID_ARGUMENT", "Media path is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        Log.d(PROOFMODE_TAG, "Generating proof for: $mediaPath")

                        // Convert file path to URI
                        val mediaFile = File(mediaPath)
                        if (!mediaFile.exists()) {
                            result.error("FILE_NOT_FOUND", "Media file does not exist: $mediaPath", null)
                            return@setMethodCallHandler
                        }

                        val mediaUri = Uri.fromFile(mediaFile)

                        // Generate proof using native ProofMode library
                        val proofHash = ProofMode.generateProof(this, mediaUri)

                        if (proofHash.isNullOrEmpty()) {
                            Log.e(PROOFMODE_TAG, "ProofMode did not generate hash")
                            result.error("PROOF_HASH_MISSING", "ProofMode did not generate video hash", null)
                            return@setMethodCallHandler
                        }

                        Log.d(PROOFMODE_TAG, "Proof generated successfully: $proofHash")
                        result.success(proofHash)
                    } catch (e: Exception) {
                        Log.e(PROOFMODE_TAG, "Failed to generate proof", e)
                        result.error("PROOF_GENERATION_FAILED", e.message, null)
                    }
                }

                "getProofDir" -> {
                    val proofHash = call.argument<String>("proofHash")
                    if (proofHash == null) {
                        result.error("INVALID_ARGUMENT", "Proof hash is required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val proofDir = ProofMode.getProofDir(this, proofHash)
                        if (proofDir != null && proofDir.exists()) {
                            result.success(proofDir.absolutePath)
                        } else {
                            result.success(null)
                        }
                    } catch (e: Exception) {
                        Log.e(PROOFMODE_TAG, "Failed to get proof directory", e)
                        result.error("GET_PROOF_DIR_FAILED", e.message, null)
                    }
                }

                "isAvailable" -> {
                    // ProofMode is always available on Android when library is included
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun setupZendeskChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ZENDESK_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val args = call.arguments as? Map<*, *>
                    val appId = args?.get("appId") as? String
                    val clientId = args?.get("clientId") as? String
                    val zendeskUrl = args?.get("zendeskUrl") as? String

                    if (appId == null || clientId == null || zendeskUrl == null) {
                        result.error("INVALID_ARGUMENT", "appId, clientId, and zendeskUrl are required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        Log.d(ZENDESK_TAG, "Initializing Zendesk with URL: $zendeskUrl")

                        // Initialize Zendesk Core SDK
                        Zendesk.INSTANCE.init(this, zendeskUrl, appId, clientId)

                        // Initialize Support SDK
                        Support.INSTANCE.init(Zendesk.INSTANCE)

                        // Set baseline anonymous identity so widget works immediately
                        // Flutter will update with email-based identity when user logs in
                        val identity: Identity = AnonymousIdentity()
                        Zendesk.INSTANCE.setIdentity(identity)

                        Log.d(ZENDESK_TAG, "Zendesk initialized with anonymous identity")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(ZENDESK_TAG, "Failed to initialize Zendesk", e)
                        result.error("INITIALIZATION_FAILED", e.message, null)
                    }
                }

                "showNewTicket" -> {
                    try {
                        // Note: Zendesk Android SDK v5.1.2 does not support pre-filling
                        // subject/tags in RequestActivity. Users must fill these in the UI.
                        // This is a known limitation of the Android SDK vs iOS SDK.
                        Log.d(ZENDESK_TAG, "Showing new ticket screen")

                        // Launch Zendesk request activity
                        RequestActivity.builder()
                            .show(this)

                        Log.d(ZENDESK_TAG, "Ticket screen shown successfully")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(ZENDESK_TAG, "Failed to show ticket screen", e)
                        result.error("SHOW_TICKET_FAILED", e.message, null)
                    }
                }

                "showTicketList" -> {
                    try {
                        Log.d(ZENDESK_TAG, "Showing ticket list screen")

                        // Launch Zendesk request list activity
                        RequestListActivity.builder()
                            .show(this)

                        Log.d(ZENDESK_TAG, "Ticket list shown successfully")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(ZENDESK_TAG, "Failed to show ticket list", e)
                        result.error("SHOW_LIST_FAILED", e.message, null)
                    }
                }

                "setUserIdentity" -> {
                    val args = call.arguments as? Map<*, *>
                    val name = args?.get("name") as? String
                    val email = args?.get("email") as? String

                    if (name == null || email == null) {
                        result.error("INVALID_ARGUMENT", "name and email are required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        Log.d(ZENDESK_TAG, "Setting user identity - name: $name, email: $email")

                        // Create anonymous identity with name and email identifiers
                        val identity: Identity = AnonymousIdentity.Builder()
                            .withNameIdentifier(name)
                            .withEmailIdentifier(email)
                            .build()
                        Zendesk.INSTANCE.setIdentity(identity)

                        Log.d(ZENDESK_TAG, "User identity set successfully")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(ZENDESK_TAG, "Failed to set user identity", e)
                        result.error("SET_IDENTITY_FAILED", e.message, null)
                    }
                }

                "clearUserIdentity" -> {
                    try {
                        Log.d(ZENDESK_TAG, "Clearing user identity")

                        // Reset to plain anonymous identity
                        val identity: Identity = AnonymousIdentity()
                        Zendesk.INSTANCE.setIdentity(identity)

                        Log.d(ZENDESK_TAG, "User identity cleared")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(ZENDESK_TAG, "Failed to clear user identity", e)
                        result.error("CLEAR_IDENTITY_FAILED", e.message, null)
                    }
                }

                "setAnonymousIdentity" -> {
                    try {
                        Log.d(ZENDESK_TAG, "Setting anonymous identity")

                        // Set plain anonymous identity (for non-logged-in users)
                        val identity: Identity = AnonymousIdentity()
                        Zendesk.INSTANCE.setIdentity(identity)

                        Log.d(ZENDESK_TAG, "Anonymous identity set")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(ZENDESK_TAG, "Failed to set anonymous identity", e)
                        result.error("SET_ANONYMOUS_IDENTITY_FAILED", e.message, null)
                    }
                }

                "createTicket" -> {
                    val args = call.arguments as? Map<*, *>
                    val subject = args?.get("subject") as? String
                    val description = args?.get("description") as? String
                    val tags = (args?.get("tags") as? List<*>)?.filterIsInstance<String>() ?: emptyList()

                    if (subject == null || description == null) {
                        result.error("INVALID_ARGUMENT", "subject and description are required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        Log.d(ZENDESK_TAG, "Creating ticket programmatically - subject: $subject")

                        // Get RequestProvider from Support SDK
                        val providerStore = Support.INSTANCE.provider()
                        if (providerStore == null) {
                            result.error("SDK_NOT_INITIALIZED", "Zendesk Support SDK not initialized", null)
                            return@setMethodCallHandler
                        }
                        val provider: RequestProvider = providerStore.requestProvider()
                        val createRequest = CreateRequest()
                        createRequest.subject = subject
                        createRequest.description = description
                        createRequest.tags = tags

                        provider.createRequest(createRequest, object : ZendeskCallback<Request>() {
                            override fun onSuccess(request: Request?) {
                                Log.d(ZENDESK_TAG, "Ticket created successfully - ID: ${request?.id}")
                                result.success(true)
                            }

                            override fun onError(error: ErrorResponse?) {
                                Log.e(ZENDESK_TAG, "Failed to create ticket: ${error?.reason}")
                                result.success(false)
                            }
                        })
                    } catch (e: Exception) {
                        Log.e(ZENDESK_TAG, "Failed to create ticket", e)
                        result.error("CREATE_TICKET_FAILED", e.message, null)
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        Log.d(ZENDESK_TAG, "Zendesk platform channel registered")
    }
}