package co.openvine.divine_quick_actions

import android.app.Activity
import android.graphics.drawable.Drawable
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView

/**
 * Covers a warm-resumed activity with the launch splash (the divine wordmark
 * centered on the brand background) while a camera quick action navigates to
 * the recorder.
 *
 * Only used for warm resumes: `launchMode="singleTask"` reuses the activity via
 * `onNewIntent`, and the OS composites the activity's last rendered frame — the
 * route the user left open (e.g. their profile) — before Flutter receives the
 * intent and navigates to the recorder. Dart can't paint before the OS shows
 * that cached surface, so the cover must be native. Cold starts are left alone:
 * the OS already shows the launch splash (the same logo a normal app-icon
 * launch shows), so there is nothing to cover.
 *
 * The wordmark is drawn with a real [ImageView] rather than by setting the
 * `launch_background` layer-list as a View background: a layer-list's centered
 * `<bitmap>` frequently fails to render as a View background, leaving only the
 * flat colour — which showed as a bare green cover. The brand background colour
 * is applied directly (no resource-name lookup) so the cover can never collapse
 * to the wrong colour, and the app icon is used as a last-resort glyph if the
 * wordmark drawable can't be resolved.
 */
internal interface CameraLaunchCover {
  fun show(activity: Activity)

  fun dismiss()
}

internal class WindowCameraLaunchCover(
  private val autoDismissMs: Long = DEFAULT_AUTO_DISMISS_MS,
) : CameraLaunchCover {
  private val mainHandler = Handler(Looper.getMainLooper())
  private val autoDismiss = Runnable { dismiss() }
  private var coverView: View? = null

  override fun show(activity: Activity) {
    if (coverView != null) {
      restartSafetyTimeout()
      return
    }
    val root = activity.window?.decorView as? ViewGroup ?: return
    coverView = buildCoverView(activity).also(root::addView)
    restartSafetyTimeout()
  }

  override fun dismiss() {
    mainHandler.removeCallbacks(autoDismiss)
    val view = coverView ?: return
    (view.parent as? ViewGroup)?.removeView(view)
    coverView = null
  }

  private fun restartSafetyTimeout() {
    mainHandler.removeCallbacks(autoDismiss)
    mainHandler.postDelayed(autoDismiss, autoDismissMs)
  }

  private fun buildCoverView(activity: Activity): View {
    val container = FrameLayout(activity).apply {
      layoutParams = ViewGroup.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.MATCH_PARENT,
      )
      // Swallow taps so the covered route can't be interacted with.
      isClickable = true
      setBackgroundColor(SPLASH_BACKGROUND_COLOR)
    }

    resolveLogo(activity)?.let { logo ->
      container.addView(
        ImageView(activity).apply {
          setImageDrawable(logo)
          adjustViewBounds = true
          layoutParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER,
          )
        },
      )
    }

    return container
  }

  /** The wordmark splash image, falling back to the app launcher icon. */
  private fun resolveLogo(activity: Activity): Drawable? {
    val wordmarkId = activity.resources.getIdentifier(
      LAUNCH_IMAGE_NAME,
      "drawable",
      activity.packageName,
    )
    if (wordmarkId != 0) {
      runCatching { activity.getDrawable(wordmarkId) }.getOrNull()?.let { return it }
    }
    // PackageManager always resolves the launcher icon, even when resource-name
    // lookup is unavailable (e.g. shrunk builds).
    return runCatching {
      activity.packageManager.getApplicationIcon(activity.packageName)
    }.getOrNull()
  }

  companion object {
    // Pure safety net for a wedged engine. Dart deterministically drops the
    // cover in every terminal state (recorder opened, action ignored/dropped);
    // this only fires if Dart never responds at all.
    private const val DEFAULT_AUTO_DISMISS_MS = 2000L

    // @color/splash_background — applied directly so the cover never depends on
    // a resource-name lookup for its background.
    private const val SPLASH_BACKGROUND_COLOR = 0xFF00150D.toInt()

    // Flutter's conventional full-screen splash wordmark in the host app.
    private const val LAUNCH_IMAGE_NAME = "launch_image"
  }
}
