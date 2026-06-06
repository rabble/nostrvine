package co.openvine.divine_quick_actions

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.appwidget.AppWidgetProviderInfo
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
                widgetLayout(appWidgetManager, appWidgetId)
            )
            buildOpenCameraPendingIntent(context)?.let { pendingIntent ->
                views.setOnClickPendingIntent(
                    R.id.divine_quick_actions_camera_widget_button,
                    pendingIntent
                )
            }
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun widgetLayout(
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ): Int {
            val hostCategory = appWidgetManager
                .getAppWidgetOptions(appWidgetId)
                .getInt(
                    AppWidgetManager.OPTION_APPWIDGET_HOST_CATEGORY,
                    AppWidgetProviderInfo.WIDGET_CATEGORY_HOME_SCREEN
                )
            return if (hostCategory == AppWidgetProviderInfo.WIDGET_CATEGORY_KEYGUARD) {
                R.layout.divine_quick_actions_camera_widget_keyguard
            } else {
                R.layout.divine_quick_actions_camera_widget
            }
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
