package com.tramkien.hau

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.UiModeManager
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Configuration
import android.content.res.Resources
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.TimeZone

/**
 * SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01: BƯỚC 3 - WIDGET THÁNG + HÔM NAY (4x2)
 *
 * Yêu cầu:
 * 1. Đọc bản chụp lịch JSON widget_schedule_snapshot.json từ vùng chia sẻ file.
 * 2. Nửa trái: Lưới tháng 7 cột x 6 hàng, nút chuyển tháng ‹ ›, hôm nay nền tròn accent,
 *    chấm học màu phụ 3dp, chấm đỏ thi 3dp. Hôm nay có thi: chấm đỏ nằm DƯỚI vòng tròn accent.
 * 3. Nửa phải: Header "Thứ, dd/MM" và "N môn", tối đa 2 thẻ môn (mỗi thẻ 2 dòng).
 *    ƯU TIÊN LỊCH THI: Lịch thi chưa diễn ra trong ngày LUÔN ĐƯỢC ƯU TIÊN vào 1 trong 2 thẻ.
 *    Footer "+N môn nữa" nếu N > 0.
 * 4. Nút ‹ ›: Lưu monthOffset trong shared storage, tự động reset về tháng hiện tại lúc 00:00.
 * 5. Tuân thủ AC-08 (không hardcode mốc giờ dạng \\b\\d{1,2}:\\d{2}\\b).
 */
typealias MonthWidgetProvider = MonthToday4x2ScheduleWidgetProvider

class MonthToday4x2ScheduleWidgetProvider : AppWidgetProvider() {

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
        val thisWidget = ComponentName(context, MonthToday4x2ScheduleWidgetProvider::class.java)

        when (action) {
            ACTION_MONTH_PREV, ACTION_MONTH_NEXT -> {
                // Đã lược bỏ tính năng chuyển tháng theo yêu cầu người dùng
            }
            Intent.ACTION_DATE_CHANGED, Intent.ACTION_TIMEZONE_CHANGED -> {
                // Tự động reset monthOffset về 0 khi sang ngày mới lúc 00:00
                resetAllMonthOffsets(context)
                val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
                for (id in appWidgetIds) {
                    updateAppWidget(context, appWidgetManager, id)
                }
            }
            AppWidgetManager.ACTION_APPWIDGET_UPDATE,
            ACTION_UPDATE_WIDGET,
            ACTION_UPDATE_WIDGET_COMMON,
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
        const val ACTION_UPDATE_WIDGET = "com.tramkien.hau.ACTION_UPDATE_WIDGET_MONTH_TODAY"
        const val ACTION_UPDATE_WIDGET_COMMON = "com.tramkien.hau.ACTION_UPDATE_WIDGET"
        const val ACTION_MONTH_PREV = "com.tramkien.hau.ACTION_MONTH_PREV"
        const val ACTION_MONTH_NEXT = "com.tramkien.hau.ACTION_MONTH_NEXT"

        private const val PREFS_NAME = "widget_month_today_prefs"
        private const val KEY_MONTH_OFFSET_PREFIX = "month_offset_"
        private const val SNAPSHOT_FILE_NAME = "widget_schedule_snapshot.json"
        private const val VN_TIMEZONE_ID = "Asia/Ho_Chi_Minh"
        private const val ALARM_REQUEST_CODE = 402

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

        fun getMonthOffset(context: Context, appWidgetId: Int): Int {
            return 0
        }

        fun setMonthOffset(context: Context, appWidgetId: Int, offset: Int) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().putInt("$KEY_MONTH_OFFSET_PREFIX$appWidgetId", offset).apply()
        }

        fun resetAllMonthOffsets(context: Context) {
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().clear().apply()
        }

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

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_schedule_month_today_4x2)
            val nowMs = System.currentTimeMillis()
            val vnTz = TimeZone.getTimeZone(VN_TIMEZONE_ID)
            val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault()).apply { timeZone = vnTz }
            val dateFormatIso = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).apply { timeZone = vnTz }
            val dateFormatDdMm = SimpleDateFormat("dd/MM", Locale.getDefault()).apply { timeZone = vnTz }

            val isDark = isSystemDarkMode(context)
            val textPrimary = if (isDark) Color.parseColor("#FFFFFF") else Color.parseColor("#1F1F1E")
            val textSecondary = if (isDark) Color.parseColor("#D3D1C7") else Color.parseColor("#5F5E5A")
            val textDimmed = if (isDark) Color.parseColor("#A8A69E") else Color.parseColor("#888780")
            val accentOn = if (isDark) Color.parseColor("#042C53") else Color.parseColor("#FFFFFF")

            // Luôn hiển thị tháng hiện tại (offset = 0)

            // Deep link chung khi tap vào widget
            val rootIntent = Intent(Intent.ACTION_VIEW, Uri.parse("tramkien://schedule")).apply {
                setClass(context, MainActivity::class.java)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val rootPending = PendingIntent.getActivity(
                context,
                appWidgetId,
                rootIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, rootPending)
            views.setOnClickPendingIntent(R.id.today_empty_container, rootPending)
            views.setOnClickPendingIntent(R.id.today_empty_title, rootPending)
            views.setOnClickPendingIntent(R.id.today_empty_subtitle, rootPending)
            views.setOnClickPendingIntent(R.id.today_header_date, rootPending)
            views.setOnClickPendingIntent(R.id.today_header_count, rootPending)

            // Đọc snapshot
            val snapshotObj = readSnapshotJson(context)
            val allSessions = if (snapshotObj != null && snapshotObj.optInt("version", 0) == 1) {
                parseSessions(snapshotObj)
            } else {
                emptyList()
            }

            val monthOffset = getMonthOffset(context, appWidgetId)

            // ==================== NỬA TRÁI: LƯỚI THÁNG ====================
            val calTarget = Calendar.getInstance(vnTz).apply {
                timeInMillis = nowMs
                add(Calendar.MONTH, monthOffset)
                set(Calendar.DAY_OF_MONTH, 1)
            }
            val targetYear = calTarget.get(Calendar.YEAR)
            val targetMonth = calTarget.get(Calendar.MONTH) + 1 // 1..12
            val daysInMonth = calTarget.getActualMaximum(Calendar.DAY_OF_MONTH)

            views.setTextViewText(R.id.month_title, "Tháng $targetMonth/$targetYear")

            // Weekday bắt đầu từ Thứ Hai: Calendar.MONDAY = 2, SUNDAY = 1
            val firstDayDow = calTarget.get(Calendar.DAY_OF_WEEK)
            val emptyLeading = if (firstDayDow == Calendar.SUNDAY) 6 else firstDayDow - Calendar.MONDAY

            val calNow = Calendar.getInstance(vnTz).apply { timeInMillis = nowMs }
            val nowYear = calNow.get(Calendar.YEAR)
            val nowMonth = calNow.get(Calendar.MONTH) + 1
            val nowDay = calNow.get(Calendar.DAY_OF_MONTH)

            // Duyệt 6 hàng x 7 cột = 42 ô
            for (idx in 0 until 42) {
                val r = idx / 7
                val c = idx % 7
                val cellId = context.resources.getIdentifier("cell_${r}_${c}", "id", context.packageName)
                val textId = context.resources.getIdentifier("cell_text_${r}_${c}", "id", context.packageName)
                val todayTextId = context.resources.getIdentifier("cell_today_text_${r}_${c}", "id", context.packageName)
                val dotId = context.resources.getIdentifier("cell_dot_${r}_${c}", "id", context.packageName)

                if (idx < emptyLeading || idx >= emptyLeading + daysInMonth) {
                    // Ô trống ngoài tháng
                    views.setTextViewText(textId, "")
                    views.setViewVisibility(textId, View.VISIBLE)
                    views.setViewVisibility(todayTextId, View.GONE)
                    views.setViewVisibility(dotId, View.GONE)
                    views.setOnClickPendingIntent(cellId, null)
                } else {
                    val d = idx - emptyLeading + 1
                    val isToday = (targetYear == nowYear && targetMonth == nowMonth && d == nowDay)

                    // Lọc buổi học / thi trong ngày d
                    var hasExam = false
                    var hasClass = false
                    val calDay = Calendar.getInstance(vnTz)

                    for (s in allSessions) {
                        calDay.timeInMillis = s.startMs
                        if (calDay.get(Calendar.YEAR) == targetYear &&
                            calDay.get(Calendar.MONTH) + 1 == targetMonth &&
                            calDay.get(Calendar.DAY_OF_MONTH) == d
                        ) {
                            if (s.kind == "exam") {
                                hasExam = true
                            } else {
                                hasClass = true
                            }
                        }
                    }

                    if (isToday) {
                        // Hôm nay: hiển thị ô tròn accent chuyên dụng (tự động nhận @color/widget_accent_on)
                        views.setViewVisibility(textId, View.GONE)
                        views.setViewVisibility(todayTextId, View.VISIBLE)
                        views.setTextViewText(todayTextId, "$d")

                        // NẾU hôm nay có lịch thi: vòng tròn accent kèm chấm đỏ nhỏ 3pt nằm phía DƯỚI vòng tròn (không nằm trong vòng tròn)
                        if (hasExam) {
                            views.setInt(dotId, "setImageResource", R.drawable.widget_month_dot_exam)
                            views.setViewVisibility(dotId, View.VISIBLE)
                        } else {
                            views.setViewVisibility(dotId, View.GONE)
                        }
                    } else {
                        // Ngày thường
                        views.setViewVisibility(textId, View.VISIBLE)
                        views.setViewVisibility(todayTextId, View.GONE)
                        views.setTextViewText(textId, "$d")

                        if (hasExam) {
                            // Chấm đỏ 3pt dưới số
                            views.setInt(dotId, "setImageResource", R.drawable.widget_month_dot_exam)
                            views.setViewVisibility(dotId, View.VISIBLE)
                        } else if (hasClass) {
                            // Chấm 3pt màu phụ dưới số
                            views.setInt(dotId, "setImageResource", R.drawable.widget_month_dot_study)
                            views.setViewVisibility(dotId, View.VISIBLE)
                        } else {
                            // Không có lịch: không chấm
                            views.setViewVisibility(dotId, View.GONE)
                        }
                    }

                    // Deep Link mở ngày đó: tramkien://schedule?date=yyyy-MM-dd
                    val dateIsoStr = String.format(Locale.US, "%04d-%02d-%02d", targetYear, targetMonth, d)
                    val dayIntent = Intent(Intent.ACTION_VIEW, Uri.parse("tramkien://schedule?date=$dateIsoStr")).apply {
                        setClass(context, MainActivity::class.java)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    val dayPending = PendingIntent.getActivity(
                        context,
                        (appWidgetId * 100) + d,
                        dayIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(cellId, dayPending)
                }
            }

            // ==================== NỬA PHẢI: LỊCH HÔM NAY ====================
            val dayOfWeekStr = getVietnameseWeekdayAbbr(nowMs)
            val ddMmStr = dateFormatDdMm.format(Date(nowMs))
            views.setTextViewText(R.id.today_header_date, "$dayOfWeekStr, $ddMmStr")

            if (snapshotObj == null || snapshotObj.optInt("version", 0) != 1) {
                // Trạng thái 0: Chưa có bản chụp -> "Đăng nhập để xem lịch"
                views.setTextViewText(R.id.today_header_count, "0 môn")
                views.setViewVisibility(R.id.today_cards_container, View.GONE)
                views.setViewVisibility(R.id.today_empty_container, View.VISIBLE)
                views.setTextViewText(R.id.today_empty_title, "Đăng nhập để xem lịch")
                views.setTextViewText(R.id.today_empty_subtitle, "")
            } else {
                val calNowDay = Calendar.getInstance(vnTz).apply { timeInMillis = nowMs }
                val todaySessions = allSessions.filter { s ->
                    val calS = Calendar.getInstance(vnTz).apply { timeInMillis = s.startMs }
                    calS.get(Calendar.YEAR) == nowYear &&
                    calS.get(Calendar.MONTH) + 1 == nowMonth &&
                    calS.get(Calendar.DAY_OF_MONTH) == nowDay
                }

                val totalCount = todaySessions.size
                views.setTextViewText(R.id.today_header_count, "$totalCount môn")

                // Môn chưa kết thúc trong ngày (endMs > nowMs)
                val remainingSessions = todaySessions.filter { it.endMs > nowMs }.sortedBy { it.startMs }

                if (remainingSessions.isEmpty()) {
                    views.setViewVisibility(R.id.today_cards_container, View.GONE)
                    views.setViewVisibility(R.id.today_empty_container, View.VISIBLE)

                    // Tìm ca tiếp theo trong 7 ngày tới
                    val deadlineMs = nowMs + 7 * 86400 * 1000L
                    val futureSessions = allSessions.filter { it.startMs > nowMs && it.startMs <= deadlineMs }.sortedBy { it.startMs }

                    val nextPreview = if (futureSessions.isNotEmpty()) {
                        val next = futureSessions[0]
                        val nextThu = getVietnameseWeekdayAbbr(next.startMs)
                        val nextTime = timeFormat.format(Date(next.startMs))
                        val roomStr = WeeklyScheduleWidgetProvider.simplifyRoom(next.room)
                        val roomPart = if (roomStr.isNotEmpty()) " · $roomStr" else ""
                        val nextName = next.subject.trim()
                        "Sắp tới: $nextThu $nextTime$roomPart\n$nextName"
                    } else {
                        "Không có lịch sắp tới"
                    }

                    if (todaySessions.isEmpty()) {
                        views.setTextViewText(R.id.today_empty_title, "Hôm nay không có lịch")
                    } else {
                        views.setTextViewText(R.id.today_empty_title, "Hôm nay đã xong $totalCount môn")
                    }
                    views.setTextViewText(R.id.today_empty_subtitle, nextPreview)
                } else {
                    views.setViewVisibility(R.id.today_empty_container, View.GONE)
                    views.setViewVisibility(R.id.today_cards_container, View.VISIBLE)

                    // ƯU TIÊN LỊCH THI: Lịch thi chưa diễn ra trong ngày LUÔN ĐƯỢC ƯU TIÊN đưa vào 1 trong 2 vị trí hiển thị (AC-11)
                    val exams = remainingSessions.filter { it.kind == "exam" }
                    val classes = remainingSessions.filter { it.kind != "exam" }

                    val chosenSessions: List<SessionData> = when {
                        exams.size >= 3 -> exams.take(3)
                        exams.size == 2 -> {
                            val combined = mutableListOf(exams[0], exams[1])
                            if (classes.isNotEmpty()) {
                                combined.add(classes[0])
                            }
                            combined.sortBy { it.startMs }
                            combined
                        }
                        exams.size == 1 -> {
                            val combined = mutableListOf(exams[0])
                            combined.addAll(classes.take(2))
                            combined.sortBy { it.startMs }
                            combined
                        }
                        else -> classes.take(3)
                    }

                    // Chọn DUY NHẤT 1 ca đang diễn ra (Single Active Session Arbiter)
                    // Ưu tiên lịch thi, sau đó tới ca bắt đầu sớm nhất
                    val activeSession = chosenSessions
                        .filter { it.startMs <= nowMs && nowMs < it.endMs }
                        .sortedWith(compareByDescending<SessionData> { it.kind == "exam" }.thenBy { it.startMs })
                        .firstOrNull()

                    // Card 1
                    if (chosenSessions.isNotEmpty()) {
                        bindCourseCard(context, views, R.id.today_card_1, R.id.card_1_time_room, R.id.card_1_title, chosenSessions[0], nowMs, timeFormat, isDark, chosenSessions[0].id == activeSession?.id)
                        views.setViewVisibility(R.id.today_card_1, View.VISIBLE)
                    } else {
                        views.setViewVisibility(R.id.today_card_1, View.GONE)
                    }

                    // Card 2
                    if (chosenSessions.size >= 2) {
                        bindCourseCard(context, views, R.id.today_card_2, R.id.card_2_time_room, R.id.card_2_title, chosenSessions[1], nowMs, timeFormat, isDark, chosenSessions[1].id == activeSession?.id)
                        views.setViewVisibility(R.id.today_card_2, View.VISIBLE)
                    } else {
                        views.setViewVisibility(R.id.today_card_2, View.GONE)
                    }

                    // Card 3
                    if (chosenSessions.size >= 3) {
                        bindCourseCard(context, views, R.id.today_card_3, R.id.card_3_time_room, R.id.card_3_title, chosenSessions[2], nowMs, timeFormat, isDark, chosenSessions[2].id == activeSession?.id)
                        views.setViewVisibility(R.id.today_card_3, View.VISIBLE)
                    } else {
                        views.setViewVisibility(R.id.today_card_3, View.GONE)
                    }

                    // Footer: 2 dòng tách biệt nếu có môn tràn hoặc môn đã qua
                    val overflowCount = remainingSessions.size - chosenSessions.size
                    val pastCount = todaySessions.size - remainingSessions.size

                    var hasFooter = false
                    if (overflowCount > 0) {
                        val overflowSessions = remainingSessions.drop(chosenSessions.size)
                        val nextOverflow = overflowSessions.firstOrNull()
                        val nextOverflowTime = if (nextOverflow != null) timeFormat.format(Date(nextOverflow.startMs)) else ""
                        val overflowText = if (nextOverflowTime.isNotEmpty()) {
                            "+$overflowCount môn nữa lúc $nextOverflowTime"
                        } else {
                            "+$overflowCount môn nữa"
                        }
                        views.setTextViewText(R.id.today_overflow_footer, overflowText)
                        views.setViewVisibility(R.id.today_overflow_footer, View.VISIBLE)
                        hasFooter = true
                    } else {
                        views.setViewVisibility(R.id.today_overflow_footer, View.GONE)
                    }

                    if (pastCount > 0) {
                        views.setTextViewText(R.id.today_overflow_done, "$pastCount môn đã xong")
                        views.setViewVisibility(R.id.today_overflow_done, View.VISIBLE)
                        hasFooter = true
                    } else {
                        views.setViewVisibility(R.id.today_overflow_done, View.GONE)
                    }

                    views.setViewVisibility(R.id.today_overflow_container, if (hasFooter) View.VISIBLE else View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
            scheduleNextAlarm(context, allSessions)
        }

        private fun bindCourseCard(
            context: Context,
            views: RemoteViews,
            cardLayoutId: Int,
            timeRoomId: Int,
            titleId: Int,
            session: SessionData,
            nowMs: Long,
            timeFormat: SimpleDateFormat,
            isDark: Boolean,
            isCurrent: Boolean
        ) {
            val isExam = session.kind == "exam"
            val startStr = timeFormat.format(Date(session.startMs))
            val roomStr = if (session.room.isNotEmpty()) session.room else "Chưa có phòng"

            val timeRoomLine = if (isExam) "$startStr · $roomStr · Thi" else "$startStr · $roomStr"
            val displayTitle = truncatePreserveSuffix(session.subject, 36)

            views.setTextViewText(timeRoomId, timeRoomLine)
            views.setTextViewText(titleId, displayTitle)

            // Màu thẻ & nền
            if (isExam) {
                val bgRes = if (isCurrent) R.drawable.widget_card_rounded_8dp_exam_current else R.drawable.widget_card_rounded_8dp_exam
                views.setInt(cardLayoutId, "setBackgroundResource", bgRes)
            } else {
                val safeColorIdx = session.color.coerceIn(0, 7)
                val bgResName = if (isCurrent) "widget_card_subject_${safeColorIdx}_current" else "widget_card_subject_$safeColorIdx"
                val bgRes = context.resources.getIdentifier(bgResName, "drawable", context.packageName)
                if (bgRes != 0) {
                    views.setInt(cardLayoutId, "setBackgroundResource", bgRes)
                }
            }

            // Deep link chi tiết môn học
            val vnTz = TimeZone.getTimeZone(VN_TIMEZONE_ID)
            val isoFormat = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).apply { timeZone = vnTz }
            val dateIso = isoFormat.format(Date(session.startMs))
            val deepLinkUri = Uri.parse("tramkien://schedule?date=$dateIso&sessionId=${session.id}")
            val clickIntent = Intent(Intent.ACTION_VIEW, deepLinkUri).apply {
                setClass(context, MainActivity::class.java)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pending = PendingIntent.getActivity(
                context,
                session.id + 1000,
                clickIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(cardLayoutId, pending)
        }

        private fun scheduleNextAlarm(context: Context, sessions: List<SessionData>) {
            val nowMs = System.currentTimeMillis()
            val vnTz = TimeZone.getTimeZone(VN_TIMEZONE_ID)
            val cal = Calendar.getInstance(vnTz).apply {
                timeInMillis = nowMs
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val midnightMs = cal.timeInMillis

            var nextTriggerMs: Long? = null
            for (s in sessions) {
                if (s.startMs > nowMs && (nextTriggerMs == null || s.startMs < nextTriggerMs)) {
                    nextTriggerMs = s.startMs
                }
                if (s.endMs > nowMs && (nextTriggerMs == null || s.endMs < nextTriggerMs)) {
                    nextTriggerMs = s.endMs
                }
            }

            val triggerMs = if (nextTriggerMs != null && nextTriggerMs < midnightMs) {
                nextTriggerMs
            } else {
                midnightMs
            }

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, MonthToday4x2ScheduleWidgetProvider::class.java).apply {
                action = ACTION_UPDATE_WIDGET
            }
            val pending = PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerMs, pending)
                } else {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, triggerMs, pending)
                }
            } catch (_: SecurityException) {
            }
        }

        private fun readSnapshotJson(context: Context): JSONObject? {
            val file = File(context.filesDir, SNAPSHOT_FILE_NAME)
            val candidate = if (file.exists()) file else File(context.noBackupFilesDir, SNAPSHOT_FILE_NAME)
            if (!candidate.exists()) return null
            return try {
                val text = candidate.readText()
                val obj = JSONObject(text)
                if (obj.optInt("version", 0) != 1) return null
                val genAt = obj.optLong("generatedAt", 0L)
                val maxAgeMs = 180L * 24 * 60 * 60 * 1000
                if (genAt > 0 && (System.currentTimeMillis() - genAt > maxAgeMs)) return null
                obj
            } catch (_: Exception) {
                null
            }
        }

        private fun parseSessions(obj: JSONObject): List<SessionData> {
            val arr = obj.optJSONArray("sessions") ?: return emptyList()
            val list = mutableListOf<SessionData>()
            for (i in 0 until arr.length()) {
                val item = arr.optJSONObject(i) ?: continue
                list.add(
                    SessionData(
                        id = item.optInt("id", i),
                        kind = item.optString("kind", "class"),
                        subject = item.optString("subject", ""),
                        shortName = item.optString("short", ""),
                        startMs = item.optLong("startMs", 0L),
                        endMs = item.optLong("endMs", 0L),
                        room = item.optString("room", ""),
                        teacher = if (item.isNull("teacher")) null else item.optString("teacher"),
                        seat = if (item.isNull("seat")) null else item.optString("seat"),
                        color = item.optInt("color", 0),
                        endEstimated = item.optBoolean("endEstimated", false)
                    )
                )
            }
            return list
        }

        fun getVietnameseWeekdayAbbr(epochMs: Long): String {
            val vnTz = TimeZone.getTimeZone(VN_TIMEZONE_ID)
            val cal = Calendar.getInstance(vnTz).apply { timeInMillis = epochMs }
            return when (cal.get(Calendar.DAY_OF_WEEK)) {
                Calendar.MONDAY -> "T2"
                Calendar.TUESDAY -> "T3"
                Calendar.WEDNESDAY -> "T4"
                Calendar.THURSDAY -> "T5"
                Calendar.FRIDAY -> "T6"
                Calendar.SATURDAY -> "T7"
                Calendar.SUNDAY -> "CN"
                else -> "CN"
            }
        }

        fun truncatePreserveSuffix(name: String, maxLength: Int): String {
            val trimmed = name.trim()
            if (trimmed.length <= maxLength) return trimmed

            val regex = Regex("(\\s+(?:[0-9]+|[IVXLCDM]+|[A-Za-z]))$")
            val match = regex.find(trimmed)
            if (match != null) {
                val suffix = match.value
                val budget = maxLength - 1 - suffix.length
                if (budget >= 6) {
                    val leftBudget = (budget * 0.55).toInt()
                    val rightBudget = budget - leftBudget
                    val leftPart = trimmed.substring(0, leftBudget).trimEnd()
                    val beforeSuffix = trimmed.substring(0, match.range.first)
                    val rightStart = beforeSuffix.length - rightBudget
                    val rightPart = if (rightStart > leftBudget) {
                        beforeSuffix.substring(rightStart).trimStart()
                    } else ""
                    return if (rightPart.isNotEmpty()) {
                        "$leftPart…$rightPart$suffix"
                    } else {
                        "$leftPart…$suffix"
                    }
                }
            }
            return "${trimmed.substring(0, (maxLength - 1).coerceAtLeast(1)).trimEnd()}…"
        }
    }
}
