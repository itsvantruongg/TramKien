package com.tramkien.hau

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Rect
import android.graphics.RectF
import android.os.Build
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject

/**
 * SPEC-WIDGET-STUDIO-01: Native Android AppWidget Provider
 * Offline rendering from shared JSON contracts:
 * - widget_theme_config.json
 * - widget_schedule_data_single_day.json
 * - widget_schedule_data_three_days.json
 * - widget_schedule_data_seven_days.json
 * Supports 3 elite widgets:
 * 1. SingleDay2x2ScheduleWidgetProvider (2x2)
 * 2. ThreeDaysScheduleWidgetProvider (4x2)
 * 3. WeeklyScheduleWidgetProvider (4x4)
 */
open class ScheduleWidgetProvider : AppWidgetProvider() {

    open val layoutResId: Int
        get() = R.layout.widget_schedule_single_day_2x2

    open val layoutType: String
        get() = "single_day_2x2"

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val themeJsonStr = prefs.getString("flutter.widget_theme_config", null)
        val dataJsonStr = getDataJson(prefs, layoutType)

        for (appWidgetId in appWidgetIds) {
            val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
            updateAppWidget(context, appWidgetManager, appWidgetId, themeJsonStr, dataJsonStr, layoutResId, layoutType, options)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val themeJsonStr = prefs.getString("flutter.widget_theme_config", null)
        val dataJsonStr = getDataJson(prefs, layoutType)
        updateAppWidget(context, appWidgetManager, appWidgetId, themeJsonStr, dataJsonStr, layoutResId, layoutType, newOptions)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        if (action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            action == "com.tramkien.hau.ACTION_UPDATE_WIDGET") {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val thisWidget = ComponentName(context, this::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(thisWidget)
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val themeJsonStr = prefs.getString("flutter.widget_theme_config", null)
            val dataJsonStr = getDataJson(prefs, layoutType)

            for (appWidgetId in appWidgetIds) {
                val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
                updateAppWidget(context, appWidgetManager, appWidgetId, themeJsonStr, dataJsonStr, layoutResId, layoutType, options)
            }
        }
    }

    companion object {
        fun getDataJson(prefs: SharedPreferences, layoutType: String): String? {
            val key = when (layoutType) {
                "tomorrow" -> "flutter.widget_schedule_data_tomorrow"
                "single_day", "single_day_2x2" -> "flutter.widget_schedule_data_single_day"
                "three_days" -> "flutter.widget_schedule_data_three_days"
                "seven_days", "weekly_strip" -> "flutter.widget_schedule_data_seven_days"
                else -> "flutter.widget_schedule_data"
            }
            return prefs.getString(key, null) ?: prefs.getString("flutter.widget_schedule_data", null)
        }

        fun calculateWidgetDimensions(
            context: Context,
            options: Bundle?,
            layoutType: String,
            explicitWidthPx: Int? = null,
            explicitHeightPx: Int? = null
        ): Pair<Int, Int> {
            val density = context.resources.displayMetrics.density
            val (fallbackWidth, fallbackHeight) = when (layoutType) {
                "single_day_2x2" -> Pair(450, 450)
                "seven_days" -> Pair(800, 800)
                else -> Pair(800, 400)
            }

            if (explicitWidthPx != null && explicitHeightPx != null && explicitWidthPx > 0 && explicitHeightPx > 0) {
                return Pair(explicitWidthPx, explicitHeightPx)
            }

            val minWidthDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
            val minHeightDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0

            val targetWidthPx = if (minWidthDp > 0) (minWidthDp * density).toInt() else fallbackWidth
            val targetHeightPx = if (minHeightDp > 0) (minHeightDp * density).toInt() else fallbackHeight

            return Pair(targetWidthPx, targetHeightPx)
        }

        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
            themeJsonStr: String?,
            dataJsonStr: String?,
            layoutResId: Int = R.layout.widget_schedule_single_day_2x2,
            layoutType: String = "single_day_2x2",
            options: Bundle? = null
        ) {
            val widgetOptions = options ?: appWidgetManager.getAppWidgetOptions(appWidgetId)
            val views = buildRemoteViews(context, themeJsonStr, dataJsonStr, layoutResId, layoutType, widgetOptions)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        fun buildFallbackViews(context: Context, layoutResId: Int): RemoteViews {
            val views = RemoteViews(context.packageName, layoutResId)
            try {
                views.setTextViewText(R.id.widget_title, "Trạm Kiến")
                views.setTextViewText(R.id.widget_subtitle, "Lịch học")
            } catch (_: Throwable) {}
            try {
                views.setTextViewText(R.id.widget_weekly_title, "Trạm Kiến")
            } catch (_: Throwable) {}
            return views
        }

        fun buildRemoteViews(
            context: Context,
            themeJsonStr: String?,
            dataJsonStr: String?,
            layoutResId: Int = R.layout.widget_schedule_single_day_2x2,
            layoutType: String = "single_day_2x2",
            options: Bundle? = null,
            targetWidthPx: Int? = null,
            targetHeightPx: Int? = null
        ): RemoteViews {
            try {
            val views = RemoteViews(context.packageName, layoutResId)

            // Click pending intents for Smart Touch-Zones
            try {
                val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }

                // 1. Header Touch Zone: Opens Widget Studio
                val studioIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("open_route", "/widget_studio")
                }
                val studioPendingIntent = PendingIntent.getActivity(context, 101, studioIntent, pendingIntentFlags)
                val studioWeeklyPendingIntent = PendingIntent.getActivity(context, 103, studioIntent, pendingIntentFlags)

                if (layoutType == "seven_days") {
                    views.setOnClickPendingIntent(R.id.widget_weekly_header_container, studioWeeklyPendingIntent)
                } else {
                    views.setOnClickPendingIntent(R.id.widget_header_container, studioPendingIntent)
                }

                // 2. Schedule Content container: Opens Schedule Screen
                val scheduleIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra("target_tab", 1)
                }
                val schedulePendingIntent = PendingIntent.getActivity(context, 102, scheduleIntent, pendingIntentFlags)
                val scheduleWeeklyPendingIntent = PendingIntent.getActivity(context, 104, scheduleIntent, pendingIntentFlags)

                if (layoutType == "seven_days") {
                    views.setOnClickPendingIntent(R.id.widget_weekly_content_container, scheduleWeeklyPendingIntent)
                    views.setOnClickPendingIntent(R.id.widget_root, scheduleWeeklyPendingIntent)
                    try { views.setOnClickPendingIntent(android.R.id.background, scheduleWeeklyPendingIntent) } catch (_: Exception) {}
                } else {
                    views.setOnClickPendingIntent(R.id.widget_content_container, schedulePendingIntent)
                    views.setOnClickPendingIntent(R.id.widget_root, schedulePendingIntent)
                    try { views.setOnClickPendingIntent(android.R.id.background, schedulePendingIntent) } catch (_: Exception) {}
                    if (layoutType == "single_day" || layoutType == "tomorrow") {
                        try {
                            views.setOnClickPendingIntent(R.id.class_item_1, schedulePendingIntent)
                        } catch (_: Exception) {}
                    }
                }
            } catch (_: Exception) {}

            var showRoom = true
            var showTime = true
            var showClassCode = false
            var showTeacher = false
            var bgStyle = "solid"
            var accentColor = Color.parseColor("#1D64F2")
            var textColor = Color.parseColor("#FFFFFF")
            var textSecColor = Color.parseColor("#CBD5E1")
            var accentDrawables = resolveAccentDrawables(accentColor)

            try {
                val effectiveThemeJsonStr = themeJsonStr ?: run {
                    val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    prefs.getString("flutter.widget_theme_config", null)
                }

                val (widthPx, heightPx) = calculateWidgetDimensions(
                    context = context,
                    options = options,
                    layoutType = layoutType,
                    explicitWidthPx = targetWidthPx,
                    explicitHeightPx = targetHeightPx
                )
                val radiusDp = 16f
                val rootBgRes = if (layoutType == "seven_days") R.drawable.widget_card_rounded_20dp else R.drawable.widget_card_rounded_bg

                if (effectiveThemeJsonStr != null) {
                    val themeObj = JSONObject(effectiveThemeJsonStr)
                    bgStyle = themeObj.optString("bg_style", "solid")
                    val bgHex = themeObj.optString("bg_color_hex", "#1C1C1E").trim()
                    val bgOpacity = themeObj.optDouble("bg_opacity", 0.72).toFloat().coerceIn(0f, 1f)
                    val borderColorHex = themeObj.optString("border_color_hex", "#26FFFFFF").trim()
                    val accentHex = themeObj.optString("accent_color_hex", "#1D64F2").trim()
                    val textPrimaryHex = themeObj.optString("text_primary_hex", "#FFFFFF").trim()
                    val textSecondaryHex = themeObj.optString("text_secondary_hex", "#98989D").trim()

                    showRoom = themeObj.optBoolean("show_room", true)
                    showTime = themeObj.optBoolean("show_time", true)
                    showClassCode = themeObj.optBoolean("show_class_code", false)
                    showTeacher = themeObj.optBoolean("show_teacher", false)

                    accentColor = parseColor(accentHex, Color.parseColor("#1D64F2"))
                    accentDrawables = resolveAccentDrawables(accentColor)
                    textColor = parseColor(textPrimaryHex, Color.parseColor("#FFFFFF"))

                    val parsedBg = parseColor(bgHex, Color.parseColor("#1C1C1E"))
                    val isLightBg = try {
                        val red = Color.red(parsedBg) / 255.0
                        val green = Color.green(parsedBg) / 255.0
                        val blue = Color.blue(parsedBg) / 255.0
                        val luminance = 0.299 * red + 0.587 * green + 0.114 * blue
                        luminance > 0.6 || bgHex.equals("#FFFFFF", ignoreCase = true) || bgHex.equals("#F8F9FA", ignoreCase = true)
                    } catch (_: Exception) {
                        false
                    }

                    // WCAG AA High Contrast:
                    // Nền sáng: chữ phụ xám than đậm #475569 chống mờ đục
                    // Nền tối: chữ phụ xám sáng #CBD5E1 (contrast >= 4.5:1)
                    val defaultSecColorHex = if (isLightBg) "#475569" else "#CBD5E1"
                    textSecColor = if (textSecondaryHex.isNotEmpty() &&
                        !textSecondaryHex.equals("#98989D", ignoreCase = true) &&
                        !textSecondaryHex.equals("#8E8E93", ignoreCase = true)) {
                        val parsedCustomSec = parseColor(textSecondaryHex, Color.parseColor(defaultSecColorHex))
                        if (isLightBg) {
                            val secLum = 0.299 * (Color.red(parsedCustomSec) / 255.0) +
                                         0.587 * (Color.green(parsedCustomSec) / 255.0) +
                                         0.114 * (Color.blue(parsedCustomSec) / 255.0)
                            if (secLum > 0.6) Color.parseColor("#475569") else parsedCustomSec
                        } else {
                            parsedCustomSec
                        }
                    } else {
                        Color.parseColor(defaultSecColorHex)
                    }

                    if (isLightBg && (textPrimaryHex.equals("#FFFFFF", ignoreCase = true) || textPrimaryHex.isEmpty())) {
                        textColor = Color.parseColor("#0F172A")
                    }

                    val customBgPath = themeObj.optString("custom_bg_image_path", "")
                    var hasCustomBg = false
                    if (customBgPath.isNotEmpty()) {
                        try {
                            val imgFile = java.io.File(customBgPath)
                            if (imgFile.exists()) {
                                val original = BitmapFactory.decodeFile(imgFile.absolutePath)
                                if (original != null) {
                                    val rounded = if (widthPx > 0 && heightPx > 0) {
                                        createRoundedBitmapWithOverlay(context, original, radiusDp, 130, widthPx, heightPx)
                                    } else {
                                        createRoundedBitmapWithOverlay(context, original, radiusDp, 130)
                                    }
                                    views.setImageViewBitmap(R.id.widget_bg_image, rounded)
                                    views.setViewVisibility(R.id.widget_bg_image, View.VISIBLE)
                                    views.setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)
                                    try { views.setInt(android.R.id.background, "setBackgroundColor", Color.TRANSPARENT) } catch (_: Exception) {}
                                    hasCustomBg = true
                                }
                            }
                        } catch (_: Exception) {}
                    }

                    if (!hasCustomBg) {
                        views.setViewVisibility(R.id.widget_bg_image, View.GONE)
                        val bgRes = when {
                            bgStyle == "transparent" -> R.drawable.widget_card_rounded_transparent
                            bgStyle == "solid" && isLightBg -> R.drawable.widget_card_rounded_light
                            bgStyle == "solid" -> R.drawable.widget_card_rounded_solid
                            isLightBg -> R.drawable.widget_card_rounded_light
                            else -> R.drawable.widget_card_rounded_bg
                        }
                        views.setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)
                        try { views.setInt(android.R.id.background, "setBackgroundResource", bgRes) } catch (_: Throwable) {}
                    }

                    val hairlineColor = if (isLightBg && bgStyle != "transparent") Color.parseColor("#E2E8F0") else Color.parseColor("#33FFFFFF")

                    if (layoutType == "seven_days") {
                        views.setViewVisibility(R.id.widget_weekly_accent_bar, View.GONE)
                        views.setTextColor(R.id.widget_weekly_title, textColor)
                        views.setTextColor(R.id.widget_weekly_subtitle, textSecColor)
                        if (bgStyle == "transparent") {
                            views.setViewVisibility(R.id.widget_weekly_hairline, View.GONE)
                        } else {
                            views.setViewVisibility(R.id.widget_weekly_hairline, View.VISIBLE)
                            views.setInt(R.id.widget_weekly_hairline, "setBackgroundColor", hairlineColor)
                        }
                    } else {
                        views.setViewVisibility(R.id.widget_accent_bar, View.GONE)
                        views.setTextColor(R.id.widget_title, textColor)
                        views.setTextColor(R.id.widget_subtitle, textSecColor)
                        if (bgStyle == "transparent") {
                            views.setViewVisibility(R.id.widget_hairline, View.GONE)
                        } else {
                            views.setViewVisibility(R.id.widget_hairline, View.VISIBLE)
                            views.setInt(R.id.widget_hairline, "setBackgroundColor", hairlineColor)
                        }
                    }
                } else {
                    views.setViewVisibility(R.id.widget_bg_image, View.GONE)
                    val bgRes = R.drawable.widget_card_rounded_solid
                    views.setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)
                    try { views.setInt(android.R.id.background, "setBackgroundResource", bgRes) } catch (_: Throwable) {}
                }

                val effectiveDataJsonStr = dataJsonStr ?: run {
                    val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    getDataJson(prefs, layoutType)
                }

                if (effectiveDataJsonStr.isNullOrEmpty()) {
                    when (layoutType) {
                        "seven_days" -> {
                            views.setTextViewText(R.id.widget_weekly_title, "Trạm Kiến")
                            views.setViewVisibility(R.id.widget_weekly_subtitle, View.GONE)
                            val cellIds = intArrayOf(
                                R.id.grid_cell_1, R.id.grid_cell_2, R.id.grid_cell_3, R.id.grid_cell_4,
                                R.id.grid_cell_5, R.id.grid_cell_6, R.id.grid_cell_7
                            )
                            val badgeIds = intArrayOf(
                                R.id.grid_cell_badge_1, R.id.grid_cell_badge_2, R.id.grid_cell_badge_3, R.id.grid_cell_badge_4,
                                R.id.grid_cell_badge_5, R.id.grid_cell_badge_6, R.id.grid_cell_badge_7
                            )
                            val nameIds = intArrayOf(
                                R.id.grid_cell_name_1, R.id.grid_cell_name_2, R.id.grid_cell_name_3, R.id.grid_cell_name_4,
                                R.id.grid_cell_name_5, R.id.grid_cell_name_6, R.id.grid_cell_name_7
                            )
                            val hybridIds = intArrayOf(
                                R.id.grid_cell_hybrid_1, R.id.grid_cell_hybrid_2, R.id.grid_cell_hybrid_3, R.id.grid_cell_hybrid_4,
                                R.id.grid_cell_hybrid_5, R.id.grid_cell_hybrid_6, R.id.grid_cell_hybrid_7
                            )
                            val class2NameIds = intArrayOf(
                                R.id.grid_cell_class2_name_1, R.id.grid_cell_class2_name_2, R.id.grid_cell_class2_name_3, R.id.grid_cell_class2_name_4,
                                R.id.grid_cell_class2_name_5, R.id.grid_cell_class2_name_6, R.id.grid_cell_class2_name_7
                            )
                            val class2HybridIds = intArrayOf(
                                R.id.grid_cell_class2_hybrid_1, R.id.grid_cell_class2_hybrid_2, R.id.grid_cell_class2_hybrid_3, R.id.grid_cell_class2_hybrid_4,
                                R.id.grid_cell_class2_hybrid_5, R.id.grid_cell_class2_hybrid_6, R.id.grid_cell_class2_hybrid_7
                            )
                            val subIds = intArrayOf(
                                R.id.grid_cell_sub_1, R.id.grid_cell_sub_2, R.id.grid_cell_sub_3, R.id.grid_cell_sub_4,
                                R.id.grid_cell_sub_5, R.id.grid_cell_sub_6, R.id.grid_cell_sub_7
                            )
                            for (i in 0..6) {
                                views.setViewVisibility(badgeIds[i], View.GONE)
                                views.setInt(cellIds[i], "setBackgroundResource", R.drawable.widget_grid_cell_bg)
                                views.setTextViewText(nameIds[i], if (i == 0) "Trạm Kiến • Vui lòng đăng nhập" else "")
                                views.setTextViewText(hybridIds[i], "")
                                views.setViewVisibility(class2NameIds[i], View.GONE)
                                views.setViewVisibility(class2HybridIds[i], View.GONE)
                                views.setViewVisibility(subIds[i], View.GONE)
                                views.setTextColor(nameIds[i], textSecColor)
                            }
                            views.setTextViewText(R.id.grid_cell_summary_classes, "0 buổi học • 0 buổi thi")
                            views.setTextViewText(R.id.grid_cell_summary_empty_days, "Trạm Kiến • Vui lòng đăng nhập")
                        }
                        "three_days" -> {
                            views.setTextViewText(R.id.widget_title, "Trạm Kiến")
                            views.setViewVisibility(R.id.widget_subtitle, View.GONE)
                            views.setViewVisibility(R.id.day_indicator_1, View.GONE)
                            views.setViewVisibility(R.id.day_indicator_2, View.GONE)
                            views.setViewVisibility(R.id.day_indicator_3, View.GONE)
                            views.setTextViewText(R.id.day_1_date_prefix, "")
                            views.setTextViewText(R.id.day_1_class_name, "Trạm Kiến • Vui lòng đăng nhập")
                            views.setTextColor(R.id.day_1_class_name, textSecColor)
                            views.setViewVisibility(R.id.day_1_class_hybrid, View.GONE)
                            views.setTextViewText(R.id.day_2_date_prefix, "")
                            views.setTextViewText(R.id.day_2_class_name, "")
                            views.setViewVisibility(R.id.day_2_class_hybrid, View.GONE)
                            views.setTextViewText(R.id.day_3_date_prefix, "")
                            views.setTextViewText(R.id.day_3_class_name, "")
                            views.setViewVisibility(R.id.day_3_class_hybrid, View.GONE)
                        }
                        "single_day_2x2" -> {
                            views.setTextViewText(R.id.widget_title, "Trạm Kiến")
                            views.setViewVisibility(R.id.single_2x2_content, View.GONE)
                            views.setViewVisibility(R.id.single_2x2_empty, View.VISIBLE)
                            views.setTextViewText(R.id.single_2x2_empty_tag, "CHƯA ĐĂNG NHẬP")
                            views.setTextViewText(R.id.single_2x2_empty_text, "Trạm Kiến • Vui lòng đăng nhập")
                        }
                        "single_day" -> {
                            views.setTextViewText(R.id.widget_title, "Trạm Kiến")
                            views.setViewVisibility(R.id.widget_subtitle, View.GONE)
                            // Ẩn toàn bộ nội dung môn học cá nhân
                            views.setViewVisibility(R.id.single_day_content, View.GONE)
                            // Hiển thị thông báo đăng nhập đồng bộ
                            views.setTextViewText(R.id.class_empty_message, "Trạm Kiến • Vui lòng đăng nhập")
                            views.setTextColor(R.id.class_empty_message, textSecColor)
                            views.setViewVisibility(R.id.class_empty_message, View.VISIBLE)
                        }
                        else -> {
                            views.setTextViewText(R.id.widget_title, "Trạm Kiến")
                            views.setViewVisibility(R.id.widget_subtitle, View.GONE)
                            views.setViewVisibility(R.id.single_day_content, View.GONE)
                            views.setTextViewText(R.id.class_empty_message, "Trạm Kiến • Vui lòng đăng nhập")
                            views.setTextColor(R.id.class_empty_message, textSecColor)
                            views.setViewVisibility(R.id.class_empty_message, View.VISIBLE)
                        }
                    }
                } else {
                    val dataObj = JSONObject(effectiveDataJsonStr)
                    val defaultTitle = when (layoutType) {
                        "tomorrow" -> "Lịch ngày mai"
                        "seven_days", "weekly_strip" -> "Lịch tuần"
                        "three_days" -> "Lịch 3 ngày"
                        else -> "Lịch hôm nay"
                    }
                    val rawTitle = dataObj.optString("widget_title", defaultTitle)
                    var subtitle = dataObj.optString("widget_subtitle", "")

                    val title: String
                    if (layoutType == "seven_days" || rawTitle.contains("7 ngày", ignoreCase = true) || rawTitle.contains("tuần", ignoreCase = true)) {
                        title = "Lịch tuần"
                        if (rawTitle.contains("|")) {
                            val parts = rawTitle.split("|")
                            val p1 = if (parts.size > 1) parts[1].trim() else ""
                            if (subtitle.isEmpty() && p1.isNotEmpty()) {
                                subtitle = p1
                            }
                        }
                    } else if (rawTitle.contains("|")) {
                        val parts = rawTitle.split("|")
                        val p0 = parts[0].trim()
                        val p1 = if (parts.size > 1) parts[1].trim() else ""
                        title = when {
                            p0.contains("3 ngày", ignoreCase = true) -> "Lịch 3 ngày"
                            p0.contains("ngày mai", ignoreCase = true) -> "Lịch ngày mai"
                            else -> "Lịch hôm nay"
                        }
                        if (subtitle.isEmpty() && p1.isNotEmpty()) {
                            subtitle = p1
                        }
                    } else {
                        title = rawTitle
                    }

                    val daysArray = dataObj.optJSONArray("days")

                    if (layoutType == "seven_days") {
                        views.setTextViewText(R.id.widget_weekly_title, title)
                        if (subtitle.isEmpty()) {
                            views.setViewVisibility(R.id.widget_weekly_subtitle, View.GONE)
                        } else {
                            views.setViewVisibility(R.id.widget_weekly_subtitle, View.VISIBLE)
                            views.setTextViewText(R.id.widget_weekly_subtitle, subtitle)
                        }
                    } else {
                        views.setTextViewText(R.id.widget_title, title)
                        if (layoutType == "single_day_2x2") {
                            val dateStr = if (daysArray != null && daysArray.length() > 0) {
                                daysArray.getJSONObject(0).optString("date_str", "")
                            } else {
                                subtitle
                            }
                            val minWidthDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
                            val isNarrow = (minWidthDp in 1..150) || (widthPx > 0 && widthPx < 400)
                            if (isNarrow) {
                                views.setTextViewTextSize(R.id.widget_title, android.util.TypedValue.COMPLEX_UNIT_SP, 12f)
                                if (minWidthDp in 1..130) {
                                    views.setViewVisibility(R.id.widget_subtitle, View.GONE)
                                } else if (dateStr.isNotEmpty()) {
                                    views.setViewVisibility(R.id.widget_subtitle, View.VISIBLE)
                                    val shortDate = if (dateStr.length > 5 && dateStr.contains("/")) {
                                        val p = dateStr.split("/")
                                        if (p.size >= 2) "${p[0].trim().takeLast(2)}/${p[1].trim().take(2)}" else dateStr
                                    } else dateStr
                                    views.setTextViewText(R.id.widget_subtitle, shortDate)
                                } else {
                                    views.setViewVisibility(R.id.widget_subtitle, View.GONE)
                                }
                            } else {
                                views.setTextViewTextSize(R.id.widget_title, android.util.TypedValue.COMPLEX_UNIT_SP, 13f)
                                if (dateStr.isEmpty()) {
                                    views.setViewVisibility(R.id.widget_subtitle, View.GONE)
                                } else {
                                    views.setViewVisibility(R.id.widget_subtitle, View.VISIBLE)
                                    views.setTextViewText(R.id.widget_subtitle, dateStr)
                                }
                            }
                        } else {
                            if (subtitle.isEmpty()) {
                                views.setViewVisibility(R.id.widget_subtitle, View.GONE)
                            } else {
                                views.setViewVisibility(R.id.widget_subtitle, View.VISIBLE)
                                views.setTextViewText(R.id.widget_subtitle, subtitle)
                            }
                        }
                    }

                    fun formatCourseTitle(c: JSONObject): String {
                        val rawName = c.optString("course_name", "")
                        val isExam = c.optBoolean("is_exam", false) || rawName.startsWith("[THI]")
                        return if (isExam && !rawName.startsWith("[THI]")) "[THI] $rawName" else rawName
                    }

                    fun formatCourseTimeRoom(c: JSONObject, isWide: Boolean = false): String {
                        val timeStr = if (showTime) c.optString("time_slot", "") else ""
                        val roomStr = if (showRoom) c.optString("room", "") else ""
                        val teacherStr = if (showTeacher) c.optString("teacher", "") else ""
                        val classCodeStr = if (isWide && showClassCode) c.optString("class_code", "") else ""
                        val parts = mutableListOf<String>()
                        if (timeStr.isNotEmpty()) parts.add(timeStr)
                        if (roomStr.isNotEmpty()) parts.add(roomStr)
                        if (teacherStr.isNotEmpty()) parts.add(teacherStr)
                        if (classCodeStr.isNotEmpty()) parts.add(classCodeStr)
                        return parts.joinToString(" • ")
                    }

                    fun formatCourseSummary(c: JSONObject): String {
                        val title = formatCourseTitle(c)
                        val tr = formatCourseTimeRoom(c)
                        return if (tr.isNotEmpty()) "$title • $tr" else title
                    }

                    fun formatCourseSummary(c: JSONObject, isWide: Boolean): String {
                        val title = formatCourseTitle(c)
                        val tr = formatCourseTimeRoom(c, isWide)
                        return if (tr.isNotEmpty()) "$title • $tr" else title
                    }

                    fun isCourseExam(c: JSONObject): Boolean {
                        return c.optBoolean("is_exam", false) || c.optString("course_name", "").startsWith("[THI]")
                    }

                    fun formatStartTime(timeSlot: String): String {
                        val rawStart = timeSlot.split("–", "-").firstOrNull()?.trim() ?: ""
                        if (rawStart.isEmpty()) return ""
                        val firstToken = rawStart.split(" ").firstOrNull()?.trim() ?: ""
                        if (firstToken.contains(":")) {
                            val colonParts = firstToken.split(":")
                            val h = colonParts[0].trim().toIntOrNull()
                            val m = colonParts.getOrNull(1)?.trim()?.toIntOrNull()
                            if (h != null) {
                                if (h == 6 && m == 55) return "7h"
                                if (h == 12 && m == 55) return "12h45"
                                return if (m == null || m == 0) "${h}h" else "${h}h${String.format("%02d", m)}"
                            }
                        }
                        if (firstToken.endsWith("h", ignoreCase = true)) {
                            val numPart = firstToken.dropLast(1).toIntOrNull()
                            if (numPart != null) return "${numPart}h"
                            return firstToken
                        }
                        val intVal = firstToken.toIntOrNull()
                        if (intVal != null) return "${intVal}h"
                        return firstToken
                    }

                    fun extractStartTime(timeSlot: String): String {
                        return formatStartTime(timeSlot)
                    }

                    fun extractEndTime(timeSlot: String): String {
                        val parts = timeSlot.split("–", "-")
                        if (parts.size <= 1) return ""
                        val rawEnd = parts[1].trim()
                        if (rawEnd.isEmpty()) return ""
                        val firstToken = rawEnd.split(" ").firstOrNull()?.trim() ?: ""
                        if (firstToken.isEmpty()) return ""
                        val formatted = if (firstToken.contains(":")) {
                            val colonParts = firstToken.split(":")
                            val h = colonParts[0].trim().toIntOrNull()
                            val m = colonParts.getOrNull(1)?.trim()?.toIntOrNull()
                            if (h != null) {
                                if (m == null || m == 0) "${h}h" else "${h}h${String.format("%02d", m)}"
                            } else firstToken
                        } else if (firstToken.endsWith("h", ignoreCase = true)) {
                            val numPart = firstToken.dropLast(1).toIntOrNull()
                            if (numPart != null) "${numPart}h" else firstToken
                        } else {
                            val intVal = firstToken.toIntOrNull()
                            if (intVal != null) "${intVal}h" else firstToken
                        }
                        return if (formatted.isNotEmpty()) "- $formatted" else ""
                    }

                    fun formatTimelineSecondary(c: JSONObject): String {
                        val roomStr = if (showRoom) c.optString("room", "") else ""
                        val teacherStr = if (showTeacher) c.optString("teacher", "") else ""
                        val classCodeStr = if (showClassCode) c.optString("class_code", "") else ""
                        val parts = mutableListOf<String>()
                        if (roomStr.isNotEmpty()) parts.add(roomStr)
                        if (teacherStr.isNotEmpty()) parts.add(teacherStr)
                        if (classCodeStr.isNotEmpty()) parts.add(classCodeStr)
                        return parts.joinToString(" • ")
                    }

                    val minWidthDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
                    val minHeightDp = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0) ?: 0
                    val isWideLauncher = minWidthDp >= 220 || (widthPx > 0 && widthPx >= 550)
                    val isTallLauncher = minHeightDp >= 200 || (heightPx > 0 && heightPx >= 500)

                    when (layoutType) {
                        "single_day" -> {
                            views.setTextColor(R.id.single_class_1_time, accentColor)
                            views.setTextColor(R.id.single_class_1_time_end, textSecColor)
                            views.setTextColor(R.id.single_class_1_name, textColor)
                            views.setTextColor(R.id.single_class_1_hybrid, textSecColor)
                            views.setTextColor(R.id.single_class_2_time, accentColor)
                            views.setTextColor(R.id.single_class_2_time_end, textSecColor)
                            views.setTextColor(R.id.single_class_2_name, textColor)
                            views.setTextColor(R.id.single_class_2_hybrid, textSecColor)
                            views.setTextColor(R.id.single_day_badge, accentColor)
                            views.setViewVisibility(R.id.single_day_spacer, View.GONE)
                            views.setTextColor(R.id.class_empty_message, textSecColor)
                            try {
                                views.setInt(R.id.single_class_1_indicator, "setBackgroundColor", accentColor)
                                views.setInt(R.id.single_class_2_indicator, "setBackgroundColor", accentColor)
                            } catch (_: Exception) {}

                            var hasClasses = false
                            if (daysArray != null && daysArray.length() > 0) {
                                val firstDay = daysArray.getJSONObject(0)
                                val rawClasses = firstDay.optJSONArray("classes")
                                val activeClasses = mutableListOf<JSONObject>()
                                val allDayClasses = mutableListOf<JSONObject>()
                                if (rawClasses != null) {
                                    for (idx in 0 until rawClasses.length()) {
                                        val item = rawClasses.getJSONObject(idx)
                                        allDayClasses.add(item)
                                        if (!item.optBoolean("is_finished", false)) {
                                            activeClasses.add(item)
                                        }
                                    }
                                }

                                val allFinished = activeClasses.isEmpty() && allDayClasses.isNotEmpty()
                                val displayClasses = if (activeClasses.isNotEmpty()) activeClasses else if (allFinished) allDayClasses else emptyList()

                                if (displayClasses.isNotEmpty()) {
                                    hasClasses = true
                                    val c1 = displayClasses[0]
                                    val c1Name = formatCourseTitle(c1)
                                    val isExam1 = isCourseExam(c1)
                                    val c1Finished = c1.optBoolean("is_finished", false)
                                    val c1TimeStart = formatStartTime(c1.optString("time_slot", ""))
                                    val c1TimeEnd = extractEndTime(c1.optString("time_slot", ""))
                                    val c1Sec = formatTimelineSecondary(c1)

                                    val c1NameColor = if (isExam1) Color.parseColor("#EF4444") else textColor
                                    val c1TimeColor = accentColor
                                    val c1IndColor = if (isExam1) Color.parseColor("#EF4444") else accentColor

                                    views.setTextViewText(R.id.single_class_1_time, c1TimeStart)
                                    views.setTextViewText(R.id.single_class_1_time_end, c1TimeEnd)
                                    views.setTextViewText(R.id.single_class_1_name, c1Name)
                                    views.setTextViewText(R.id.single_class_1_hybrid, c1Sec)
                                    views.setTextColor(R.id.single_class_1_time, c1TimeColor)
                                    views.setTextColor(R.id.single_class_1_time_end, textSecColor)
                                    views.setTextColor(R.id.single_class_1_name, c1NameColor)
                                    views.setTextColor(R.id.single_class_1_hybrid, textSecColor)
                                    try {
                                        views.setInt(R.id.single_class_1_indicator, "setBackgroundColor", c1IndColor)
                                    } catch (_: Exception) {}
                                    views.setViewVisibility(R.id.class_item_1, View.VISIBLE)

                                    if (displayClasses.size > 1) {
                                        val c2 = displayClasses[1]
                                        val c2Name = formatCourseTitle(c2)
                                        val isExam2 = isCourseExam(c2)
                                        val c2Finished = c2.optBoolean("is_finished", false)
                                        val c2TimeStart = formatStartTime(c2.optString("time_slot", ""))
                                        val c2TimeEnd = extractEndTime(c2.optString("time_slot", ""))
                                        val c2Sec = formatTimelineSecondary(c2)

                                        val c2NameColor = if (isExam2) Color.parseColor("#EF4444") else textColor
                                        val c2TimeColor = accentColor
                                        val c2IndColor = if (isExam2) Color.parseColor("#EF4444") else accentColor

                                        views.setTextViewText(R.id.single_class_2_time, c2TimeStart)
                                        views.setTextViewText(R.id.single_class_2_time_end, c2TimeEnd)
                                        views.setTextViewText(R.id.single_class_2_name, c2Name)
                                        views.setTextViewText(R.id.single_class_2_hybrid, c2Sec)
                                        views.setTextColor(R.id.single_class_2_time, c2TimeColor)
                                        views.setTextColor(R.id.single_class_2_time_end, textSecColor)
                                        views.setTextColor(R.id.single_class_2_name, c2NameColor)
                                        views.setTextColor(R.id.single_class_2_hybrid, textSecColor)
                                        try {
                                            views.setInt(R.id.single_class_2_indicator, "setBackgroundColor", c2IndColor)
                                        } catch (_: Exception) {}
                                        views.setViewVisibility(R.id.class_item_2, View.VISIBLE)
                                    } else {
                                        views.setViewVisibility(R.id.class_item_2, View.GONE)
                                    }

                                    if (displayClasses.size > 2) {
                                        val remaining = displayClasses.size - 2
                                        views.setViewVisibility(R.id.single_day_spacer, View.VISIBLE)
                                        views.setTextViewText(R.id.single_day_badge, "(+$remaining môn nữa)")
                                        views.setTextColor(R.id.single_day_badge, accentColor)
                                        views.setViewVisibility(R.id.single_day_badge, View.VISIBLE)
                                    } else {
                                        views.setViewVisibility(R.id.single_day_spacer, View.GONE)
                                        views.setViewVisibility(R.id.single_day_badge, View.GONE)
                                    }
                                }
                            }

                            if (hasClasses) {
                                views.setViewVisibility(R.id.single_day_content, View.VISIBLE)
                                views.setViewVisibility(R.id.class_empty_message, View.GONE)
                            } else {
                                views.setViewVisibility(R.id.single_day_content, View.GONE)
                                views.setTextViewText(R.id.class_empty_message, "Hôm nay nghỉ")
                                views.setViewVisibility(R.id.class_empty_message, View.VISIBLE)
                            }
                        }

                        "single_day_2x2" -> {
                            views.setTextColor(R.id.single_2x2_class_1_name, textColor)
                            views.setTextColor(R.id.single_2x2_class_1_hybrid, textSecColor)
                            views.setTextColor(R.id.single_2x2_class_2_name, textColor)
                            views.setTextColor(R.id.single_2x2_class_2_hybrid, textSecColor)
                            views.setTextColor(R.id.single_2x2_class_3_name, textColor)
                            views.setTextColor(R.id.single_2x2_class_3_hybrid, textSecColor)
                            views.setTextColor(R.id.single_2x2_class_4_name, textColor)
                            views.setTextColor(R.id.single_2x2_class_4_hybrid, textSecColor)
                            views.setTextColor(R.id.single_2x2_badge, accentColor)
                            views.setTextColor(R.id.single_2x2_empty_tag, accentColor)
                            views.setTextColor(R.id.single_2x2_empty_text, textSecColor)

                            views.setInt(R.id.single_2x2_class_1_hybrid, "setMaxLines", 1)
                            views.setInt(R.id.single_2x2_class_2_hybrid, "setMaxLines", 1)
                            views.setInt(R.id.single_2x2_class_3_hybrid, "setMaxLines", 1)
                            views.setInt(R.id.single_2x2_class_4_hybrid, "setMaxLines", 1)

                            var hasClasses = false
                            if (daysArray != null && daysArray.length() > 0) {
                                val firstDay = daysArray.getJSONObject(0)
                                val rawClasses = firstDay.optJSONArray("classes")
                                val activeClasses = mutableListOf<JSONObject>()
                                val allDayClasses = mutableListOf<JSONObject>()
                                if (rawClasses != null) {
                                    for (idx in 0 until rawClasses.length()) {
                                        val item = rawClasses.getJSONObject(idx)
                                        allDayClasses.add(item)
                                        if (!item.optBoolean("is_finished", false)) {
                                            activeClasses.add(item)
                                        }
                                    }
                                }

                                val allFinished = activeClasses.isEmpty() && allDayClasses.isNotEmpty()
                                val displayClasses = if (activeClasses.isNotEmpty()) activeClasses else if (allFinished) allDayClasses else emptyList()

                                if (displayClasses.isNotEmpty()) {
                                    hasClasses = true
                                    val c1 = displayClasses[0]
                                    val c1Name = formatCourseTitle(c1)
                                    val isExam1 = isCourseExam(c1)
                                    val c1Finished = c1.optBoolean("is_finished", false)
                                    val c1Hybrid = formatCourseTimeRoom(c1, isWideLauncher)

                                    views.setTextViewText(R.id.single_2x2_class_1_name, c1Name)
                                    views.setTextViewText(R.id.single_2x2_class_1_hybrid, c1Hybrid)
                                    val c1Color = if (isExam1) Color.parseColor("#EF4444") else (if (c1Finished) textSecColor else textColor)
                                    views.setTextColor(R.id.single_2x2_class_1_name, c1Color)

                                    if (displayClasses.size > 1) {
                                        val c2 = displayClasses[1]
                                        val c2Name = formatCourseTitle(c2)
                                        val isExam2 = isCourseExam(c2)
                                        val c2Finished = c2.optBoolean("is_finished", false)
                                        val c2Hybrid = formatCourseTimeRoom(c2, isWideLauncher)

                                        views.setTextViewText(R.id.single_2x2_class_2_name, c2Name)
                                        views.setTextViewText(R.id.single_2x2_class_2_hybrid, c2Hybrid)
                                        val c2Color = if (isExam2) Color.parseColor("#EF4444") else (if (c2Finished) textSecColor else textColor)
                                        views.setTextColor(R.id.single_2x2_class_2_name, c2Color)
                                        views.setViewVisibility(R.id.single_2x2_class_2_container, View.VISIBLE)
                                    } else {
                                        views.setViewVisibility(R.id.single_2x2_class_2_container, View.GONE)
                                    }

                                    if (allFinished) {
                                        views.setTextViewText(R.id.single_2x2_badge, "[ĐÃ XONG]")
                                        views.setTextColor(R.id.single_2x2_badge, textSecColor)
                                        views.setViewVisibility(R.id.single_2x2_badge, View.VISIBLE)
                                        views.setViewVisibility(R.id.single_2x2_class_3_container, View.GONE)
                                        views.setViewVisibility(R.id.single_2x2_class_4_container, View.GONE)
                                    } else if (isTallLauncher) {
                                        // minHeightDp >= 200dp: Bung thêm môn thứ 3, thứ 4
                                        if (displayClasses.size > 2) {
                                            val c3 = displayClasses[2]
                                            val c3Name = formatCourseTitle(c3)
                                            val isExam3 = isCourseExam(c3)
                                            val c3Finished = c3.optBoolean("is_finished", false)
                                            val c3Hybrid = formatCourseTimeRoom(c3, isWideLauncher)

                                            views.setTextViewText(R.id.single_2x2_class_3_name, c3Name)
                                            views.setTextViewText(R.id.single_2x2_class_3_hybrid, c3Hybrid)
                                            val c3Color = if (isExam3) Color.parseColor("#EF4444") else (if (c3Finished) textSecColor else textColor)
                                            views.setTextColor(R.id.single_2x2_class_3_name, c3Color)
                                            views.setViewVisibility(R.id.single_2x2_class_3_container, View.VISIBLE)
                                        } else {
                                            views.setViewVisibility(R.id.single_2x2_class_3_container, View.GONE)
                                        }

                                        if (displayClasses.size > 3) {
                                            val c4 = displayClasses[3]
                                            val c4Name = formatCourseTitle(c4)
                                            val isExam4 = isCourseExam(c4)
                                            val c4Finished = c4.optBoolean("is_finished", false)
                                            val c4Hybrid = formatCourseTimeRoom(c4, isWideLauncher)

                                            views.setTextViewText(R.id.single_2x2_class_4_name, c4Name)
                                            views.setTextViewText(R.id.single_2x2_class_4_hybrid, c4Hybrid)
                                            val c4Color = if (isExam4) Color.parseColor("#EF4444") else (if (c4Finished) textSecColor else textColor)
                                            views.setTextColor(R.id.single_2x2_class_4_name, c4Color)
                                            views.setViewVisibility(R.id.single_2x2_class_4_container, View.VISIBLE)
                                        } else {
                                            views.setViewVisibility(R.id.single_2x2_class_4_container, View.GONE)
                                        }

                                        if (displayClasses.size > 4) {
                                            val remaining = displayClasses.size - 4
                                            val footer = "+$remaining môn nữa"
                                            views.setTextViewText(R.id.single_2x2_badge, footer)
                                            views.setTextColor(R.id.single_2x2_badge, accentColor)
                                            views.setViewVisibility(R.id.single_2x2_badge, View.VISIBLE)
                                        } else {
                                            views.setViewVisibility(R.id.single_2x2_badge, View.GONE)
                                        }
                                    } else {
                                        views.setViewVisibility(R.id.single_2x2_class_3_container, View.GONE)
                                        views.setViewVisibility(R.id.single_2x2_class_4_container, View.GONE)
                                        if (displayClasses.size > 2) {
                                            val remaining = displayClasses.size - 2
                                            val footer = "+$remaining môn nữa"
                                            views.setTextViewText(R.id.single_2x2_badge, footer)
                                            views.setTextColor(R.id.single_2x2_badge, accentColor)
                                            views.setViewVisibility(R.id.single_2x2_badge, View.VISIBLE)
                                        } else {
                                            views.setViewVisibility(R.id.single_2x2_badge, View.GONE)
                                        }
                                    }
                                }
                            }

                            if (hasClasses) {
                                views.setViewVisibility(R.id.single_2x2_content, View.VISIBLE)
                                views.setViewVisibility(R.id.single_2x2_empty, View.GONE)
                            } else {
                                views.setViewVisibility(R.id.single_2x2_content, View.GONE)
                                views.setTextViewText(R.id.single_2x2_empty_tag, "SẮP TỚI")
                                views.setTextViewText(R.id.single_2x2_empty_text, "Hôm nay nghỉ")
                                views.setViewVisibility(R.id.single_2x2_empty, View.VISIBLE)
                            }
                        }

                        "three_days" -> {
                            val rowIds = intArrayOf(R.id.day_row_1, R.id.day_row_2, R.id.day_row_3)
                            val prefixIds = intArrayOf(R.id.day_1_date_prefix, R.id.day_2_date_prefix, R.id.day_3_date_prefix)
                            val nameIds = intArrayOf(R.id.day_1_class_name, R.id.day_2_class_name, R.id.day_3_class_name)
                            val hybridIds = intArrayOf(R.id.day_1_class_hybrid, R.id.day_2_class_hybrid, R.id.day_3_class_hybrid)
                            val extraIds = intArrayOf(R.id.day_1_class_extra, R.id.day_2_class_extra, R.id.day_3_class_extra)
                            val indIds = intArrayOf(R.id.day_indicator_1, R.id.day_indicator_2, R.id.day_indicator_3)

                            for (i in 0..2) {
                                val hasDayData = daysArray != null && i < daysArray.length()
                                if (hasDayData) {
                                    val dayObj = daysArray.getJSONObject(i)
                                    val isToday = dayObj.optBoolean("is_today", i == 0)
                                    val isDimmed = dayObj.optBoolean("is_dimmed", false)
                                    val weekdayStr = dayObj.optString("weekday_str", "")
                                    val dateStr = dayObj.optString("date_str", "")

                                    if (isToday) {
                                        if (accentDrawables.todayHighlightRes != R.drawable.widget_today_highlight_bg) {
                                            views.setInt(rowIds[i], "setBackgroundResource", accentDrawables.todayHighlightRes)
                                        } else {
                                            views.setInt(rowIds[i], "setBackgroundResource", R.drawable.widget_today_highlight_bg)
                                        }
                                    } else {
                                        views.setInt(rowIds[i], "setBackgroundResource", 0)
                                    }

                                    views.setTextViewText(prefixIds[i], "$weekdayStr $dateStr")
                                    views.setTextColor(prefixIds[i], if (isToday) accentColor else if (isDimmed) textSecColor else textColor)
                                    views.setTextColor(extraIds[i], accentColor)
                                    views.setViewVisibility(indIds[i], View.GONE)

                                    val classesArray = dayObj.optJSONArray("classes")
                                    val count = classesArray?.length() ?: 0

                                    if (count == 0) {
                                        views.setTextViewText(nameIds[i], "Không có lịch")
                                        views.setTextColor(nameIds[i], if (isToday) textColor else textSecColor)
                                        views.setViewVisibility(hybridIds[i], View.GONE)
                                        views.setViewVisibility(extraIds[i], View.GONE)
                                    } else if (count == 1) {
                                        val c1 = classesArray!!.getJSONObject(0)
                                        val isExam1 = isCourseExam(c1)
                                        val isFinished1 = c1.optBoolean("is_finished", false)
                                        val c1Title = formatCourseTitle(c1)
                                        val c1TimeRoom = formatCourseTimeRoom(c1, isWideLauncher)

                                        views.setTextViewText(nameIds[i], c1Title)
                                        val c1Color = if (isExam1) Color.parseColor("#EF4444") else (if (isFinished1) textSecColor else (if (isToday) textColor else if (isDimmed) textSecColor else textColor))
                                        views.setTextColor(nameIds[i], c1Color)

                                        if (c1TimeRoom.isNotEmpty()) {
                                            views.setTextViewText(hybridIds[i], c1TimeRoom)
                                            views.setTextColor(hybridIds[i], textSecColor)
                                            views.setViewVisibility(hybridIds[i], View.VISIBLE)
                                        } else {
                                            views.setViewVisibility(hybridIds[i], View.GONE)
                                        }
                                        views.setViewVisibility(extraIds[i], View.GONE)
                                    } else if (count == 2) {
                                        val c1 = classesArray!!.getJSONObject(0)
                                        val c2 = classesArray.getJSONObject(1)
                                        val isExam1 = isCourseExam(c1)
                                        val isExam2 = isCourseExam(c2)
                                        val isFinished1 = c1.optBoolean("is_finished", false)
                                        val isFinished2 = c2.optBoolean("is_finished", false)

                                        views.setTextViewText(nameIds[i], formatCourseSummary(c1, isWideLauncher))
                                        val c1Color = if (isExam1) Color.parseColor("#EF4444") else (if (isFinished1) textSecColor else (if (isToday) textColor else if (isDimmed) textSecColor else textColor))
                                        views.setTextColor(nameIds[i], c1Color)

                                        views.setTextViewText(hybridIds[i], formatCourseSummary(c2, isWideLauncher))
                                        val c2Color = if (isExam2) Color.parseColor("#EF4444") else (if (isFinished2) textSecColor else textSecColor)
                                        views.setTextColor(hybridIds[i], c2Color)
                                        views.setViewVisibility(hybridIds[i], View.VISIBLE)
                                        views.setViewVisibility(extraIds[i], View.GONE)
                                    } else {
                                        val c1 = classesArray!!.getJSONObject(0)
                                        val isExam1 = isCourseExam(c1)
                                        val isFinished1 = c1.optBoolean("is_finished", false)

                                        if (isTallLauncher) {
                                            // minHeightDp >= 200dp: Hiển thị cả Môn 1 và Môn 2 chi tiết cho mỗi ngày
                                            val c2 = classesArray.getJSONObject(1)
                                            val isExam2 = isCourseExam(c2)
                                            val isFinished2 = c2.optBoolean("is_finished", false)

                                            views.setTextViewText(nameIds[i], formatCourseSummary(c1, isWideLauncher))
                                            val c1Color = if (isExam1) Color.parseColor("#EF4444") else (if (isFinished1) textSecColor else (if (isToday) textColor else if (isDimmed) textSecColor else textColor))
                                            views.setTextColor(nameIds[i], c1Color)

                                            views.setTextViewText(hybridIds[i], formatCourseSummary(c2, isWideLauncher))
                                            val c2Color = if (isExam2) Color.parseColor("#EF4444") else (if (isFinished2) textSecColor else textSecColor)
                                            views.setTextColor(hybridIds[i], c2Color)
                                            views.setViewVisibility(hybridIds[i], View.VISIBLE)

                                            val remaining = count - 2
                                            views.setTextViewText(extraIds[i], "(+$remaining môn nữa)")
                                            views.setViewVisibility(extraIds[i], View.VISIBLE)
                                        } else {
                                            val remaining = count - 1
                                            views.setTextViewText(nameIds[i], formatCourseSummary(c1, isWideLauncher))
                                            val c1Color = if (isExam1) Color.parseColor("#EF4444") else (if (isFinished1) textSecColor else (if (isToday) textColor else if (isDimmed) textSecColor else textColor))
                                            views.setTextColor(nameIds[i], c1Color)

                                            views.setTextViewText(hybridIds[i], "(+$remaining môn nữa)")
                                            views.setTextColor(hybridIds[i], textSecColor)
                                            views.setViewVisibility(hybridIds[i], View.VISIBLE)
                                            views.setViewVisibility(extraIds[i], View.GONE)
                                        }
                                    }
                                }
                            }
                        }

                        "seven_days" -> {
                            val cellIds = intArrayOf(
                                R.id.grid_cell_1, R.id.grid_cell_2, R.id.grid_cell_3,
                                R.id.grid_cell_4, R.id.grid_cell_5, R.id.grid_cell_6,
                                R.id.grid_cell_7
                            )
                            val badgeIds = intArrayOf(
                                R.id.grid_cell_badge_1, R.id.grid_cell_badge_2, R.id.grid_cell_badge_3,
                                R.id.grid_cell_badge_4, R.id.grid_cell_badge_5, R.id.grid_cell_badge_6,
                                R.id.grid_cell_badge_7
                            )
                            val headerIds = intArrayOf(
                                R.id.grid_cell_header_1, R.id.grid_cell_header_2, R.id.grid_cell_header_3,
                                R.id.grid_cell_header_4, R.id.grid_cell_header_5, R.id.grid_cell_header_6,
                                R.id.grid_cell_header_7
                            )
                            val nameIds = intArrayOf(
                                R.id.grid_cell_name_1, R.id.grid_cell_name_2, R.id.grid_cell_name_3,
                                R.id.grid_cell_name_4, R.id.grid_cell_name_5, R.id.grid_cell_name_6,
                                R.id.grid_cell_name_7
                            )
                            val hybridIds = intArrayOf(
                                R.id.grid_cell_hybrid_1, R.id.grid_cell_hybrid_2, R.id.grid_cell_hybrid_3,
                                R.id.grid_cell_hybrid_4, R.id.grid_cell_hybrid_5, R.id.grid_cell_hybrid_6,
                                R.id.grid_cell_hybrid_7
                            )
                            val class2NameIds = intArrayOf(
                                R.id.grid_cell_class2_name_1, R.id.grid_cell_class2_name_2, R.id.grid_cell_class2_name_3,
                                R.id.grid_cell_class2_name_4, R.id.grid_cell_class2_name_5, R.id.grid_cell_class2_name_6,
                                R.id.grid_cell_class2_name_7
                            )
                            val class2HybridIds = intArrayOf(
                                R.id.grid_cell_class2_hybrid_1, R.id.grid_cell_class2_hybrid_2, R.id.grid_cell_class2_hybrid_3,
                                R.id.grid_cell_class2_hybrid_4, R.id.grid_cell_class2_hybrid_5, R.id.grid_cell_class2_hybrid_6,
                                R.id.grid_cell_class2_hybrid_7
                            )
                            val subIds = intArrayOf(
                                R.id.grid_cell_sub_1, R.id.grid_cell_sub_2, R.id.grid_cell_sub_3,
                                R.id.grid_cell_sub_4, R.id.grid_cell_sub_5, R.id.grid_cell_sub_6,
                                R.id.grid_cell_sub_7
                            )

                            var totalClasses = 0
                            var totalExams = 0
                            var emptyDays = 0

                            val isExpandedWeekly = minWidthDp >= 260 || minHeightDp >= 260 || (widthPx > 0 && widthPx >= 600) || (heightPx > 0 && heightPx >= 600)
                            val weeklyNameMaxLines = 1 // Khóa cứng 1 dòng duy nhất, text dài cắt bằng dấu ba chấm "..."

                            for (i in 0..6) {
                                views.setInt(nameIds[i], "setMaxLines", weeklyNameMaxLines)
                                views.setInt(class2NameIds[i], "setMaxLines", weeklyNameMaxLines)
                                val hasDayData = daysArray != null && i < daysArray.length()
                                if (hasDayData) {
                                    val dayObj = daysArray.getJSONObject(i)
                                    val isToday = dayObj.optBoolean("is_today", false)
                                    val weekdayStr = dayObj.optString("weekday_str", "")
                                    val dateStr = dayObj.optString("date_str", "")

                                    views.setTextViewText(headerIds[i], "$weekdayStr $dateStr")

                                    if (isToday) {
                                        views.setViewVisibility(badgeIds[i], View.VISIBLE)
                                        val r = Color.red(accentColor) / 255.0
                                        val g = Color.green(accentColor) / 255.0
                                        val b = Color.blue(accentColor) / 255.0
                                        val accentLuminance = 0.299 * r + 0.587 * g + 0.114 * b
                                        val badgeTextColor = if (accentLuminance > 0.6) Color.parseColor("#0F172A") else Color.WHITE
                                        views.setTextColor(badgeIds[i], badgeTextColor)
                                        views.setInt(badgeIds[i], "setBackgroundResource", accentDrawables.badgeBgRes)
                                        if (accentDrawables.todayHighlightRes != R.drawable.widget_today_highlight_bg) {
                                            views.setInt(cellIds[i], "setBackgroundResource", accentDrawables.todayHighlightRes)
                                        } else {
                                            views.setInt(cellIds[i], "setBackgroundResource", R.drawable.widget_today_highlight_bg)
                                        }
                                        views.setTextColor(headerIds[i], accentColor)
                                    } else {
                                        views.setViewVisibility(badgeIds[i], View.GONE)
                                        if (bgStyle == "transparent") {
                                            views.setInt(cellIds[i], "setBackgroundColor", Color.TRANSPARENT)
                                        } else {
                                            views.setInt(cellIds[i], "setBackgroundResource", R.drawable.widget_grid_cell_bg)
                                        }
                                        views.setTextColor(headerIds[i], textSecColor)
                                    }

                                    val classesArray = dayObj.optJSONArray("classes")
                                    val count = classesArray?.length() ?: 0

                                    if (count == 0) {
                                        emptyDays++
                                        views.setTextViewText(nameIds[i], "Không có lịch")
                                        views.setTextColor(nameIds[i], textSecColor)
                                        views.setViewVisibility(hybridIds[i], View.GONE)
                                        views.setViewVisibility(class2NameIds[i], View.GONE)
                                        views.setViewVisibility(class2HybridIds[i], View.GONE)
                                        views.setViewVisibility(subIds[i], View.GONE)
                                    } else {
                                        for (k in 0 until count) {
                                            val ck = classesArray!!.getJSONObject(k)
                                            if (isCourseExam(ck)) {
                                                totalExams++
                                            } else {
                                                totalClasses++
                                            }
                                        }

                                        val c1 = classesArray!!.getJSONObject(0)
                                        val isExam1 = isCourseExam(c1)
                                        val isFinished1 = c1.optBoolean("is_finished", false)
                                        val c1Title = formatCourseTitle(c1)
                                        val c1TimeRoom = formatCourseTimeRoom(c1, isWideLauncher)

                                        // Hàng 2: Tên môn 1 (Bold 10.5sp, maxLines="1", ellipsis)
                                        views.setTextViewText(nameIds[i], c1Title)
                                        val c1Color = if (isExam1) Color.parseColor("#EF4444") else (if (isFinished1) textSecColor else textColor)
                                        views.setTextColor(nameIds[i], c1Color)

                                        // Hàng 3: Giờ • Phòng môn 1 (9sp)
                                        if (c1TimeRoom.isNotEmpty()) {
                                            views.setTextViewText(hybridIds[i], c1TimeRoom)
                                            views.setTextColor(hybridIds[i], textSecColor)
                                            views.setViewVisibility(hybridIds[i], View.VISIBLE)
                                        } else {
                                            views.setViewVisibility(hybridIds[i], View.GONE)
                                        }

                                        if (count == 1) {
                                            views.setViewVisibility(class2NameIds[i], View.GONE)
                                            views.setViewVisibility(class2HybridIds[i], View.GONE)
                                            views.setViewVisibility(subIds[i], View.GONE)
                                        } else if (count == 2) {
                                            // Hàng 4 & 5: Môn 2 (Tên và Giờ • Phòng riêng biệt)
                                            val c2 = classesArray.getJSONObject(1)
                                            val isExam2 = isCourseExam(c2)
                                            val isFinished2 = c2.optBoolean("is_finished", false)
                                            val c2Title = formatCourseTitle(c2)
                                            val c2TimeRoom = formatCourseTimeRoom(c2, isWideLauncher)

                                            views.setTextViewText(class2NameIds[i], c2Title)
                                            val c2Color = if (isExam2) Color.parseColor("#EF4444") else (if (isFinished2) textSecColor else textColor)
                                            views.setTextColor(class2NameIds[i], c2Color)
                                            views.setViewVisibility(class2NameIds[i], View.VISIBLE)

                                            if (c2TimeRoom.isNotEmpty()) {
                                                views.setTextViewText(class2HybridIds[i], c2TimeRoom)
                                                views.setTextColor(class2HybridIds[i], textSecColor)
                                                views.setViewVisibility(class2HybridIds[i], View.VISIBLE)
                                            } else {
                                                views.setViewVisibility(class2HybridIds[i], View.GONE)
                                            }

                                            views.setViewVisibility(subIds[i], View.GONE)
                                        } else {
                                            // count >= 3: Môn 1 + Môn 2 + Dòng cuối cùng (+... môn nữa)
                                            val c2 = classesArray.getJSONObject(1)
                                            val isExam2 = isCourseExam(c2)
                                            val isFinished2 = c2.optBoolean("is_finished", false)
                                            val c2Title = formatCourseTitle(c2)
                                            val c2TimeRoom = formatCourseTimeRoom(c2, isWideLauncher)

                                            views.setTextViewText(class2NameIds[i], c2Title)
                                            val c2Color = if (isExam2) Color.parseColor("#EF4444") else (if (isFinished2) textSecColor else textColor)
                                            views.setTextColor(class2NameIds[i], c2Color)
                                            views.setViewVisibility(class2NameIds[i], View.VISIBLE)

                                            if (c2TimeRoom.isNotEmpty()) {
                                                views.setTextViewText(class2HybridIds[i], c2TimeRoom)
                                                views.setTextColor(class2HybridIds[i], textSecColor)
                                                views.setViewVisibility(class2HybridIds[i], View.VISIBLE)
                                            } else {
                                                views.setViewVisibility(class2HybridIds[i], View.GONE)
                                            }

                                            val remaining = count - 2
                                            views.setTextViewText(subIds[i], "(+$remaining môn nữa)")
                                            views.setTextColor(subIds[i], accentColor)
                                            views.setViewVisibility(subIds[i], View.VISIBLE)
                                        }
                                    }
                                }
                            }

                            // Ô 8: Ô Tổng kết tuần: X buổi học • Y buổi thi
                            views.setInt(R.id.grid_cell_8, "setBackgroundResource", accentDrawables.summaryBgRes)
                            views.setTextColor(R.id.grid_cell_summary_title, accentColor)
                            views.setTextColor(R.id.grid_cell_summary_classes, textColor)
                            views.setTextColor(R.id.grid_cell_summary_empty_days, textSecColor)
                            views.setTextViewText(R.id.grid_cell_summary_classes, "$totalClasses buổi học • $totalExams buổi thi")
                            views.setTextViewText(R.id.grid_cell_summary_empty_days, "$emptyDays ngày trống")
                        }
                    }
                }
            } catch (_: Exception) {}

            return views
        } catch (e: Throwable) {
            android.util.Log.e("ScheduleWidgetProvider", "Error building RemoteViews", e)
            return buildFallbackViews(context, layoutResId)
        }
    }

        fun parseColor(hex: String, defaultColor: Int): Int {
            return try {
                val clean = hex.trim()
                val formatted = if (clean.startsWith("#")) clean else "#$clean"
                Color.parseColor(formatted)
            } catch (_: Exception) {
                defaultColor
            }
        }

        fun createDynamicCardBackground(
            context: Context,
            widthPx: Int,
            heightPx: Int,
            bgColor: Int,
            bgOpacity: Float,
            borderColor: Int,
            borderWidthDp: Float,
            cornerRadiusDp: Float
        ): Bitmap {
            val density = context.resources.displayMetrics.density
            val cornerRadiusPx = cornerRadiusDp * density
            val borderWidthPx = borderWidthDp * density

            val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)

            val baseAlpha = Color.alpha(bgColor)
            val finalAlpha = (baseAlpha * bgOpacity.coerceIn(0f, 1f)).toInt().coerceIn(0, 255)

            val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.argb(finalAlpha, Color.red(bgColor), Color.green(bgColor), Color.blue(bgColor))
                style = Paint.Style.FILL
            }

            val inset = if (borderWidthPx > 0f) borderWidthPx / 2f else 1f
            val rect = RectF(inset, inset, widthPx.toFloat() - inset, heightPx.toFloat() - inset)
            canvas.drawRoundRect(rect, cornerRadiusPx, cornerRadiusPx, bgPaint)

            if (borderWidthPx > 0f && Color.alpha(borderColor) > 0) {
                val borderPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = borderColor
                    style = Paint.Style.STROKE
                    strokeWidth = borderWidthPx
                }
                val borderRect = RectF(
                    inset,
                    inset,
                    widthPx.toFloat() - inset,
                    heightPx.toFloat() - inset
                )
                val borderCornerRadius = (cornerRadiusPx - inset).coerceAtLeast(0f)
                canvas.drawRoundRect(borderRect, borderCornerRadius, borderCornerRadius, borderPaint)
            }

            return bitmap
        }

        fun createRoundedBitmapWithOverlay(
            context: Context,
            src: Bitmap,
            cornerRadiusDp: Float,
            overlayAlpha: Int,
            targetWidthPx: Int = src.width,
            targetHeightPx: Int = src.height
        ): Bitmap {
            val density = context.resources.displayMetrics.density
            val cornerRadiusPx = cornerRadiusDp * density
            val output = Bitmap.createBitmap(targetWidthPx, targetHeightPx, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(output)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
            val rect = Rect(0, 0, src.width, src.height)
            val rectF = RectF(0f, 0f, targetWidthPx.toFloat(), targetHeightPx.toFloat())

            val path = Path().apply {
                addRoundRect(rectF, cornerRadiusPx, cornerRadiusPx, Path.Direction.CW)
            }
            canvas.clipPath(path)

            val srcWidth = src.width.toFloat()
            val srcHeight = src.height.toFloat()
            if (srcWidth > 0f && srcHeight > 0f) {
                val scale = Math.max(targetWidthPx / srcWidth, targetHeightPx / srcHeight)
                val scaledWidth = srcWidth * scale
                val scaledHeight = srcHeight * scale
                val left = (targetWidthPx - scaledWidth) / 2f
                val top = (targetHeightPx - scaledHeight) / 2f
                val destRect = RectF(left, top, left + scaledWidth, top + scaledHeight)
                canvas.drawBitmap(src, null, destRect, paint)
            } else {
                canvas.drawBitmap(src, rect, rectF, paint)
            }

            val overlayPaint = Paint().apply {
                color = Color.argb(overlayAlpha.coerceIn(0, 255), 0, 0, 0)
                style = Paint.Style.FILL
            }
            canvas.drawRect(rectF, overlayPaint)

            return output
        }

        // Retained for fallback / dynamic generation compatibility (e.g. testing / custom bitmap fallback):
        fun applyLegacyDynamicBitmapFallback(
            context: Context,
            views: RemoteViews,
            widthPx: Int,
            heightPx: Int,
            radiusDp: Float,
            parsedBg: Int,
            bgOpacity: Float,
            parsedBorderColor: Int
        ) {
            val bgBitmap = createDynamicCardBackground(
                context = context,
                widthPx = widthPx,
                heightPx = heightPx,
                bgColor = parsedBg,
                bgOpacity = bgOpacity,
                borderColor = parsedBorderColor,
                borderWidthDp = 1.0f,
                cornerRadiusDp = radiusDp
            )
            views.setImageViewBitmap(R.id.widget_bg_image, bgBitmap)
            views.setViewVisibility(R.id.widget_bg_image, View.VISIBLE)
            views.setInt(R.id.widget_root, "setBackgroundColor", Color.TRANSPARENT)
            try { views.setInt(android.R.id.background, "setBackgroundColor", Color.TRANSPARENT) } catch (_: Exception) {}
        }

        data class AccentDrawables(
            val badgeBgRes: Int,
            val todayHighlightRes: Int,
            val summaryBgRes: Int
        )

        fun resolveAccentDrawables(accentColor: Int): AccentDrawables {
            val r = Color.red(accentColor)
            val g = Color.green(accentColor)
            val b = Color.blue(accentColor)

            val presets = listOf(
                Triple("black", 28, 28) to 30,
                Triple("white", 255, 255) to 255,
                Triple("slate", 100, 116) to 139,
                Triple("emerald", 16, 185) to 129,
                Triple("amber", 245, 158) to 11,
                Triple("red", 239, 68) to 68,
                Triple("blue", 29, 100) to 242
            )

            fun distSq(pr: Int, pg: Int, pb: Int): Int {
                val dr = r - pr
                val dg = g - pg
                val db = b - pb
                return dr * dr + dg * dg + db * db
            }

            var closestType = "blue"
            var minDist = Int.MAX_VALUE

            for ((triple, pb) in presets) {
                val type = triple.first
                val pr = triple.second
                val pg = triple.third
                val d = distSq(pr, pg, pb)
                if (d < minDist) {
                    minDist = d
                    closestType = type
                }
            }

            return when (closestType) {
                "black" -> AccentDrawables(
                    badgeBgRes = R.drawable.widget_today_badge_black,
                    todayHighlightRes = R.drawable.widget_today_highlight_black,
                    summaryBgRes = R.drawable.widget_grid_summary_cell_black
                )
                "white" -> AccentDrawables(
                    badgeBgRes = R.drawable.widget_today_badge_white,
                    todayHighlightRes = R.drawable.widget_today_highlight_white,
                    summaryBgRes = R.drawable.widget_grid_summary_cell_white
                )
                "slate" -> AccentDrawables(
                    badgeBgRes = R.drawable.widget_today_badge_slate,
                    todayHighlightRes = R.drawable.widget_today_highlight_slate,
                    summaryBgRes = R.drawable.widget_grid_summary_cell_slate
                )
                "emerald" -> AccentDrawables(
                    badgeBgRes = R.drawable.widget_today_badge_emerald,
                    todayHighlightRes = R.drawable.widget_today_highlight_emerald,
                    summaryBgRes = R.drawable.widget_grid_summary_cell_emerald
                )
                "amber" -> AccentDrawables(
                    badgeBgRes = R.drawable.widget_today_badge_amber,
                    todayHighlightRes = R.drawable.widget_today_highlight_amber,
                    summaryBgRes = R.drawable.widget_grid_summary_cell_amber
                )
                "red" -> AccentDrawables(
                    badgeBgRes = R.drawable.widget_today_badge_red,
                    todayHighlightRes = R.drawable.widget_today_highlight_red,
                    summaryBgRes = R.drawable.widget_grid_summary_cell_red
                )
                else -> AccentDrawables(
                    badgeBgRes = R.drawable.widget_today_badge_bg,
                    todayHighlightRes = R.drawable.widget_today_highlight_bg,
                    summaryBgRes = R.drawable.widget_grid_summary_cell_bg
                )
            }
        }
    }
}

/**
 * Option 1: 4x2 Single Day Widget Provider (Legacy)
 */
class SingleDayScheduleWidgetProvider : ScheduleWidgetProvider() {
    override val layoutResId: Int
        get() = R.layout.widget_schedule_single_day
    override val layoutType: String
        get() = "single_day"
}

/**
 * Option 2: 2x2 Single Day Square Widget Provider
 */
class SingleDay2x2ScheduleWidgetProvider : ScheduleWidgetProvider() {
    override val layoutResId: Int
        get() = R.layout.widget_schedule_single_day_2x2
    override val layoutType: String
        get() = "single_day_2x2"
}

/**
 * Option 3: 4x2 Three Days Widget Provider
 */
class ThreeDaysScheduleWidgetProvider : ScheduleWidgetProvider() {
    override val layoutResId: Int
        get() = R.layout.widget_schedule_three_days
    override val layoutType: String
        get() = "three_days"
}

/**
 * Option 4: 4x2 Weekly Strip Calendar Widget Provider (Legacy)
 */
class WeeklyStripScheduleWidgetProvider : ScheduleWidgetProvider() {
    override val layoutResId: Int
        get() = R.layout.widget_schedule_weekly_strip
    override val layoutType: String
        get() = "weekly_strip"
}

/**
 * Option 5: 4x4 Weekly Grid 8-Cell Widget Provider
 */
class WeeklyScheduleWidgetProvider : ScheduleWidgetProvider() {
    override val layoutResId: Int
        get() = R.layout.widget_schedule_weekly
    override val layoutType: String
        get() = "seven_days"
}

/**
 * Option 6: 4x2 Tomorrow Schedule Widget Provider (Legacy)
 */
class TomorrowScheduleWidgetProvider : ScheduleWidgetProvider() {
    override val layoutResId: Int
        get() = R.layout.widget_schedule_tomorrow
    override val layoutType: String
        get() = "tomorrow"
}
