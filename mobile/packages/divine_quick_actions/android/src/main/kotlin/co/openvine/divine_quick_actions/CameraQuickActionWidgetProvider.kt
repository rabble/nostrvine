package co.openvine.divine_quick_actions

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.os.Build
import android.widget.RemoteViews

class CameraQuickActionWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { appWidgetId ->
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        private const val REQUEST_CODE_OPEN_CAMERA = 4101

        internal fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(
                context.packageName,
                R.layout.divine_quick_actions_camera_widget
            )
            buildOpenCameraPendingIntent(context)?.let { pendingIntent ->
                views.setOnClickPendingIntent(
                    R.id.divine_quick_actions_camera_widget_button,
                    pendingIntent
                )
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun buildOpenCameraPendingIntent(context: Context): PendingIntent? {
            val intent = QuickActionContract.buildLaunchIntent(
                context,
                QuickActionContract.TYPE_CAMERA,
                mapOf("source" to "widget")
            ) ?: return null
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
            return PendingIntent.getActivity(
                context,
                REQUEST_CODE_OPEN_CAMERA,
                intent,
                flags
            )
        }

        private fun immutableFlag(): Int {
            return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE
            } else {
                0
            }
        }
    }
}