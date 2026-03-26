package co.openvine.image_metadata_stripper

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import androidx.exifinterface.media.ExifInterface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors

class ImageMetadataStripperPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(
        flutterPluginBinding: FlutterPlugin.FlutterPluginBinding,
    ) {
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "image_metadata_stripper",
        )
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "stripImageMetadata" -> stripImageMetadata(call, result)
            else -> result.notImplemented()
        }
    }

    private fun stripImageMetadata(call: MethodCall, result: Result) {
        val inputPath = call.argument<String>("inputPath")
        val outputPath = call.argument<String>("outputPath")

        if (inputPath == null || outputPath == null) {
            result.error(
                "INVALID_ARGUMENT",
                "inputPath and outputPath are required",
                null,
            )
            return
        }

        val inputFile = File(inputPath)
        if (!inputFile.exists()) {
            result.error(
                "FILE_NOT_FOUND",
                "Input file does not exist: $inputPath",
                null,
            )
            return
        }

        executor.execute {
            try {
                // Read EXIF orientation before decoding
                val exif = ExifInterface(inputPath)
                val orientation = exif.getAttributeInt(
                    ExifInterface.TAG_ORIENTATION,
                    ExifInterface.ORIENTATION_NORMAL,
                )

                val bitmap = BitmapFactory.decodeFile(inputPath)
                if (bitmap == null) {
                    mainHandler.post {
                        result.error(
                            "DECODE_FAILED",
                            "Could not decode image: $inputPath",
                            null,
                        )
                    }
                    return@execute
                }

                // Apply EXIF orientation to bitmap
                val oriented = applyOrientation(bitmap, orientation)

                val format = if (inputPath.lowercase().endsWith(".png")) {
                    Bitmap.CompressFormat.PNG
                } else {
                    Bitmap.CompressFormat.JPEG
                }

                val quality = if (format == Bitmap.CompressFormat.PNG) 100 else 85

                FileOutputStream(File(outputPath)).use { out ->
                    oriented.compress(format, quality, out)
                }
                if (oriented !== bitmap) oriented.recycle()
                bitmap.recycle()

                mainHandler.post {
                    result.success(null)
                }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("STRIP_FAILED", e.message, null)
                }
            }
        }
    }

    private fun applyOrientation(bitmap: Bitmap, orientation: Int): Bitmap {
        val matrix = Matrix()
        when (orientation) {
            ExifInterface.ORIENTATION_ROTATE_90 -> matrix.postRotate(90f)
            ExifInterface.ORIENTATION_ROTATE_180 -> matrix.postRotate(180f)
            ExifInterface.ORIENTATION_ROTATE_270 -> matrix.postRotate(270f)
            ExifInterface.ORIENTATION_FLIP_HORIZONTAL ->
                matrix.postScale(-1f, 1f)
            ExifInterface.ORIENTATION_FLIP_VERTICAL ->
                matrix.postScale(1f, -1f)
            ExifInterface.ORIENTATION_TRANSPOSE -> {
                matrix.postRotate(90f)
                matrix.postScale(-1f, 1f)
            }
            ExifInterface.ORIENTATION_TRANSVERSE -> {
                matrix.postRotate(270f)
                matrix.postScale(-1f, 1f)
            }
            else -> return bitmap
        }
        return Bitmap.createBitmap(
            bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true,
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
