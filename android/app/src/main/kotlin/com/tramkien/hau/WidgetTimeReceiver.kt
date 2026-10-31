package com.tramkien.hau

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/**
 * Receiver lắng nghe các sự kiện thời gian và hệ thống để cập nhật toàn bộ widget:
 * - TIME_SET (người dùng đổi giờ)
 * - TIMEZONE_CHANGED (đổi múi giờ)
 * - DATE_CHANGED (sang ngày mới 00:00)
 * - BOOT_COMPLETED (khởi động máy xong)
 *
 * Tuân thủ SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 Mục 3 & 6.
 */
class WidgetTimeReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action == Intent.ACTION_TIME_CHANGED ||
            action == Intent.ACTION_TIMEZONE_CHANGED ||
            action == Intent.ACTION_DATE_CHANGED ||
            action == Intent.ACTION_BOOT_COMPLETED ||
            action == "android.intent.action.TIME_SET"
        ) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val providers = listOf(
                SingleDay2x2ScheduleWidgetProvider::class.java,
                MonthToday4x2ScheduleWidgetProvider::class.java,
                ThreeDaysScheduleWidgetProvider::class.java,
                WeeklyScheduleWidgetProvider::class.java
            )

            for (providerCls in providers) {
                try {
                    val comp = ComponentName(context, providerCls)
                    val ids = appWidgetManager.getAppWidgetIds(comp)
                    if (ids.isNotEmpty()) {
                        val updateIntent = Intent(context, providerCls).apply {
                            this.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                        }
                        context.sendBroadcast(updateIntent)
                    }
                } catch (_: Exception) {}
            }
        }
    }
}
