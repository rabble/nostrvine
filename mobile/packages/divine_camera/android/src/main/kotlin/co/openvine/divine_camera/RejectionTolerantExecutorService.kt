package co.openvine.divine_camera

import java.util.concurrent.ExecutorService
import java.util.concurrent.RejectedExecutionException

/**
 * Wraps an [ExecutorService] so tasks submitted after shutdown are dropped
 * instead of throwing [RejectedExecutionException].
 *
 * CameraX's `EncoderImpl` posts MediaCodec teardown callbacks (including a
 * late `onError`) to the recorder executor. When the camera is released the
 * executor is shut down, and a callback that arrives afterwards would
 * otherwise crash the app with an uncaught `RejectedExecutionException` on
 * the MediaCodec thread. Swallowing the rejection makes teardown
 * timing-independent.
 */
internal class RejectionTolerantExecutorService(
    private val delegate: ExecutorService,
) : ExecutorService by delegate {
    override fun execute(command: Runnable) {
        try {
            delegate.execute(command)
        } catch (e: RejectedExecutionException) {
            DivineCameraLog.w(
                TAG,
                "Dropped task on terminated camera executor: ${e.message}",
            )
        }
    }

    private companion object {
        private const val TAG = "RejectionTolerantExecutor"
    }
}
