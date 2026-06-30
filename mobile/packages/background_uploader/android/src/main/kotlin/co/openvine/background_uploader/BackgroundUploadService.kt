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

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onCreate() {
    super.onCreate()
    createNotificationChannel()
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    startForegroundCompat()

    when (intent?.action) {
      ACTION_ENQUEUE -> handleEnqueue(intent)
      ACTION_CANCEL -> {
        intent.getStringExtra(EXTRA_TASK_ID)?.let { cancelledTaskIds[it] = true }
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
    val taskId = intent.getStringExtra(EXTRA_TASK_ID) ?: return
    val urlString = intent.getStringExtra(EXTRA_URL) ?: return
    val filePath = intent.getStringExtra(EXTRA_FILE_PATH) ?: return
    val method = intent.getStringExtra(EXTRA_METHOD) ?: "PUT"

    @Suppress("UNCHECKED_CAST")
    val headers =
      (intent.getSerializableExtra(EXTRA_HEADERS) as? HashMap<String, String>)
        ?: HashMap()

    activeTaskIds.add(taskId)
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

      FileInputStream(file).use { input ->
        connection.outputStream.use { output ->
          val buffer = ByteArray(BUFFER_SIZE)
          var sent = 0L
          while (true) {
            if (cancelledTaskIds.containsKey(taskId)) {
              postCancelled(taskId)
              return
            }
            val read = input.read(buffer)
            if (read == -1) break
            output.write(buffer, 0, read)
            sent += read
            if (length > 0) postProgress(taskId, sent.toDouble() / length)
          }
        }
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
    return builder
      .setContentTitle("Uploading")
      .setSmallIcon(android.R.drawable.stat_sys_upload)
      .setOngoing(true)
      .build()
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
    executor.shutdown()
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

    private const val CHANNEL_ID = "background_upload"
    private const val NOTIFICATION_ID = 0x42
    private const val BUFFER_SIZE = 64 * 1024
    private const val CONNECT_TIMEOUT_MS = 30_000
    private const val READ_TIMEOUT_MS = 600_000

    private val activeTaskIds = ConcurrentHashMap.newKeySet<String>()
    private val cancelledTaskIds = ConcurrentHashMap<String, Boolean>()

    /// Foreground sessions that keep the service alive beyond any in-flight
    /// upload, so the process stays foregrounded (network usable) across the
    /// caller's follow-up work — e.g. signing and broadcasting an event after a
    /// background upload completes. The service stops only when both the
    /// upload set and this set are empty.
    private val activeSessions = ConcurrentHashMap.newKeySet<String>()

    fun activeTaskIds(): List<String> = activeTaskIds.toList()
  }
}
