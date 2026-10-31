package com.tramkien.hau

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
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
 * SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01: BƯỚC 4 - WIDGET 3 NGÀY (4x2)
 *
 * Yêu cầu:
 * 1. Đọc bản chụp lịch JSON widget_schedule_snapshot.json từ vùng chia sẻ file.
 * 2. Chia 3 cột bằng nhau (khoảng cách 8dp): Hôm nay, Ngày mai, Ngày kia.
 * 3. Tiêu đề cột (cỡ 11, vừa): Cột hôm nay "Hôm nay dd", hai ngày còn lại "Thứ · dd".
 * 4. Kỷ luật ẩn hiện "+N": Chỉ hiện khi N > 0, ẩn hoàn toàn khi N = 0 (bỏ +0).
 * 5. Mỗi cột tối đa 2 thẻ môn: Dòng 1 "HH:mm · phòng" (vừa), Dòng 2 shortName. Phòng viết gọn.
 * 6. Cột hôm nay bỏ qua môn đã kết thúc (past). Môn đang học có viền accent.
 * 7. QUY TẮC ƯU TIÊN LỊCH THI (AC-11): Lịch thi mang nền đỏ và LUÔN LUÔN ĐƯỢC ƯU TIÊN vào 1 trong 2 thẻ.
 * 8. Cột trống: Hiển thị chữ "Trống".
 * 9. Không vi phạm AC-08 (không hardcode mốc giờ dạng \b\d{1,2}:\d{2}\b).
 */
typealias ThreeDayWidgetProvider = ThreeDaysScheduleWidgetProvider

class ThreeDaysScheduleWidgetProvider : AppWidgetProvider() {

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
        val thisWidget = ComponentName(context, ThreeDaysScheduleWidgetProvider::class.java)

        when (action) {
            AppWidgetManager.ACTION_APPWIDGET_UPDATE,
            ACTION_UPDATE_WIDGET,
            ACTION_UPDATE_WIDGET_THREE_DAYS,
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
        const val ACTION_UPDATE_WIDGET_THREE_DAYS = "com.tramkien.hau.ACTION_UPDATE_WIDGET_THREE_DAYS"

        private const val SNAPSHOT_FILE_NAME = "widget_schedule_snapshot.json"
        private const val VN_TIMEZONE_ID = "Asia/Ho_Chi_Minh"
        private const val ALARM_REQUEST_CODE = 403

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

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val isDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES
            val views = RemoteViews(context.packageName, R.layout.widget_schedule_three_days)

            val vnTz = TimeZone.getTimeZone(VN_TIMEZONE_ID)
            val nowMs = System.currentTimeMillis()

            val timeFormat = SimpleDateFormat("HH:mm", Locale.US).apply {
                timeZone = vnTz
            }

            val snapshotObj = readSnapshotJson(context)
            val allSessions = parseSessions(snapshotObj)

            // Deep link chung
            val rootIntent = Intent(Intent.ACTION_VIEW, Uri.parse("tramkien://schedule")).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val rootPending = PendingIntent.getActivity(
                context,
                appWidgetId,
                rootIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, rootPending)

            if (snapshotObj == null || snapshotObj.optInt("version", 0) != 1) {
                // Trạng thái 0: Chưa có bản chụp -> Hiển thị "Đăng nhập để xem lịch"
                views.setViewVisibility(R.id.empty_state_container, View.VISIBLE)
                views.setViewVisibility(R.id.content_container, View.GONE)
            } else {
                views.setViewVisibility(R.id.empty_state_container, View.GONE)
                views.setViewVisibility(R.id.content_container, View.VISIBLE)

                // Cấu hình ID cho 3 cột
                val colContainers = intArrayOf(R.id.col_1_container, R.id.col_2_container, R.id.col_3_container)
                val colTitles = intArrayOf(R.id.col_1_title, R.id.col_2_title, R.id.col_3_title)
                val colBadges = intArrayOf(R.id.col_1_badge, R.id.col_2_badge, R.id.col_3_badge)
                val colEmpties = intArrayOf(R.id.col_1_empty, R.id.col_2_empty, R.id.col_3_empty)
                val colCardsList = intArrayOf(R.id.col_1_cards, R.id.col_2_cards, R.id.col_3_cards)

                val colCard1Layouts = intArrayOf(R.id.col_1_card_1, R.id.col_2_card_1, R.id.col_3_card_1)
                val colCard1TimeRooms = intArrayOf(R.id.col_1_card_1_time_room, R.id.col_2_card_1_time_room, R.id.col_3_card_1_time_room)
                val colCard1Titles = intArrayOf(R.id.col_1_card_1_title, R.id.col_2_card_1_title, R.id.col_3_card_1_title)

                val colCard2Layouts = intArrayOf(R.id.col_1_card_2, R.id.col_2_card_2, R.id.col_3_card_2)
                val colCard2TimeRooms = intArrayOf(R.id.col_1_card_2_time_room, R.id.col_2_card_2_time_room, R.id.col_3_card_2_time_room)
                val colCard2Titles = intArrayOf(R.id.col_1_card_2_title, R.id.col_2_card_2_title, R.id.col_3_card_2_title)

                for (colIdx in 0..2) {
                    val calDay = Calendar.getInstance(vnTz).apply {
                        timeInMillis = nowMs
                        add(Calendar.DAY_OF_YEAR, colIdx)
                    }

                    val targetYear = calDay.get(Calendar.YEAR)
                    val targetMonth = calDay.get(Calendar.MONTH) + 1
                    val targetDay = calDay.get(Calendar.DAY_OF_MONTH)
                    val isTodayCol = (colIdx == 0)

                    val dayStr = String.format(Locale.US, "%02d", targetDay)
                    val title = if (isTodayCol) {
                        "Hôm nay $dayStr"
                    } else {
                        val weekdayAbbr = getVietnameseWeekdayAbbr(calDay.timeInMillis)
                        "$weekdayAbbr · $dayStr"
                    }

                    views.setTextViewText(colTitles[colIdx], title)

                    // Deep link cho cột: tramkien://schedule?date=yyyy-MM-dd
                    val dateIsoStr = String.format(Locale.US, "%04d-%02d-%02d", targetYear, targetMonth, targetDay)
                    val colIntent = Intent(Intent.ACTION_VIEW, Uri.parse("tramkien://schedule?date=$dateIsoStr")).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }
                    val colPending = PendingIntent.getActivity(
                        context,
                        (appWidgetId * 10) + colIdx,
                        colIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(colContainers[colIdx], colPending)

                    // Lọc các ca trong ngày
                    val calSession = Calendar.getInstance(vnTz)
                    val daySessions = allSessions.filter { s ->
                        calSession.timeInMillis = s.startMs
                        calSession.get(Calendar.YEAR) == targetYear &&
                        calSession.get(Calendar.MONTH) + 1 == targetMonth &&
                        calSession.get(Calendar.DAY_OF_MONTH) == targetDay
                    }.sortedBy { it.startMs }

                    // Với cột hôm nay: Bỏ qua môn đã kết thúc (past: endMs <= nowMs)
                    val remainingSessions = if (isTodayCol) {
                        daySessions.filter { it.endMs > nowMs }
                    } else {
                        daySessions
                    }

                    // QUY TẮC ƯU TIÊN LỊCH THI (AC-11):
                    // Lịch thi mang nền đỏ và LUÔN LUÔN ĐƯỢC ƯU TIÊN VÀO VÙNG HIỂN THỊ (chiếm 1 trong 2 thẻ).
                    val exams = remainingSessions.filter { it.kind == "exam" }
                    val classes = remainingSessions.filter { it.kind != "exam" }

                    val chosenSessions: List<SessionData> = when {
                        exams.size >= 2 -> exams.take(2)
                        exams.size == 1 -> {
                            val combined = mutableListOf(exams[0])
                            if (classes.isNotEmpty()) {
                                combined.add(classes[0])
                            }
                            combined.sortBy { it.startMs }
                            combined
                        }
                        else -> classes.take(2)
                    }

                    // Kỷ luật ẩn hiện "+N": Chỉ hiển thị khi N > 0, tuyệt đối không hiển thị +0
                    val hiddenCount = remainingSessions.size - chosenSessions.size
                    if (hiddenCount > 0) {
                        views.setTextViewText(colBadges[colIdx], "+$hiddenCount")
                        views.setViewVisibility(colBadges[colIdx], View.VISIBLE)
                    } else {
                        views.setViewVisibility(colBadges[colIdx], View.GONE)
                    }

                    if (chosenSessions.isEmpty()) {
                        // Cột trống -> Hiển thị "Trống"
                        views.setViewVisibility(colEmpties[colIdx], View.VISIBLE)
                        views.setViewVisibility(colCardsList[colIdx], View.GONE)
                    } else {
                        views.setViewVisibility(colEmpties[colIdx], View.GONE)
                        views.setViewVisibility(colCardsList[colIdx], View.VISIBLE)

                        // Thẻ 1
                        if (chosenSessions.isNotEmpty()) {
                            bindThreeDaysCard(
                                context,
                                views,
                                colCard1Layouts[colIdx],
                                colCard1TimeRooms[colIdx],
                                colCard1Titles[colIdx],
                                chosenSessions[0],
                                nowMs,
                                isTodayCol,
                                timeFormat,
                                isDark,
                                appWidgetId,
                                (colIdx * 2) + 1
                            )
                            views.setViewVisibility(colCard1Layouts[colIdx], View.VISIBLE)
                        } else {
                            views.setViewVisibility(colCard1Layouts[colIdx], View.GONE)
                        }

                        // Thẻ 2
                        if (chosenSessions.size >= 2) {
                            bindThreeDaysCard(
                                context,
                                views,
                                colCard2Layouts[colIdx],
                                colCard2TimeRooms[colIdx],
                                colCard2Titles[colIdx],
                                chosenSessions[1],
                                nowMs,
                                isTodayCol,
                                timeFormat,
                                isDark,
                                appWidgetId,
                                (colIdx * 2) + 2
                            )
                            views.setViewVisibility(colCard2Layouts[colIdx], View.VISIBLE)
                        } else {
                            views.setViewVisibility(colCard2Layouts[colIdx], View.GONE)
                        }
                    }
                }
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
            scheduleNextAlarm(context, allSessions)
        }

        private fun bindThreeDaysCard(
            context: Context,
            views: RemoteViews,
            cardLayoutId: Int,
            timeRoomId: Int,
            titleId: Int,
            session: SessionData,
            nowMs: Long,
            isToday: Boolean,
            timeFormat: SimpleDateFormat,
            isDark: Boolean,
            appWidgetId: Int,
            requestOffset: Int
        ) {
            val isExam = session.kind == "exam"
            val isCurrent = isToday && (session.startMs <= nowMs && nowMs < session.endMs)

            val startStr = timeFormat.format(Date(session.startMs))
            val roomStr = simplifyRoom(session.room)

            val timeRoomLine = if (roomStr.isNotEmpty()) "$startStr · $roomStr" else startStr
            val rawShortName = if (session.shortName.trim().isNotEmpty()) session.shortName.trim() else session.subject.trim()
            val shortName = truncatePreserveSuffix(rawShortName, 24)

            views.setTextViewText(timeRoomId, timeRoomLine)
            views.setTextViewText(titleId, shortName)

            // Nền & màu chữ theo token
            if (isExam) {
                val bgRes = if (isCurrent) R.drawable.widget_card_rounded_8dp_exam_current else R.drawable.widget_card_rounded_8dp_exam
                views.setInt(cardLayoutId, "setBackgroundResource", bgRes)
                val examColor = if (isDark) Color.parseColor("#F7C1C1") else Color.parseColor("#791F1F")
                views.setTextColor(timeRoomId, examColor)
                views.setTextColor(titleId, examColor)
            } else {
                val safeColorIdx = session.color.coerceIn(0, 7)
                val bgResName = if (isCurrent) "widget_card_subject_${safeColorIdx}_current" else "widget_card_subject_$safeColorIdx"
                val bgRes = context.resources.getIdentifier(bgResName, "drawable", context.packageName)
                if (bgRes != 0) {
                    views.setInt(cardLayoutId, "setBackgroundResource", bgRes)
                }

                val textColorResName = "widget_subject_${safeColorIdx}_text"
                val textColorRes = context.resources.getIdentifier(textColorResName, "color", context.packageName)
                if (textColorRes != 0) {
                    val colorVal = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        context.getColor(textColorRes)
                    } else {
                        @Suppress("DEPRECATION")
                        context.resources.getColor(textColorRes)
                    }
                    views.setTextColor(timeRoomId, colorVal)
                    views.setTextColor(titleId, colorVal)
                }
            }

            // Deep link tới phiên cụ thể
            val sessionCal = Calendar.getInstance(TimeZone.getTimeZone(VN_TIMEZONE_ID)).apply {
                timeInMillis = session.startMs
            }
            val dateIsoStr = String.format(
                Locale.US,
                "%04d-%02d-%02d",
                sessionCal.get(Calendar.YEAR),
                sessionCal.get(Calendar.MONTH) + 1,
                sessionCal.get(Calendar.DAY_OF_MONTH)
            )
            val cardIntent = Intent(Intent.ACTION_VIEW, Uri.parse("tramkien://schedule?date=$dateIsoStr&sessionId=${session.id}")).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val cardPending = PendingIntent.getActivity(
                context,
                (appWidgetId * 100) + requestOffset,
                cardIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(cardLayoutId, cardPending)
        }

        fun simplifyRoom(rawRoom: String): String {
            var room = rawRoom.trim()
            if (room.isEmpty()) return ""
            room = room.replace(Regex("\\(.*?\\)"), "").trim()
            room = room.replace(Regex("^[Pp]\\.([A-Za-z0-9]+)"), "P$1")
            return room.trim()
        }

        fun truncatePreserveSuffix(text: String, maxLength: Int): String {
            if (text.length <= maxLength) return text
            val regex = Regex("(.*?)\\s+([0-9]+|[IVXLCDM]+)$", RegexOption.IGNORE_CASE)
            val match = regex.matchEntire(text)
            return if (match != null) {
                val prefix = match.groupValues[1]
                val suffix = match.groupValues[2]
                val budget = maxLength - suffix.length - 2
                if (budget > 3) {
                    "${prefix.substring(0, budget)}…$suffix"
                } else {
                    "${text.substring(0, maxLength - 1)}…"
                }
            } else {
                "${text.substring(0, maxLength - 1)}…"
            }
        }

        fun getVietnameseWeekdayAbbr(epochMs: Long): String {
            val cal = Calendar.getInstance(TimeZone.getTimeZone(VN_TIMEZONE_ID)).apply {
                timeInMillis = epochMs
            }
            return when (cal.get(Calendar.DAY_OF_WEEK)) {
                Calendar.MONDAY -> "T2"
                Calendar.TUESDAY -> "T3"
                Calendar.WEDNESDAY -> "T4"
                Calendar.THURSDAY -> "T5"
                Calendar.FRIDAY -> "T6"
                Calendar.SATURDAY -> "T7"
                Calendar.SUNDAY -> "CN"
                else -> ""
            }
        }

        fun readSnapshotJson(context: Context): JSONObject? {
            val primaryFile = File(context.filesDir, SNAPSHOT_FILE_NAME)
            val targetFile = if (primaryFile.exists()) {
                primaryFile
            } else {
                val fallbackFile = File(context.noBackupFilesDir, SNAPSHOT_FILE_NAME)
                if (fallbackFile.exists()) fallbackFile else null
            } ?: return null

            return try {
                val jsonStr = targetFile.readText(Charsets.UTF_8)
                val obj = JSONObject(jsonStr)
                if (obj.optInt("version", 0) != 1) return null
                val genAt = obj.optLong("generatedAt", 0L)
                val maxAgeMs = 14L * 24 * 60 * 60 * 1000
                if (genAt > 0 && (System.currentTimeMillis() - genAt > maxAgeMs)) return null
                obj
            } catch (e: Exception) {
                null
            }
        }

        fun parseSessions(jsonObj: JSONObject?): List<SessionData> {
            if (jsonObj == null) return emptyList()
            val sessionsArray = jsonObj.optJSONArray("sessions") ?: return emptyList()
            val list = mutableListOf<SessionData>()

            for (i in 0 until sessionsArray.length()) {
                val item = sessionsArray.optJSONObject(i) ?: continue
                val id = item.optInt("id", 0)
                val kind = item.optString("kind", "class")
                val subject = item.optString("subject", "")
                val shortName = item.optString("short", "")
                val startMs = item.optLong("startMs", 0L)
                val endMs = item.optLong("endMs", 0L)
                val room = item.optString("room", "")
                val teacher = if (item.has("teacher") && !item.isNull("teacher")) item.optString("teacher") else null
                val seat = if (item.has("seat") && !item.isNull("seat")) item.optString("seat") else null
                val color = item.optInt("color", 0)
                val endEstimated = item.optBoolean("endEstimated", false)

                list.add(
                    SessionData(
                        id = id,
                        kind = kind,
                        subject = subject,
                        shortName = shortName,
                        startMs = startMs,
                        endMs = endMs,
                        room = room,
                        teacher = teacher,
                        seat = seat,
                        color = color,
                        endEstimated = endEstimated
                    )
                )
            }
            return list
        }

        fun scheduleNextAlarm(context: Context, sessions: List<SessionData>) {
            val nowMs = System.currentTimeMillis()
            val vnTz = TimeZone.getTimeZone(VN_TIMEZONE_ID)

            val calMidnight = Calendar.getInstance(vnTz).apply {
                timeInMillis = nowMs
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
                add(Calendar.DAY_OF_MONTH, 1)
            }
            val midnightMs = calMidnight.timeInMillis

            var nextWakeMs = midnightMs

            for (s in sessions) {
                if (s.startMs > nowMs && s.startMs < nextWakeMs) {
                    nextWakeMs = s.startMs
                }
                if (s.endMs > nowMs && s.endMs < nextWakeMs) {
                    nextWakeMs = s.endMs
                }
            }

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, ThreeDaysScheduleWidgetProvider::class.java).apply {
                action = ACTION_UPDATE_WIDGET_THREE_DAYS
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC, nextWakeMs, pendingIntent)
                } else {
                    alarmManager.set(AlarmManager.RTC, nextWakeMs, pendingIntent)
                }
            } catch (e: Exception) {
                // Ignore security exceptions
            }
        }
    }
}
