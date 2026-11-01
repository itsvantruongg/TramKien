package com.tramkien.hau

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
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
            ACTION_WEEK_PREV -> {
                val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
                if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    val currentOffset = getWeekOffset(context, appWidgetId)
                    setWeekOffset(context, appWidgetId, currentOffset - 1)
                    updateAppWidget(context, appWidgetManager, appWidgetId)
                }
            }
            ACTION_WEEK_NEXT -> {
                val appWidgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
                if (appWidgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    val currentOffset = getWeekOffset(context, appWidgetId)
                    setWeekOffset(context, appWidgetId, currentOffset + 1)
                    updateAppWidget(context, appWidgetManager, appWidgetId)
                }
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

        fun getWeekOffset(context: Context, appWidgetId: Int): Int {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            return prefs.getInt(KEY_WEEK_OFFSET_PREFIX + appWidgetId, 0)
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
                val maxAgeMs = 14L * 24 * 60 * 60 * 1000
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
            val isDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
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

            // 2. Nút chuyển tuần ‹ và ›
            val prevIntent = Intent(context, WeeklyScheduleWidgetProvider::class.java).apply {
                action = ACTION_WEEK_PREV
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val prevPending = PendingIntent.getBroadcast(
                context,
                appWidgetId * 10 + 1,
                prevIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_weekly_btn_prev, prevPending)

            val nextIntent = Intent(context, WeeklyScheduleWidgetProvider::class.java).apply {
                action = ACTION_WEEK_NEXT
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val nextPending = PendingIntent.getBroadcast(
                context,
                appWidgetId * 10 + 2,
                nextIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_weekly_btn_next, nextPending)

            // Kiểm tra trạng thái có snapshot (AC-10)
            if (snapshotObj == null) {
                // Hiển thị dải 7 ngày trống với dấu ·
                for (i in 0 until 7) {
                    val countId = getCountViewId(i)
                    views.setTextViewText(countId, "\u00B7")
                    views.setTextColor(countId, if (isDark) Color.parseColor("#888780") else Color.parseColor("#888780"))
                    views.setInt(countId, "setBackgroundResource", 0)
                }

                views.setViewVisibility(R.id.widget_weekly_list, View.GONE)
                views.setViewVisibility(R.id.widget_weekly_empty_container, View.VISIBLE)
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

            // Đếm số môn từng ngày trong tuần
            val countPerDay = IntArray(7)
            val dayCal = mondayCal.clone() as Calendar

            for (i in 0 until 7) {
                val dYear = dayCal.get(Calendar.YEAR)
                val dMonth = dayCal.get(Calendar.MONTH)
                val dDay = dayCal.get(Calendar.DAY_OF_MONTH)

                var count = 0
                for (s in allSessions) {
                    val sCal = Calendar.getInstance(vnTz, Locale.US).apply { timeInMillis = s.startMs }
                    if (sCal.get(Calendar.YEAR) == dYear &&
                        sCal.get(Calendar.MONTH) == dMonth &&
                        sCal.get(Calendar.DAY_OF_MONTH) == dDay) {
                        count++
                    }
                }
                countPerDay[i] = count

                val countId = getCountViewId(i)
                val isToday = (dYear == todayYear && dMonth == todayMonth && dDay == todayDay)

                if (isToday) {
                    views.setTextViewText(countId, if (count > 0) count.toString() else "\u00B7")
                    views.setInt(countId, "setBackgroundResource", R.drawable.widget_weekly_pill_accent)
                    views.setTextColor(countId, if (isDark) Color.parseColor("#042C53") else Color.parseColor("#FFFFFF"))
                } else {
                    views.setInt(countId, "setBackgroundResource", 0)
                    if (count > 0) {
                        views.setTextViewText(countId, count.toString())
                        views.setTextColor(countId, if (isDark) Color.parseColor("#F1EFE8") else Color.parseColor("#1F1F1E"))
                    } else {
                        views.setTextViewText(countId, "\u00B7")
                        views.setTextColor(countId, Color.parseColor("#888780"))
                    }
                }

                dayCal.add(Calendar.DAY_OF_MONTH, 1)
            }

            // Gán RemoteAdapter cho ListView cuộn được
            val serviceIntent = Intent(context, WeeklyRemoteViewsService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                putExtra("week_offset", weekOffset)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.widget_weekly_list, serviceIntent)
            appWidgetManager.notifyAppWidgetViewDataChanged(appWidgetId, R.id.widget_weekly_list)

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

            appWidgetManager.updateAppWidget(appWidgetId, views)
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
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC, nextTriggerMs, pendingIntent)
                } else {
                    alarmManager.set(AlarmManager.RTC, nextTriggerMs, pendingIntent)
                }
            } catch (e: Exception) {
                // Ignore security exceptions
            }
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
        data class DayHeader(val title: String, val dateIso: String, val isToday: Boolean) : ListItem()
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

    // Bảng 8 màu Text/Bar chuẩn
    private val subjectColorsLight = intArrayOf(
        Color.parseColor("#0C447C"), // 0
        Color.parseColor("#27500A"), // 1
        Color.parseColor("#3C3489"), // 2
        Color.parseColor("#633806"), // 3
        Color.parseColor("#085041"), // 4
        Color.parseColor("#72243E"), // 5
        Color.parseColor("#712B13"), // 6
        Color.parseColor("#444441")  // 7
    )

    private val subjectColorsDark = intArrayOf(
        Color.parseColor("#B5D4F4"), // 0
        Color.parseColor("#C0DD97"), // 1
        Color.parseColor("#CECBF6"), // 2
        Color.parseColor("#FAC775"), // 3
        Color.parseColor("#9FE1CB"), // 4
        Color.parseColor("#F4C0D1"), // 5
        Color.parseColor("#F5C4B3"), // 6
        Color.parseColor("#D3D1C7")  // 7
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

        // Tạo items xen kẽ nhóm ngày và gộp ngày trống
        var emptyStart = -1

        fun flushEmpty(currentIdx: Int) {
            if (emptyStart != -1) {
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

                val wkStr = WeeklyScheduleWidgetProvider.WEEKDAY_LABELS[i]
                val headerTitle = if (isToday) {
                    "Hôm nay \u00B7 $wkStr " + dayMonthFormat.format(dDate)
                } else {
                    "$wkStr " + dayMonthFormat.format(dDate)
                }
                val dateIso = isoFormat.format(dDate)

                items.add(ListItem.DayHeader(headerTitle, dateIso, isToday))

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
        val isDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

        return when (item) {
            is ListItem.DayHeader -> {
                val rv = RemoteViews(context.packageName, R.layout.widget_weekly_item_header)
                rv.setTextViewText(R.id.item_header_text, item.title)
                if (item.isToday) {
                    rv.setTextColor(R.id.item_header_text, if (isDark) Color.parseColor("#85B7EB") else Color.parseColor("#185FA5"))
                } else {
                    rv.setTextColor(R.id.item_header_text, if (isDark) Color.parseColor("#F1EFE8") else Color.parseColor("#1F1F1E"))
                }
                val fillIntent = Intent().apply {
                    data = Uri.parse("tramkien://schedule?date=${item.dateIso}")
                }
                rv.setOnClickFillInIntent(R.id.widget_weekly_item_root, fillIntent)
                rv
            }
            is ListItem.SessionRow -> {
                val rv = RemoteViews(context.packageName, R.layout.widget_weekly_item_session)
                rv.setTextViewText(R.id.item_session_time, item.timeStr)
                rv.setTextViewText(R.id.item_session_title, item.displayTitle)
                rv.setTextViewText(R.id.item_session_room, item.roomStr)

                // Cài đặt màu vạch và chữ
                if (item.isToday && item.isPast) {
                    // Môn đã qua của hôm nay: thanh màu xám, toàn hàng chuyển màu mờ #888780
                    val grayBar = if (isDark) Color.parseColor("#444441") else Color.parseColor("#D3D1C7")
                    rv.setInt(R.id.item_color_bar, "setColorFilter", grayBar)
                    val textDimmed = Color.parseColor("#888780")
                    rv.setTextColor(R.id.item_session_time, textDimmed)
                    rv.setTextColor(R.id.item_session_title, textDimmed)
                    rv.setTextColor(R.id.item_session_room, textDimmed)
                } else if (item.isExam) {
                    // Môn thi: Vạch màu đỏ, chữ đậm vừa, tiền tố "Thi "
                    rv.setInt(R.id.item_color_bar, "setColorFilter", Color.parseColor("#E24B4A"))
                    rv.setTextColor(R.id.item_session_time, if (isDark) Color.parseColor("#B4B2A9") else Color.parseColor("#5F5E5A"))
                    rv.setTextColor(R.id.item_session_title, if (isDark) Color.parseColor("#F7C1C1") else Color.parseColor("#791F1F"))
                    rv.setTextColor(R.id.item_session_room, if (isDark) Color.parseColor("#B4B2A9") else Color.parseColor("#5F5E5A"))
                } else {
                    // Môn học thường: 8 màu theo colorIndex
                    val palette = if (isDark) subjectColorsDark else subjectColorsLight
                    val safeIdx = item.colorIndex.coerceIn(0, 7)
                    rv.setInt(R.id.item_color_bar, "setColorFilter", palette[safeIdx])
                    rv.setTextColor(R.id.item_session_time, if (isDark) Color.parseColor("#B4B2A9") else Color.parseColor("#5F5E5A"))
                    rv.setTextColor(R.id.item_session_title, if (isDark) Color.parseColor("#F1EFE8") else Color.parseColor("#1F1F1E"))
                    rv.setTextColor(R.id.item_session_room, if (isDark) Color.parseColor("#B4B2A9") else Color.parseColor("#5F5E5A"))
                }

                val fillIntent = Intent().apply {
                    data = Uri.parse("tramkien://schedule?date=${item.dateIso}&sessionId=${item.session.id}")
                }
                rv.setOnClickFillInIntent(R.id.widget_weekly_item_root, fillIntent)
                rv
            }
            is ListItem.MergedEmptyDays -> {
                val rv = RemoteViews(context.packageName, R.layout.widget_weekly_item_empty)
                rv.setTextViewText(R.id.item_empty_text, item.title)
                rv.setTextColor(R.id.item_empty_text, Color.parseColor("#888780"))
                val fillIntent = Intent().apply {
                    data = Uri.parse("tramkien://schedule?date=${item.dateIso}")
                }
                rv.setOnClickFillInIntent(R.id.widget_weekly_item_root, fillIntent)
                rv
            }
        }
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 3

    override fun getItemId(position: Int): Long = position.toLong()

    override fun hasStableIds(): Boolean = true
}
