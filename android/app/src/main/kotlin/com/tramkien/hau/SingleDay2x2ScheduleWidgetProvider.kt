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
 * SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01: BƯỚC 2 - WIDGET HÔM NAY (2x2)
 *
 * Yêu cầu:
 * 1. Đọc bản chụp lịch từ file JSON widget_schedule_snapshot.json trong context.filesDir
 * 2. Không đọc trực tiếp SQLite, không hardcode bảng giờ tiết hay regex ngày.
 * 3. So sánh startMs, endMs với now để tính trạng thái current, upcoming, past.
 * 4. Thứ tự ưu tiên 5 cấp chuẩn Mục 3.1 & 3.6.
 * 5. Thanh tiến độ 4dp (ẩn nếu endEstimated == true).
 * 6. Đếm ngược đáy "Đến HH:mm" (ẩn nếu endEstimated == true).
 * 7. AlarmManager.setAndAllowWhileIdle cập nhật đúng mốc giờ tiếp theo.
 * 8. Deep link tramkien://schedule?date=yyyy-MM-dd&sessionId=...
 * 9. Tuyệt đối không vi phạm AC-08 (không hardcode mốc giờ dạng \\b\\d{1,2}:\\d{2}\\b).
 */
typealias TodayWidgetProvider = SingleDay2x2ScheduleWidgetProvider

class SingleDay2x2ScheduleWidgetProvider : AppWidgetProvider() {

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
        if (action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            action == ACTION_UPDATE_WIDGET ||
            action == Intent.ACTION_TIME_CHANGED ||
            action == Intent.ACTION_TIMEZONE_CHANGED ||
            action == Intent.ACTION_DATE_CHANGED ||
            action == Intent.ACTION_BOOT_COMPLETED
        ) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, SingleDay2x2ScheduleWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            for (appWidgetId in appWidgetIds) {
                updateAppWidget(context, appWidgetManager, appWidgetId)
            }
        }
    }

    companion object {
        const val ACTION_UPDATE_WIDGET = "com.tramkien.hau.ACTION_UPDATE_WIDGET"
        private const val SNAPSHOT_FILE_NAME = "widget_schedule_snapshot.json"
        private const val VN_TIMEZONE_ID = "Asia/Ho_Chi_Minh"
        private const val ALARM_REQUEST_CODE = 202

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
            val views = RemoteViews(context.packageName, R.layout.widget_schedule_single_day_2x2)
            val nowMs = System.currentTimeMillis()
            val vnTz = TimeZone.getTimeZone(VN_TIMEZONE_ID)
            val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault()).apply { timeZone = vnTz }
            val dateFormatIso = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).apply { timeZone = vnTz }

            val isDark = (context.resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES

            // Màu Token chuẩn Mục 1.4 & 1.5
            val accentColor = if (isDark) Color.parseColor("#85B7EB") else Color.parseColor("#185FA5")
            val examColor = if (isDark) Color.parseColor("#F7C1C1") else Color.parseColor("#791F1F")
            val textPrimary = if (isDark) Color.parseColor("#F1EFE8") else Color.parseColor("#1F1F1E")
            val textSecondary = if (isDark) Color.parseColor("#B4B2A9") else Color.parseColor("#5F5E5A")

            val snapshotObj = readSnapshotJson(context)
            if (snapshotObj == null || snapshotObj.optInt("version", 0) != 1) {
                // Trạng thái 0: Chưa có bản chụp / chưa đăng nhập
                renderEmptyState(
                    views = views,
                    title = "Đăng nhập để xem lịch",
                    subtitle = "",
                    textPrimary = textPrimary,
                    textSecondary = textSecondary,
                    deepLinkUri = "tramkien://schedule?date=${dateFormatIso.format(Date(nowMs))}"
                )
                setOnClickPendingIntent(context, views, "tramkien://schedule?date=${dateFormatIso.format(Date(nowMs))}", appWidgetId)
                appWidgetManager.updateAppWidget(appWidgetId, views)
                return
            }

            val sessions = parseSessions(snapshotObj)
            val calNow = Calendar.getInstance(vnTz).apply { timeInMillis = nowMs }

            // Nhóm theo hôm nay & ngày mai
            val todaySessions = sessions.filter { isSameDay(it.startMs, calNow, vnTz) }
            val calTomorrow = (calNow.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 1) }
            val tomorrowSessions = sessions.filter { isSameDay(it.startMs, calTomorrow, vnTz) }

            // 1. Môn đang diễn ra (current)
            val activeSessions = todaySessions.filter { it.startMs <= nowMs && nowMs < it.endMs }
            var selectedSession: SessionData? = null
            var statusLabel = ""
            var statusColor = accentColor

            if (activeSessions.isNotEmpty()) {
                // Ưu tiên lịch thi trước, sau đó bắt đầu sớm hơn
                selectedSession = activeSessions.sortedWith(
                    compareBy({ if (it.kind == "exam") 0 else 1 }, { it.startMs })
                ).first()
                if (selectedSession.kind == "exam") {
                    statusLabel = "Đang thi"
                    statusColor = examColor
                } else {
                    statusLabel = "Đang học"
                    statusColor = accentColor
                }
            }

            // 2. Lịch thi sắp tới trong ngày (kind == "exam" và upcoming)
            if (selectedSession == null) {
                val upcomingExams = todaySessions.filter { it.kind == "exam" && it.startMs > nowMs }
                    .sortedBy { it.startMs }
                if (upcomingExams.isNotEmpty()) {
                    selectedSession = upcomingExams.first()
                    statusLabel = "Tiếp theo"
                    statusColor = textSecondary
                }
            }

            // 3. Môn sắp tới gần nhất trong ngày (kind == "class" và upcoming)
            if (selectedSession == null) {
                val upcomingClasses = todaySessions.filter { it.kind == "class" && it.startMs > nowMs }
                    .sortedBy { it.startMs }
                if (upcomingClasses.isNotEmpty()) {
                    selectedSession = upcomingClasses.first()
                    statusLabel = "Tiếp theo"
                    statusColor = textSecondary
                }
            }

            // 4. Hết ngày: Môn đầu tiên của ngày mai
            if (selectedSession == null && tomorrowSessions.isNotEmpty()) {
                selectedSession = tomorrowSessions.sortedBy { it.startMs }.first()
                statusLabel = "Ngày mai"
                statusColor = textSecondary
            }

            if (selectedSession != null) {
                // Hiển thị môn học đã chọn
                views.setViewVisibility(R.id.widget_empty_container, View.GONE)
                views.setViewVisibility(R.id.widget_session_content, View.VISIBLE)
                views.setViewVisibility(R.id.widget_status_label, View.VISIBLE)

                views.setTextViewText(R.id.widget_status_label, statusLabel)
                views.setTextColor(R.id.widget_status_label, statusColor)

                val displayTitle = truncatePreserveSuffix(selectedSession.subject, 40)
                views.setTextViewText(R.id.widget_subject_name, displayTitle)
                views.setTextColor(R.id.widget_subject_name, textPrimary)

                val startTimeStr = timeFormat.format(Date(selectedSession.startMs))
                val subInfo = if (selectedSession.room.trim().isNotEmpty()) {
                    "$startTimeStr · ${selectedSession.room.trim()}"
                } else {
                    startTimeStr
                }
                views.setTextViewText(R.id.widget_sub_info, subInfo)
                views.setTextColor(R.id.widget_sub_info, textSecondary)

                // Xử lý thanh tiến độ và đếm ngược (chỉ hiện khi đang học/thi và !endEstimated)
                val isCurrent = selectedSession.startMs <= nowMs && nowMs < selectedSession.endMs
                if (isCurrent && !selectedSession.endEstimated) {
                    val totalDuration = selectedSession.endMs - selectedSession.startMs
                    val elapsed = nowMs - selectedSession.startMs
                    val progressPercent = if (totalDuration > 0) {
                        ((elapsed.toFloat() / totalDuration) * 100).toInt().coerceIn(0, 100)
                    } else 0

                    if (selectedSession.kind == "exam") {
                        views.setViewVisibility(R.id.widget_progress_bar, View.GONE)
                        views.setViewVisibility(R.id.widget_progress_bar_exam, View.VISIBLE)
                        views.setProgressBar(R.id.widget_progress_bar_exam, 100, progressPercent, false)
                    } else {
                        views.setViewVisibility(R.id.widget_progress_bar, View.VISIBLE)
                        views.setViewVisibility(R.id.widget_progress_bar_exam, View.GONE)
                        views.setProgressBar(R.id.widget_progress_bar, 100, progressPercent, false)
                    }
                    views.setViewVisibility(R.id.widget_countdown, View.VISIBLE)

                    val endTimeStr = timeFormat.format(Date(selectedSession.endMs))
                    views.setTextViewText(R.id.widget_countdown, "Đến $endTimeStr")
                    views.setTextColor(R.id.widget_countdown, textSecondary)
                } else {
                    views.setViewVisibility(R.id.widget_progress_bar, View.GONE)
                    views.setViewVisibility(R.id.widget_progress_bar_exam, View.GONE)
                    views.setViewVisibility(R.id.widget_countdown, View.GONE)
                }

                val dateIso = dateFormatIso.format(Date(selectedSession.startMs))
                val deepLink = "tramkien://schedule?date=$dateIso&sessionId=${selectedSession.id}"
                setOnClickPendingIntent(context, views, deepLink, appWidgetId)
            } else {
                // 5. Trạng thái trống (Mục 3.6)
                val nextSessionWithin7Days = findNextSessionWithin7Days(sessions, nowMs)
                val nextPreviewText = if (nextSessionWithin7Days != null) {
                    val weekdayStr = formatWeekdayAbbr(nextSessionWithin7Days.startMs, vnTz)
                    val timeStr = timeFormat.format(Date(nextSessionWithin7Days.startMs))
                    val nameStr = if (nextSessionWithin7Days.shortName.isNotEmpty()) {
                        nextSessionWithin7Days.shortName
                    } else {
                        nextSessionWithin7Days.subject
                    }
                    "Tiếp theo: $weekdayStr $timeStr $nameStr"
                } else {
                    "Không có lịch sắp tới"
                }

                val emptyTitle: String
                if (todaySessions.isNotEmpty()) {
                    // Tất cả các môn hôm nay đã qua
                    emptyTitle = "Hôm nay đã xong ${todaySessions.size} môn"
                } else {
                    emptyTitle = "Hôm nay không có lịch"
                }

                val todayIso = dateFormatIso.format(Date(nowMs))
                val deepLink = "tramkien://schedule?date=$todayIso"
                renderEmptyState(
                    views = views,
                    title = emptyTitle,
                    subtitle = nextPreviewText,
                    textPrimary = textPrimary,
                    textSecondary = textSecondary,
                    deepLinkUri = deepLink
                )
                setOnClickPendingIntent(context, views, deepLink, appWidgetId)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)

            // Lên lịch cập nhật chính xác cho mốc giờ tiếp theo (Mục 4.3)
            scheduleNextAlarm(context, todaySessions, nowMs, vnTz)
        }

        private fun renderEmptyState(
            views: RemoteViews,
            title: String,
            subtitle: String,
            textPrimary: Int,
            textSecondary: Int,
            deepLinkUri: String
        ) {
            views.setViewVisibility(R.id.widget_status_label, View.GONE)
            views.setViewVisibility(R.id.widget_session_content, View.GONE)
            views.setViewVisibility(R.id.widget_progress_bar, View.GONE)
            views.setViewVisibility(R.id.widget_progress_bar_exam, View.GONE)
            views.setViewVisibility(R.id.widget_countdown, View.GONE)

            views.setViewVisibility(R.id.widget_empty_container, View.VISIBLE)
            views.setTextViewText(R.id.widget_empty_title, title)
            views.setTextColor(R.id.widget_empty_title, textPrimary)

            if (subtitle.isNotEmpty()) {
                views.setViewVisibility(R.id.widget_empty_subtitle, View.VISIBLE)
                views.setTextViewText(R.id.widget_empty_subtitle, subtitle)
                views.setTextColor(R.id.widget_empty_subtitle, textSecondary)
            } else {
                views.setViewVisibility(R.id.widget_empty_subtitle, View.GONE)
            }
        }

        private fun setOnClickPendingIntent(
            context: Context,
            views: RemoteViews,
            deepLinkUri: String,
            appWidgetId: Int
        ) {
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(deepLinkUri)).apply {
                setClass(context, MainActivity::class.java)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
        }

        private fun scheduleNextAlarm(
            context: Context,
            todaySessions: List<SessionData>,
            nowMs: Long,
            vnTz: TimeZone
        ) {
            val candidateMs = mutableListOf<Long>()
            for (s in todaySessions) {
                if (s.startMs > nowMs) candidateMs.add(s.startMs)
                if (s.endMs > nowMs) candidateMs.add(s.endMs)
            }

            // Mốc nửa đêm chuyển sang ngày mới tại Việt Nam
            val cal = Calendar.getInstance(vnTz).apply {
                timeInMillis = nowMs
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            candidateMs.add(cal.timeInMillis)

            val nextMs = candidateMs.filter { it > nowMs }.minOrNull() ?: return
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, SingleDay2x2ScheduleWidgetProvider::class.java).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, nextMs, pendingIntent)
                } else {
                    alarmManager.set(AlarmManager.RTC_WAKEUP, nextMs, pendingIntent)
                }
            } catch (e: Exception) {
                android.util.Log.e("SingleDay2x2", "Cannot set alarm", e)
            }
        }

        private fun readSnapshotJson(context: Context): JSONObject? {
            return try {
                val file = File(context.filesDir, SNAPSHOT_FILE_NAME)
                val jsonStr = if (!file.exists()) {
                    val noBackupFile = File(context.noBackupFilesDir, SNAPSHOT_FILE_NAME)
                    if (noBackupFile.exists()) noBackupFile.readText() else null
                } else {
                    file.readText()
                } ?: return null
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

        private fun parseSessions(snapshotObj: JSONObject): List<SessionData> {
            val list = mutableListOf<SessionData>()
            val arr = snapshotObj.optJSONArray("sessions") ?: return list
            for (i in 0 until arr.length()) {
                val item = arr.optJSONObject(i) ?: continue
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

        private fun isSameDay(epochMs: Long, calTarget: Calendar, vnTz: TimeZone): Boolean {
            val cal = Calendar.getInstance(vnTz).apply { timeInMillis = epochMs }
            return cal.get(Calendar.YEAR) == calTarget.get(Calendar.YEAR) &&
                    cal.get(Calendar.DAY_OF_YEAR) == calTarget.get(Calendar.DAY_OF_YEAR)
        }

        private fun findNextSessionWithin7Days(sessions: List<SessionData>, nowMs: Long): SessionData? {
            val deadlineMs = nowMs + 7L * 24 * 60 * 60 * 1000
            val future = sessions.filter { it.startMs > nowMs && it.startMs <= deadlineMs }
            return future.minByOrNull { it.startMs }
        }

        private fun formatWeekdayAbbr(epochMs: Long, vnTz: TimeZone): String {
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

        /**
         * Quy tắc cắt tên dài bảo tồn hậu tố (Ellipsis Preservation - AC-09)
         */
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
