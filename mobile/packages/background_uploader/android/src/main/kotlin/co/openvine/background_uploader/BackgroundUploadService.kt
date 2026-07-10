// ABOUTME: Foreground service that streams a file upload to completion so it
// ABOUTME: keeps running after the app is backgrounded; reports progress back.

package co.openvine.background_uploader

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import java.io.File
import java.io.FileInputStream
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors

class BackgroundUploadService : Service() {
  private val executor = Executors.newCachedThreadPool()
  private var notificationTitle: String = DEFAULT_NOTIFICATION_TITLE

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onCreate() {
    super.onCreate()
    running = true
    createNotificationChannel()
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    try {
      startForegroundCompat()
    } catch (e: Exception) {
      intent?.getStringExtra(EXTRA_TASK_ID)?.let { taskId ->
        postFailure(
          taskId,
          error = e.message ?: e.javaClass.simpleName,
        )
      }
      stopSelf()
      return START_NOT_STICKY
    }

    when (intent?.action) {
      ACTION_ENQUEUE -> handleEnqueue(intent)
      ACTION_CANCEL -> {
        intent.getStringExtra(EXTRA_TASK_ID)?.let { taskId ->
          cancelledTaskIds[taskId] = true
          // Abort a transfer already blocked reading the response so a cancel
          // that lands after the body is fully sent terminates as `cancelled`
          // instead of running to `completed` (matching iOS `task.cancel()`).
          runCatching { activeConnections[taskId]?.disconnect() }
        }
        stopIfIdle()
      }
      ACTION_BEGIN_SESSION ->
        intent.getStringExtra(EXTRA_SESSION_ID)?.let { activeSessions.add(it) }
      ACTION_END_SESSION -> {
        intent.getStringExtra(EXTRA_SESSION_ID)?.let { activeSessions.remove(it) }
        stopIfIdle()
      }
      else -> stopIfIdle()
    }
    return START_NOT_STICKY
  }

  private fun handleEnqueue(intent: Intent) {
    // A malformed intent must not leave the just-started foreground service
    // running with nothing to do, so bail out through stopIfIdle().
    val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: return stopIfIdle()
    val urlString = intent.getStringExtra(EXTRA_URL) ?: return stopIfIdle()
    val filePath = intent.getStringExtra(EXTRA_FILE_PATH) ?: return stopIfIdle()
    val method = intent.getStringExtra(EXTRA_METHOD) ?: "PUT"

    intent.getStringExtra(EXTRA_NOTIFICATION_TITLE)?.let { title ->
      if (title != notificationTitle) {
        notificationTitle = title
        // Refresh the ongoing notification with the caller-supplied title.
        runCatching { startForegroundCompat() }
      }
    }

    @Suppress("UNCHECKED_CAST")
    val headers =
      (intent.getSerializableExtra(EXTRA_HEADERS) as? HashMap<String, String>)
        ?: HashMap()

    // Dedupe: a retry/timeout can re-enqueue the same taskId while the first
    // transfer is still in flight. add() returns false when already present, so
    // skip starting a second parallel upload of the same file. The service
    // stays foregrounded because activeTaskIds is non-empty.
    if (!activeTaskIds.add(taskId)) return
    cancelledTaskIds.remove(taskId)
    executor.execute { runUpload(taskId, urlString, filePath, method, headers) }
  }

  private fun runUpload(
    taskId: String,
    urlString: String,
    filePath: String,
    method: String,
    headers: Map<String, String>,
  ) {
    var connection: HttpURLConnection? = null
    try {
      val file = File(filePath)
      if (!file.exists()) {
        postFailure(taskId, error = "No file at $filePath")
        return
      }

      val length = file.length()
      connection = (URL(urlString).openConnection() as HttpURLConnection).apply {
        requestMethod = method
        doOutput = true
        setFixedLengthStreamingMode(length)
        connectTimeout = CONNECT_TIMEOUT_MS
        readTimeout = READ_TIMEOUT_MS
        headers.forEach { (key, value) -> setRequestProperty(key, value) }
      }
      // Register the connection so ACTION_CANCEL can abort a transfer that is
      // already blocked reading the response (see onStartCommand).
      activeConnections[taskId] = connection

      FileInputStream(file).use { input ->
        connection.outputStream.use { output ->
          val buffer = ByteArray(BUFFER_SIZE)
          var sent = 0L
          // Throttle to one event per whole percent (≤101 per transfer) so the
          // hot write loop doesn't flood the main thread / method channel and
          // the pending-upload store with hundreds of progress updates.
          var lastReportedPercent = -1
          while (true) {
            if (cancelledTaskIds.containsKey(taskId)) {
              postCancelled(taskId)
              return
            }
            val read = input.read(buffer)
            if (read == -1) break
            output.write(buffer, 0, read)
            sent += read
            if (length > 0) {
              val percent = (sent * 100 / length).toInt()
              if (percent != lastReportedPercent) {
                lastReportedPercent = percent
                postProgress(taskId, sent.toDouble() / length)
              }
            }
          }
        }
      }

      // A cancel can land after the last chunk is written but before the
      // response is read; without this re-check the transfer would report
      // `completed` even though the caller asked to cancel.
      if (cancelledTaskIds.containsKey(taskId)) {
        postCancelled(taskId)
        return
      }

      val statusCode = connection.responseCode
      val body = readBody(connection)
      val success = statusCode in 200..299
      postTerminal(
        taskId = taskId,
        status = if (success) "completed" else "failed",
        progress = if (success) 1.0 else 0.0,
        httpStatusCode = statusCode,
        responseBody = body,
      )
    } catch (e: Exception) {
      if (cancelledTaskIds.containsKey(taskId)) {
        postCancelled(taskId)
      } else {
        postFailure(taskId, error = e.message ?: e.javaClass.simpleName)
      }
    } finally {
      connection?.disconnect()
      activeConnections.remove(taskId)
      activeTaskIds.remove(taskId)
      cancelledTaskIds.remove(taskId)
      stopIfIdle()
    }
  }

  private fun readBody(connection: HttpURLConnection): String? {
    val stream = runCatching { connection.inputStream }.getOrNull()
      ?: connection.errorStream
      ?: return null
    return stream.use { it.readBytes().toString(Charsets.UTF_8) }
  }

  private fun postProgress(taskId: String, progress: Double) {
    BackgroundUploaderPlugin.postEvent(
      mapOf(
        "taskId" to taskId,
        "status" to "running",
        "progress" to progress.coerceIn(0.0, 1.0),
      ),
    )
  }

  private fun postTerminal(
    taskId: String,
    status: String,
    progress: Double,
    httpStatusCode: Int?,
    responseBody: String?,
  ) {
    BackgroundUploaderPlugin.postEvent(
      mapOf(
        "taskId" to taskId,
        "status" to status,
        "progress" to progress,
        "httpStatusCode" to httpStatusCode,
        "responseBody" to responseBody,
      ),
    )
  }

  private fun postFailure(taskId: String, error: String) {
    BackgroundUploaderPlugin.postEvent(
      mapOf(
        "taskId" to taskId,
        "status" to "failed",
        "progress" to 0.0,
        "error" to error,
      ),
    )
  }

  private fun postCancelled(taskId: String) {
    BackgroundUploaderPlugin.postEvent(
      mapOf("taskId" to taskId, "status" to "cancelled", "progress" to 0.0),
    )
  }

  // On Android 15+ (API 35) a `dataSync` foreground service that exhausts its
  // cumulative daily runtime budget receives onTimeout; the default no-op never
  // stops the service, so the platform raises a foreground-service-timeout
  // crash. Comply by aborting any in-flight transfers and stopping.
  override fun onTimeout(startId: Int, fgsType: Int) {
    activeConnections.values.forEach { runCatching { it.disconnect() } }
    activeConnections.clear()
    activeTaskIds.clear()
    cancelledTaskIds.clear()
    activeSessions.clear()
    stopIfIdle()
  }

  private fun stopIfIdle() {
    if (activeTaskIds.isEmpty() && activeSessions.isEmpty()) {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
        stopForeground(STOP_FOREGROUND_REMOVE)
      } else {
        @Suppress("DEPRECATION")
        stopForeground(true)
      }
      stopSelf()
    }
  }

  private fun startForegroundCompat() {
    val notification = buildNotification()
    if (BackgroundUploaderPlugin.supportsTypedForegroundService()) {
      startForeground(
        NOTIFICATION_ID,
        notification,
        ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
      )
    } else {
      startForeground(NOTIFICATION_ID, notification)
    }
  }

  private fun buildNotification(): Notification {
    val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      Notification.Builder(this, CHANNEL_ID)
    } else {
      @Suppress("DEPRECATION")
      Notification.Builder(this)
    }
    builder
      .setContentTitle(notificationTitle)
      .setSmallIcon(android.R.drawable.stat_sys_upload)
      .setOngoing(true)
    // Show the upload notification immediately instead of letting the system
    // defer it up to ~10s (Android 12+ FGS notification deferral), which would
    // otherwise hide it for most of a short upload.
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
      builder.setForegroundServiceBehavior(Notification.FOREGROUND_SERVICE_IMMEDIATE)
    }
    return builder.build()
  }

  private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    if (manager.getNotificationChannel(CHANNEL_ID) != null) return
    manager.createNotificationChannel(
      NotificationChannel(
        CHANNEL_ID,
        "Background uploads",
        NotificationManager.IMPORTANCE_LOW,
      ),
    )
  }

  override fun onDestroy() {
    running = false
    executor.shutdown()
    // These sets are process-static, so a destroyed service would otherwise
    // leak stale entries into the next service instance: a leftover
    // activeSessions/activeTaskIds entry keeps stopIfIdle() from ever firing
    // (permanent foreground notification), and a leftover activeTaskIds entry
    // makes a later re-enqueue of the same taskId a silent no-op. Reset them so
    // each fresh service starts from a clean slate.
    activeTaskIds.clear()
    cancelledTaskIds.clear()
    activeConnections.clear()
    activeSessions.clear()
    super.onDestroy()
  }

  companion object {
    const val ACTION_ENQUEUE = "co.openvine.background_uploader.ENQUEUE"
    const val ACTION_CANCEL = "co.openvine.background_uploader.CANCEL"
    const val ACTION_BEGIN_SESSION = "co.openvine.background_uploader.BEGIN_SESSION"
    const val ACTION_END_SESSION = "co.openvine.background_uploader.END_SESSION"
    const val EXTRA_TASK_ID = "taskId"
    const val EXTRA_URL = "url"
    const val EXTRA_FILE_PATH = "filePath"
    const val EXTRA_METHOD = "method"
    const val EXTRA_HEADERS = "headers"
    const val EXTRA_SESSION_ID = "sessionId"
    const val EXTRA_NOTIFICATION_TITLE = "notificationTitle"

    private const val CHANNEL_ID = "background_upload"
    private const val NOTIFICATION_ID = 0x42
    private const val BUFFER_SIZE = 256 * 1024
    private const val CONNECT_TIMEOUT_MS = 30_000
    private const val READ_TIMEOUT_MS = 600_000
    private const val DEFAULT_NOTIFICATION_TITLE = "Uploading"

    /// Whether a service instance is currently alive. The plugin checks this so
    /// control commands (cancel / end-session) are only delivered to a live
    /// service via `startService`, never by starting a foreground service from
    /// the background. Set in [onCreate] / cleared in [onDestroy].
    @Volatile
    private var running = false

    fun isRunning(): Boolean = running

    private val activeTaskIds = ConcurrentHashMap.newKeySet<String>()
    private val cancelledTaskIds = ConcurrentHashMap<String, Boolean>()

    /// Live connections keyed by task, so an ACTION_CANCEL delivered while a
    /// transfer is blocked reading the response can `disconnect()` to abort it.
    private val activeConnections = ConcurrentHashMap<String, HttpURLConnection>()

    /// Foreground sessions that keep the service alive beyond any in-flight
    /// upload, so the process stays foregrounded (network usable) across the
    /// caller's follow-up work — e.g. signing and broadcasting an event after a
    /// background upload completes. The service stops only when both the
    /// upload set and this set are empty.
    private val activeSessions = ConcurrentHashMap.newKeySet<String>()

    fun activeTaskIds(): List<String> = activeTaskIds.toList()
  }
}
