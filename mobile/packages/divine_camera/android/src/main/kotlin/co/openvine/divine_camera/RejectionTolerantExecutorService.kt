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
 *
 * Only [execute] is guarded. Kotlin's `by` delegation forwards `submit`,
 * `invokeAll`, and `invokeAny` straight to [delegate], whose own `execute`
 * (not this override) runs the task, so a rejection raised on those paths
 * would still propagate. That is sufficient here because `EncoderImpl` posts
 * its teardown callbacks via `execute(...)`; extend this wrapper if a future
 * caller routes work through `submit(...)`.
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
