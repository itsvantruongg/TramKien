package com.tramkien.hau

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.app.UiModeManager
import android.content.res.Configuration
import android.content.res.Resources
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01: BƯỚC 5 - WIDGET TUẦN (4x4, ~320x318 dp)
 *
 * Yêu cầu:
 * 1. Đọc bản chụp lịch JSON widget_schedule_snapshot.json từ vùng chia sẻ file.
 * 2. Dòng tiêu đề: "Tuần dd/MM – dd/MM" (cỡ 12, vừa) kèm nút ‹ › chuyển tuần.
 * 3. Dải 7 ngày: T2 T3 T4 T5 T6 T7 CN (cỡ 11, màu phụ), hàng số môn (ngày 0 môn hiển thị dấu "·" màu mờ),
 *    ngày hôm nay: viên thuốc accent đầy quanh con số.
 * 4. Danh sách chi tiết cuộn được (ListView / RemoteViews AdapterView) theo nhóm ngày:
 *    - Tiêu đề nhóm ngày (cỡ 11, vừa): "Hôm nay · Thứ dd/MM", "Thứ dd/MM"...
 *    - Mỗi môn 1 hàng cao 19dp:
 *      * Thanh màu 3x14dp bo 2dp (theo bảng 8 màu 0..7).
 *      * Giờ bắt đầu "HH:mm" (rộng 34dp, màu phụ).
 *      * Tên môn (cắt "…").
 *      * Phòng căn phải (cỡ 11, phụ).
 *      * Môn thi: Vạch màu đỏ, tên môn in vừa và có tiền tố "Thi ", phòng căn phải.
 *      * Môn đã qua của hôm nay: Toàn hàng chuyển màu mờ (#888780), thanh màu chuyển màu xám.
 *      * Các ngày trống liên tiếp gộp thành một dòng: Ví dụ "T7 – CN: không có lịch".
 * 5. Tuân thủ AC-08 (không hardcode mốc giờ dạng \\b\\d{1,2}:\\d{2}\\b).
 */
typealias WeekWidgetProvider = WeeklyScheduleWidgetProvider
typealias WeekWidgetService = WeeklyRemoteViewsService

class WeeklyScheduleWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateAppWidget(context, appWidgetManager, appWidgetId)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val thisWidget = ComponentName(context, WeeklyScheduleWidgetProvider::class.java)

        when (action) {
            ACTION_WEEK_PREV, ACTION_WEEK_NEXT -> {
                // Đã lược bỏ tính năng dịch tuần theo yêu cầu người dùng
            }
            Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIMEZONE_CHANGED -> {
                // Tự động reset weekOffset về 0 khi sang ngày mới lúc 00:00
                resetAllWeekOffsets(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
                for (id in appWidgetIds) {
                    updateAppWidget(context, appWidgetManager, id)
                }
            }
            AppWidgetManager.ACTION_APPWIDGET_UPDATE,
            ACTION_UPDATE_WIDGET,
            ACTION_UPDATE_WIDGET_WEEKLY,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_DATE_CHANGED,
            Intent.ACTION_BOOT_COMPLETED -> {
                val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
                for (id in appWidgetIds) {
                    updateAppWidget(context, appWidgetManager, id)
                }
            }
        }
    }

    companion object {
        const val ACTION_UPDATE_WIDGET = "com.tramkien.hau.ACTION_UPDATE_WIDGET"
        const val ACTION_UPDATE_WIDGET_WEEKLY = "com.tramkien.hau.ACTION_UPDATE_WIDGET_WEEKLY"
        const val ACTION_WEEK_PREV = "com.tramkien.hau.ACTION_WEEK_PREV"
        const val ACTION_WEEK_NEXT = "com.tramkien.hau.ACTION_WEEK_NEXT"

        private const val PREFS_NAME = "widget_weekly_prefs"
        private const val KEY_WEEK_OFFSET_PREFIX = "week_offset_"
        private const val SNAPSHOT_FILE_NAME = "widget_schedule_snapshot.json"
        private const val VN_TIMEZONE_ID = "Asia/Ho_Chi_Minh"
        private const val ALARM_REQUEST_CODE = 405

        val WEEKDAY_LABELS = arrayOf("T2", "T3", "T4", "T5", "T6", "T7", "CN")

        data class SessionData(
            val id: Int,
            val kind: String, // "class" hoặc "exam"
            val subject: String,
            val shortName: String,
            val startMs: Long,
            val endMs: Long,
            val room: String,
            val teacher: String?,
            val seat: String?,
            val color: Int,
            val endEstimated: Boolean
        )

        fun isSystemDarkMode(context: Context): Boolean {
            val uiModeManager = context.getSystemService(Context.UI_MODE_SERVICE) as? UiModeManager
            if (uiModeManager != null) {
                if (uiModeManager.nightMode == UiModeManager.MODE_NIGHT_YES) return true
                if (uiModeManager.nightMode == UiModeManager.MODE_NIGHT_NO) return false
            }
            val systemNight = (Resources.getSystem().configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
            if (systemNight) return true

            return (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
        }

        fun getThemedContext(context: Context): Context {
            val isDark = isSystemDarkMode(context)
            val config = Configuration(context.resources.configuration)
            config.uiMode = (config.uiMode and Configuration.UI_MODE_NIGHT_MASK.inv()) or
                (if (isDark) Configuration.UI_MODE_NIGHT_YES else Configuration.UI_MODE_NIGHT_NO)
            return context.createConfigurationContext(config)
        }

        fun setViewTextColorRes(views: RemoteViews, viewId: Int, colorResId: Int, context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                views.setColor(viewId, "setTextColor", colorResId)
            } else {
                val themedContext = getThemedContext(context)
                @Suppress("DEPRECATION")
                val color = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    themedContext.getColor(colorResId)
                } else {
                    themedContext.resources.getColor(colorResId)
                }
                views.setTextColor(viewId, color)
            }
        }

        fun getWeekOffset(context: Context, appWidgetId: Int): Int {
            return 0
        }

        fun setWeekOffset(context: Context, appWidgetId: Int, offset: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putInt(KEY_WEEK_OFFSET_PREFIX + appWidgetId, offset).apply()
        }

        fun resetAllWeekOffsets(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().clear().apply()
        }

        fun readSnapshotJson(context: Context): JSONObject? {
            return try {
                val file = File(context.filesDir, SNAPSHOT_FILE_NAME)
                if (!file.exists()) return null
                val content = file.readText(Charsets.UTF_8)
                val json = JSONObject(content)
                if (json.optInt("version", -1) != 1) return null
                val genAt = json.optLong("generatedAt", 0L)
                val maxAgeMs = 180L * 24 * 60 * 60 * 1000
                if (genAt > 0 && (System.currentTimeMillis() - genAt > maxAgeMs)) return null
                json
            } catch (e: Exception) {
                null
            }
        }

        fun parseSessions(json: JSONObject?): List<SessionData> {
            if (json == null) return emptyList()
            val sessionsArray = json.optJSONArray("sessions") ?: return emptyList()
            val list = mutableListOf<SessionData>()
            for (i in 0 until sessionsArray.length()) {
                val obj = sessionsArray.optJSONObject(i) ?: continue
                list.add(
                    SessionData(
                        id = obj.optInt("id", 0),
                        kind = obj.optString("kind", "class"),
                        subject = obj.optString("subject", ""),
                        shortName = obj.optString("short", ""),
                        startMs = obj.optLong("startMs", 0L),
                        endMs = obj.optLong("endMs", 0L),
                        room = obj.optString("room", ""),
                        teacher = obj.optString("teacher", null),
                        seat = obj.optString("seat", null),
                        color = obj.optInt("color", 0),
                        endEstimated = obj.optBoolean("endEstimated", false)
                    )
                )
            }
            return list
        }

        fun simplifyRoom(rawRoom: String): String {
            var room = rawRoom.trim()
            if (room.isEmpty()) return ""
            room = room.replace(Regex("\\(.*?\\)"), "").trim()
            room = room.replace(Regex("^[Pp]\\.([A-Za-z0-9]+)"), "P$1")
            return room.trim()
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val isDark = isSystemDarkMode(context)
            val textPrimary = if (isDark) Color.parseColor("#FFFFFF") else Color.parseColor("#1F1F1E")
            val textSecondary = if (isDark) Color.parseColor("#D3D1C7") else Color.parseColor("#5F5E5A")
            val textDimmed = if (isDark) Color.parseColor("#A8A69E") else Color.parseColor("#888780")
            val views = RemoteViews(context.packageName, R.layout.widget_schedule_weekly)

            val vnTz = TimeZone.getTimeZone(VN_TIMEZONE_ID)
            val nowMs = System.currentTimeMillis()

            val dayMonthFormat = SimpleDateFormat("dd/MM", Locale.US).apply {
                timeZone = vnTz
            }

            val snapshotObj = readSnapshotJson(context)
            val weekOffset = getWeekOffset(context, appWidgetId)

            // Tính toán mốc Thứ Hai và Chủ Nhật của tuần
            val cal = Calendar.getInstance(vnTz, Locale.US).apply {
                timeInMillis = nowMs
            }
            val todayYear = cal.get(Calendar.YEAR)
            val todayMonth = cal.get(Calendar.MONTH)
            val todayDay = cal.get(Calendar.DAY_OF_MONTH)

            // Đưa về Thứ Hai của tuần hiện tại (Calendar.DAY_OF_WEEK: MONDAY = 2, SUNDAY = 1)
            var currentDayOfWeek = cal.get(Calendar.DAY_OF_WEEK)
            var daysFromMonday = if (currentDayOfWeek == Calendar.SUNDAY) 6 else currentDayOfWeek - Calendar.MONDAY
            cal.add(Calendar.DAY_OF_MONTH, -daysFromMonday)

            // Dịch chuyển theo weekOffset
            cal.add(Calendar.WEEK_OF_YEAR, weekOffset)

            val mondayDate = cal.time
            val mondayCal = cal.clone() as Calendar

            cal.add(Calendar.DAY_OF_MONTH, 6)
            val sundayDate = cal.time

            // 1. Tiêu đề tuần: "Tuần dd/MM – dd/MM"
            val weekTitle = "Tuần " + dayMonthFormat.format(mondayDate) + " \u2013 " + dayMonthFormat.format(sundayDate)
            views.setTextViewText(R.id.widget_weekly_title, weekTitle)

            // Luôn hiển thị tuần hiện tại (offset = 0)

            // Kiểm tra trạng thái có snapshot (AC-10)
            if (snapshotObj == null) {
                // Hiển thị dải 7 ngày trống với dấu ·
                for (i in 0 until 7) {
                    val countId = getCountViewId(i)
                    val todayCountId = getTodayCountViewId(i)
                    val labelId = getLabelViewId(i)
                    val todayLabelId = getTodayLabelViewId(i)

                    views.setViewVisibility(labelId, View.VISIBLE)
                    views.setViewVisibility(todayLabelId, View.GONE)
                    views.setViewVisibility(countId, View.VISIBLE)
                    views.setViewVisibility(todayCountId, View.GONE)
                    views.setTextViewText(countId, "\u00B7")
                }

                views.setViewVisibility(R.id.widget_weekly_list, View.GONE)
                views.setViewVisibility(R.id.widget_weekly_empty_container, View.VISIBLE)
                views.setViewVisibility(R.id.widget_weekly_footer_empty, View.GONE)
                views.setTextViewText(R.id.widget_weekly_empty_text, "Đăng nhập để xem lịch")

                val openAppIntent = Intent(Intent.ACTION_VIEW, Uri.parse("tramkien://schedule")).apply {
                    setClass(context, MainActivity::class.java)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val openAppPending = PendingIntent.getActivity(
                    context,
                    appWidgetId,
                    openAppIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.widget_root, openAppPending)

                appWidgetManager.updateAppWidget(appWidgetId, views)
                scheduleNextUpdate(context, emptyList(), nowMs)
                return
            }

            // Snapshot hợp lệ
            views.setViewVisibility(R.id.widget_weekly_list, View.VISIBLE)
            views.setViewVisibility(R.id.widget_weekly_empty_container, View.GONE)

            val allSessions = parseSessions(snapshotObj)

            val startOfTodayCal = Calendar.getInstance(vnTz, Locale.US).apply {
                timeInMillis = nowMs
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val startOfTodayMs = startOfTodayCal.timeInMillis

            val dayCal = mondayCal.clone() as Calendar
            for (i in 0 until 7) {
                val dYear = dayCal.get(Calendar.YEAR)
                val dMonth = dayCal.get(Calendar.MONTH)
                val dDay = dayCal.get(Calendar.DAY_OF_MONTH)
                val dTimeMs = dayCal.timeInMillis

                val countId = getCountViewId(i)
                val labelId = getLabelViewId(i)
                val todayCountId = getTodayCountViewId(i)
                val todayLabelId = getTodayLabelViewId(i)

                val isToday = (dYear == todayYear && dMonth == todayMonth && dDay == todayDay)
                val isPastDay = dTimeMs < startOfTodayMs

                val dateStr = dayMonthFormat.format(dayCal.time)

                if (isToday) {
                    views.setViewVisibility(labelId, View.GONE)
                    views.setViewVisibility(todayLabelId, View.VISIBLE)
                    views.setTextViewText(todayLabelId, WEEKDAY_LABELS[i])

                    views.setViewVisibility(countId, View.GONE)
                    views.setViewVisibility(todayCountId, View.VISIBLE)
                    views.setTextViewText(todayCountId, dateStr)
                } else {
                    views.setViewVisibility(labelId, View.VISIBLE)
                    views.setViewVisibility(todayLabelId, View.GONE)
                    views.setTextViewText(labelId, WEEKDAY_LABELS[i])

                    views.setViewVisibility(countId, View.VISIBLE)
                    views.setViewVisibility(todayCountId, View.GONE)
                    views.setTextViewText(countId, dateStr)

                    if (isPastDay) {
                        views.setTextColor(labelId, textDimmed)
                        views.setTextColor(countId, textDimmed)
                    }
                }

                dayCal.add(Calendar.DAY_OF_MONTH, 1)
            }

            // Phân bổ sessions theo 7 ngày để xác định footer ngày trống cuối tuần khi danh sách không cần cuộn
            val sessionsByDay = Array(7) { mutableListOf<SessionData>() }
            for (s in allSessions) {
                val sCal = Calendar.getInstance(vnTz, Locale.US).apply { timeInMillis = s.startMs }
                for (i in 0 until 7) {
                    val dCal = mondayCal.clone() as Calendar
                    dCal.add(Calendar.DAY_OF_MONTH, i)
                    if (sCal.get(Calendar.YEAR) == dCal.get(Calendar.YEAR) &&
                        sCal.get(Calendar.MONTH) == dCal.get(Calendar.MONTH) &&
                        sCal.get(Calendar.DAY_OF_MONTH) == dCal.get(Calendar.DAY_OF_MONTH)) {
                        sessionsByDay[i].add(s)
                        break
                    }
                }
            }

            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            val minHeightDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
            val isSatEmpty = sessionsByDay[5].isEmpty()
            val isNoScroll = computeIsNoScroll(sessionsByDay, minHeightDp)

            if (isNoScroll) {
                val footerStr = if (isSatEmpty) "T7 \u2013 CN: không có lịch" else "CN: không có lịch"
                views.setTextViewText(R.id.widget_weekly_footer_empty, footerStr)
                views.setViewVisibility(R.id.widget_weekly_footer_empty, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_weekly_footer_empty, View.GONE)
            }

            // Gán RemoteAdapter cho ListView cuộn được (Uri kèm timestamp để bypass cache của Launcher)
            val serviceIntent = Intent(context, WeeklyRemoteViewsService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                putExtra("week_offset", weekOffset)
                data = Uri.parse("tramkien://widget/weekly/list/$appWidgetId/${System.currentTimeMillis()}")
            }
            views.setRemoteAdapter(R.id.widget_weekly_list, serviceIntent)

            // PendingIntent Template cho các hàng trong ListView
            val listClickIntent = Intent(Intent.ACTION_VIEW).apply {
                setClass(context, MainActivity::class.java)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val listClickPending = PendingIntent.getActivity(
                context,
                appWidgetId * 10 + 3,
                listClickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            views.setPendingIntentTemplate(R.id.widget_weekly_list, listClickPending)

            // BẮT BUỘC updateAppWidget TRƯỚC để Launcher commit RemoteViews mới (VISIBLE)
            appWidgetManager.updateAppWidget(appWidgetId, views)
            // Sau đó MỚI notify để RemoteViewsFactory kích hoạt onDataSetChanged() nạp dữ liệu mới
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_weekly_list)
            scheduleNextUpdate(context, allSessions, nowMs)
        }

        private fun getCountViewId(index: Int): Int {
            return when (index) {
                0 -> R.id.col_day_count_0
                1 -> R.id.col_day_count_1
                2 -> R.id.col_day_count_2
                3 -> R.id.col_day_count_3
                4 -> R.id.col_day_count_4
                5 -> R.id.col_day_count_5
                else -> R.id.col_day_count_6
            }
        }

        private fun getTodayCountViewId(index: Int): Int {
            return when (index) {
                0 -> R.id.col_day_today_count_0
                1 -> R.id.col_day_today_count_1
                2 -> R.id.col_day_today_count_2
                3 -> R.id.col_day_today_count_3
                4 -> R.id.col_day_today_count_4
                5 -> R.id.col_day_today_count_5
                else -> R.id.col_day_today_count_6
            }
        }

        private fun getLabelViewId(index: Int): Int {
            return when (index) {
                0 -> R.id.col_day_label_0
                1 -> R.id.col_day_label_1
                2 -> R.id.col_day_label_2
                3 -> R.id.col_day_label_3
                4 -> R.id.col_day_label_4
                5 -> R.id.col_day_label_5
                else -> R.id.col_day_label_6
            }
        }

        private fun getTodayLabelViewId(index: Int): Int {
            return when (index) {
                0 -> R.id.col_day_today_label_0
                1 -> R.id.col_day_today_label_1
                2 -> R.id.col_day_today_label_2
                3 -> R.id.col_day_today_label_3
                4 -> R.id.col_day_today_label_4
                5 -> R.id.col_day_today_label_5
                else -> R.id.col_day_today_label_6
            }
        }

        fun scheduleNextUpdate(context: Context, sessions: List<SessionData>, nowMs: Long) {
            val vnTz = TimeZone.getTimeZone(VN_TIMEZONE_ID)
            val cal = Calendar.getInstance(vnTz, Locale.US).apply {
                timeInMillis = nowMs
                add(Calendar.DAY_OF_MONTH, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 2)
                set(Calendar.MILLISECOND, 0)
            }
            var nextTriggerMs = cal.timeInMillis

            for (s in sessions) {
                if (s.startMs > nowMs && s.startMs < nextTriggerMs) {
                    nextTriggerMs = s.startMs + 1000L
                }
                if (s.endMs > nowMs && s.endMs < nextTriggerMs) {
                    nextTriggerMs = s.endMs + 1000L
                }
            }

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, WeeklyScheduleWidgetProvider::class.java).apply {
                action = ACTION_UPDATE_WIDGET_WEEKLY
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextTriggerMs, pendingIntent)
                } else {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, nextTriggerMs, pendingIntent)
                }
            } catch (e: Exception) {
                // Ignore security exceptions
            }
        }

        fun computeIsNoScroll(
            sessionsByDay: Array<MutableList<SessionData>>,
            minHeightDp: Int = 0
        ): Boolean {
            val isWeekendTrailingEmpty = sessionsByDay[6].isEmpty()
            if (!isWeekendTrailingEmpty) return false

            val activeDays = sessionsByDay.count { it.isNotEmpty() }
            val totalSessions = sessionsByDay.sumOf { it.size }

            var emptyBlocks = 0
            var inEmpty = false
            val endCheck = if (sessionsByDay[5].isEmpty()) 5 else 6
            for (i in 0 until endCheck) {
                if (sessionsByDay[i].isEmpty()) {
                    if (!inEmpty) {
                        emptyBlocks++
                        inEmpty = true
                    }
                } else {
                    inEmpty = false
                }
            }

            val availableHeightDp = if (minHeightDp > 0) maxOf(minHeightDp - 90, 240) else 260
            val itemHeight = 28
            val headerHeight = 22
            val emptyHeight = 18
            val totalContentHeightDp = (activeDays * headerHeight) + (totalSessions * itemHeight) + (emptyBlocks * emptyHeight)

            return totalContentHeightDp <= availableHeightDp
        }
    }
}

/**
 * Service cấp dữ liệu cho ListView cuộn được của Widget Tuần 4x4
 */
class WeeklyRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return WeeklyRemoteViewsFactory(applicationContext, intent)
    }
}

/**
 * Factory tạo các hàng cho ListView của Widget Tuần 4x4
 */
class WeeklyRemoteViewsFactory(
    private val context: Context,
    private val intent: Intent
) : RemoteViewsService.RemoteViewsFactory {

    private val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
    private var weekOffset = intent.getIntExtra("week_offset", 0)

    sealed class ListItem {
        data class DayHeader(val title: String, val dateIso: String, val isToday: Boolean, val isPastDay: Boolean) : ListItem()
        data class SessionRow(
            val session: WeeklyScheduleWidgetProvider.Companion.SessionData,
            val timeStr: String,
            val displayTitle: String,
            val roomStr: String,
            val isExam: Boolean,
            val isPast: Boolean,
            val isToday: Boolean,
            val colorIndex: Int,
            val dateIso: String
        ) : ListItem()
        data class MergedEmptyDays(val title: String, val dateIso: String) : ListItem()
    }

    private val items = mutableListOf<ListItem>()
    private var isAdaptiveMode = false

    // Bảng 8 màu Text/Bar chuẩn phân biệt rõ rệt (Vibrant & High Contrast - Cool Tones cho môn học)
    private val subjectColorsLight = intArrayOf(
        Color.parseColor("#2563EB"), // 0 - Blue
        Color.parseColor("#059669"), // 1 - Emerald
        Color.parseColor("#7C3AED"), // 2 - Violet
        Color.parseColor("#0D9488"), // 3 - Teal (thay cho Amber để độc quyền màu ấm cho lịch thi)
        Color.parseColor("#0891B2"), // 4 - Cyan
        Color.parseColor("#0284C7"), // 5 - Sky (thay cho Rose để độc quyền màu ấm cho lịch thi)
        Color.parseColor("#0369A1"), // 6 - Ocean Blue (thay cho Slate để màu xám chỉ dành cho môn đã qua)
        Color.parseColor("#4F46E5")  // 7 - Indigo
    )

    private val subjectColorsDark = intArrayOf(
        Color.parseColor("#93C5FD"), // 0 - Blue light
        Color.parseColor("#6EE7B7"), // 1 - Emerald light
        Color.parseColor("#C4B5FD"), // 2 - Violet light
        Color.parseColor("#5EEAD4"), // 3 - Teal light
        Color.parseColor("#67E8F9"), // 4 - Cyan light
        Color.parseColor("#7DD3FC"), // 5 - Sky light
        Color.parseColor("#7DD3FC"), // 6 - Ocean Blue light
        Color.parseColor("#A5B4FC")  // 7 - Indigo light
    )

    override fun onCreate() {
        buildItems()
    }

    override fun onDataSetChanged() {
        weekOffset = WeeklyScheduleWidgetProvider.getWeekOffset(context, appWidgetId)
        buildItems()
    }

    private fun buildItems() {
        items.clear()
        val snapshotObj = WeeklyScheduleWidgetProvider.readSnapshotJson(context) ?: return
        val allSessions = WeeklyScheduleWidgetProvider.parseSessions(snapshotObj)

        val vnTz = TimeZone.getTimeZone("Asia/Ho_Chi_Minh")
        val nowMs = System.currentTimeMillis()

        val timeFormat = SimpleDateFormat("HH:mm", Locale.US).apply { timeZone = vnTz }
        val dayMonthFormat = SimpleDateFormat("dd/MM", Locale.US).apply { timeZone = vnTz }
        val isoFormat = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { timeZone = vnTz }

        val cal = Calendar.getInstance(vnTz, Locale.US).apply { timeInMillis = nowMs }
        val todayYear = cal.get(Calendar.YEAR)
        val todayMonth = cal.get(Calendar.MONTH)
        val todayDay = cal.get(Calendar.DAY_OF_MONTH)

        val startOfTodayCal = Calendar.getInstance(vnTz, Locale.US).apply {
            timeInMillis = nowMs
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val startOfTodayMs = startOfTodayCal.timeInMillis

        var currentDayOfWeek = cal.get(Calendar.DAY_OF_WEEK)
        var daysFromMonday = if (currentDayOfWeek == Calendar.SUNDAY) 6 else currentDayOfWeek - Calendar.MONDAY
        cal.add(Calendar.DAY_OF_MONTH, -daysFromMonday)
        cal.add(Calendar.WEEK_OF_YEAR, weekOffset)

        val targetMondayCal = cal.clone() as Calendar

        // Phân bổ sessions theo 7 ngày
        val sessionsByDay = Array(7) { mutableListOf<WeeklyScheduleWidgetProvider.Companion.SessionData>() }

        for (s in allSessions) {
            val sCal = Calendar.getInstance(vnTz, Locale.US).apply { timeInMillis = s.startMs }
            val diffDays = ((s.startMs - targetMondayCal.timeInMillis) / (24 * 60 * 60 * 1000L)).toInt()

            for (i in 0 until 7) {
                val dCal = targetMondayCal.clone() as Calendar
                dCal.add(Calendar.DAY_OF_MONTH, i)
                if (sCal.get(Calendar.YEAR) == dCal.get(Calendar.YEAR) &&
                    sCal.get(Calendar.MONTH) == dCal.get(Calendar.MONTH) &&
                    sCal.get(Calendar.DAY_OF_MONTH) == dCal.get(Calendar.DAY_OF_MONTH)) {
                    sessionsByDay[i].add(s)
                    break
                }
            }
        }

        for (i in 0 until 7) {
            sessionsByDay[i].sortBy { it.startMs }
        }

        val totalSessionsInWeek = sessionsByDay.sumOf { it.size }
        isAdaptiveMode = true

        val options = AppWidgetManager.getInstance(context).getAppWidgetOptions(appWidgetId)
        val minHeightDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
        val isSatEmpty = sessionsByDay[5].isEmpty()
        val isNoScroll = WeeklyScheduleWidgetProvider.computeIsNoScroll(sessionsByDay, minHeightDp)

        // Tạo items xen kẽ nhóm ngày và gộp ngày trống
        var emptyStart = -1

        fun flushEmpty(currentIdx: Int) {
            if (emptyStart != -1) {
                if (currentIdx == 7 && isNoScroll) {
                    if (emptyStart >= 5) {
                        emptyStart = -1
                        return
                    } else {
                        val startIdx = emptyStart
                        val endIdx = if (isSatEmpty) 4 else 5
                        if (endIdx >= startIdx) {
                            val startWk = WeeklyScheduleWidgetProvider.WEEKDAY_LABELS[startIdx]
                            val endWk = WeeklyScheduleWidgetProvider.WEEKDAY_LABELS[endIdx]
                            val title = if (startIdx == endIdx) {
                                "$startWk: không có lịch"
                            } else {
                                "$startWk \u2013 $endWk: không có lịch"
                            }
                            val eCal = targetMondayCal.clone() as Calendar
                            eCal.add(Calendar.DAY_OF_MONTH, startIdx)
                            items.add(ListItem.MergedEmptyDays(title, isoFormat.format(eCal.time)))
                        }
                        emptyStart = -1
                        return
                    }
                }

                val startIdx = emptyStart
                val endIdx = currentIdx - 1
                val startWk = WeeklyScheduleWidgetProvider.WEEKDAY_LABELS[startIdx]
                val endWk = WeeklyScheduleWidgetProvider.WEEKDAY_LABELS[endIdx]
                val title = if (startIdx == endIdx) {
                    "$startWk: không có lịch"
                } else {
                    "$startWk \u2013 $endWk: không có lịch"
                }
                val eCal = targetMondayCal.clone() as Calendar
                eCal.add(Calendar.DAY_OF_MONTH, startIdx)
                items.add(ListItem.MergedEmptyDays(title, isoFormat.format(eCal.time)))
                emptyStart = -1
            }
        }

        for (i in 0 until 7) {
            val daySessions = sessionsByDay[i]
            if (daySessions.isEmpty()) {
                if (emptyStart == -1) {
                    emptyStart = i
                }
            } else {
                flushEmpty(i)

                val dCal = targetMondayCal.clone() as Calendar
                dCal.add(Calendar.DAY_OF_MONTH, i)
                val dDate = dCal.time
                val isToday = (dCal.get(Calendar.YEAR) == todayYear &&
                               dCal.get(Calendar.MONTH) == todayMonth &&
                               dCal.get(Calendar.DAY_OF_MONTH) == todayDay)
                val isPastDay = dCal.timeInMillis < startOfTodayMs

                val wkStr = WeeklyScheduleWidgetProvider.WEEKDAY_LABELS[i]
                val headerTitle = if (isToday) {
                    "Hôm nay \u00B7 $wkStr " + dayMonthFormat.format(dDate)
                } else {
                    "$wkStr " + dayMonthFormat.format(dDate)
                }
                val dateIso = isoFormat.format(dDate)

                items.add(ListItem.DayHeader(headerTitle, dateIso, isToday, isPastDay))

                for (s in daySessions) {
                    val isExam = (s.kind == "exam")
                    val isPast = (s.endMs <= nowMs)
                    val sStartDate = Date(s.startMs)
                    val timeStr = timeFormat.format(sStartDate)
                    val roomStr = WeeklyScheduleWidgetProvider.simplifyRoom(s.room)

                    val rawName = s.subject.trim()
                    val titleWithPrefix = if (isExam) "Thi $rawName" else rawName

                    items.add(
                        ListItem.SessionRow(
                            session = s,
                            timeStr = timeStr,
                            displayTitle = titleWithPrefix,
                            roomStr = roomStr,
                            isExam = isExam,
                            isPast = isPast,
                            isToday = isToday,
                            colorIndex = s.color,
                            dateIso = dateIso
                        )
                    )
                }
            }
        }

        flushEmpty(7)
    }

    override fun onDestroy() {
        items.clear()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews? {
        if (position < 0 || position >= items.size) return null
        val item = items[position]
        val isDark = WeeklyScheduleWidgetProvider.isSystemDarkMode(context)

        return when (item) {
            is ListItem.DayHeader -> {
                val layoutId = R.layout.widget_weekly_item_header_adaptive
                val rv = RemoteViews(context.packageName, layoutId)
                rv.setTextViewText(R.id.item_header_text, item.title)
                if (item.isToday) {
                    val todayColor = if (isDark) Color.parseColor("#85B7EB") else Color.parseColor("#185FA5")
                    rv.setTextColor(R.id.item_header_text, todayColor)
                } else if (item.isPastDay) {
                    val dimColor = if (isDark) Color.parseColor("#A8A69E") else Color.parseColor("#888780")
                    rv.setTextColor(R.id.item_header_text, dimColor)
                }

                val fillIntent = Intent().apply {
                    data = Uri.parse("tramkien://schedule?date=${item.dateIso}")
                }
                rv.setOnClickFillInIntent(R.id.widget_weekly_item_root, fillIntent)
                rv
            }
            is ListItem.SessionRow -> {
                val layoutId = R.layout.widget_weekly_item_session_adaptive
                val rv = RemoteViews(context.packageName, layoutId)
                rv.setTextViewText(R.id.item_session_time, item.timeStr)
                rv.setTextViewText(R.id.item_session_title, item.displayTitle)
                rv.setTextViewText(R.id.item_session_room, item.roomStr)

                // Cài đặt màu vạch và chữ
                if (item.isPast) {
                    // Môn đã kết thúc: thanh màu xám, toàn hàng chuyển màu mờ
                    val grayBar = if (isDark) Color.parseColor("#444441") else Color.parseColor("#D3D1C7")
                    rv.setInt(R.id.item_color_bar, "setColorFilter", grayBar)
                    val dimColor = if (isDark) Color.parseColor("#A8A69E") else Color.parseColor("#888780")
                    val subColor = if (isDark) Color.parseColor("#D3D1C7") else Color.parseColor("#888780")
                    rv.setTextColor(R.id.item_session_time, subColor)
                    rv.setTextColor(R.id.item_session_title, dimColor)
                    rv.setTextColor(R.id.item_session_room, subColor)
                } else if (item.isExam) {
                    // Môn thi chưa kết thúc: Vạch màu đỏ, chữ đỏ
                    rv.setInt(R.id.item_color_bar, "setColorFilter", Color.parseColor("#EF4444"))
                    val examTitleColor = if (isDark) Color.parseColor("#FCA5A5") else Color.parseColor("#791F1F")
                    val subColor = if (isDark) Color.parseColor("#D3D1C7") else Color.parseColor("#5F5E5A")
                    rv.setTextColor(R.id.item_session_time, subColor)
                    rv.setTextColor(R.id.item_session_title, examTitleColor)
                    rv.setTextColor(R.id.item_session_room, subColor)
                } else {
                    // Môn học thường chưa kết thúc: Vạch màu theo colorIndex, reset màu text chống tái sử dụng view rác
                    val palette = if (isDark) subjectColorsDark else subjectColorsLight
                    val safeIdx = item.colorIndex.coerceIn(0, 7)
                    rv.setInt(R.id.item_color_bar, "setColorFilter", palette[safeIdx])
                    val titleColor = if (isDark) Color.parseColor("#F1EFE8") else Color.parseColor("#1F1F1E")
                    val subColor = if (isDark) Color.parseColor("#D3D1C7") else Color.parseColor("#5F5E5A")
                    rv.setTextColor(R.id.item_session_title, titleColor)
                    rv.setTextColor(R.id.item_session_time, subColor)
                    rv.setTextColor(R.id.item_session_room, subColor)
                }

                val fillIntent = Intent().apply {
                    data = Uri.parse("tramkien://schedule?date=${item.dateIso}&sessionId=${item.session.id}")
                }
                rv.setOnClickFillInIntent(R.id.widget_weekly_item_root, fillIntent)
                rv
            }
            is ListItem.MergedEmptyDays -> {
                val layoutId = R.layout.widget_weekly_item_empty_adaptive
                val rv = RemoteViews(context.packageName, layoutId)
                rv.setTextViewText(R.id.item_empty_text, item.title)
                val fillIntent = Intent().apply {
                    data = Uri.parse("tramkien://schedule?date=${item.dateIso}")
                }
                rv.setOnClickFillInIntent(R.id.widget_weekly_item_root, fillIntent)
                rv
            }
        }
    }

    override fun getLoadingView(): RemoteViews {
        return RemoteViews(context.packageName, R.layout.widget_weekly_loading)
    }

    override fun getViewTypeCount(): Int = 6

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
}
