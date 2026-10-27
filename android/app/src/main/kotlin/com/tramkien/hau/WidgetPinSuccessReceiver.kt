package com.tramkien.hau

import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/**
 * BroadcastReceiver nhận callback từ Launcher khi người dùng xác nhận
 * "Thêm tự động" (Add automatically) trên hộp thoại Ghim Widget (requestPinAppWidget).
 *
 * Chức năng:
 * Kích hoạt cập nhật dữ liệu mới nhất cho toàn bộ widget đã ghim.
 * Không ép buộc mở màn hình chính bằng code để tránh văng vào App Drawer trên Samsung One UI / Xiaomi.
 */
class WidgetPinSuccessReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // Cập nhật dữ liệu cho các widget provider
        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val providerClasses = listOf(
                SingleDay2x2ScheduleWidgetProvider::class.java,
                ThreeDaysScheduleWidgetProvider::class.java,
                WeeklyScheduleWidgetProvider::class.java,
                ScheduleWidgetProvider::class.java,
                SingleDayScheduleWidgetProvider::class.java
            )
            for (cls in providerClasses) {
                try {
                    val thisWidget = ComponentName(context, cls)
                    val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
                    if (appWidgetIds.isNotEmpty()) {
                        val updateIntent = Intent(context, cls).apply {
                            action = "com.tramkien.hau.ACTION_UPDATE_WIDGET"
                            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
                        }
                        context.sendBroadcast(updateIntent)
                    }
                } catch (_: Exception) {}
            }
        } catch (_: Exception) {}
    }
}
