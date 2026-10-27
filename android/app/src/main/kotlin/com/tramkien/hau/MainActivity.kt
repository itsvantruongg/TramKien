package com.tramkien.hau

import android.app.Activity
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.os.Build
import android.view.View
import android.widget.FrameLayout
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity: FlutterActivity() {
    private val WIDGET_CHANNEL = "com.tramkien.hau/widget"
    private var initialRoute: String? = null
    private var initialTargetTab: Int? = null
    private var pendingImageResult: MethodChannel.Result? = null
    private val PICK_IMAGE_REQUEST = 9021

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == PICK_IMAGE_REQUEST) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                try {
                    val uri = data.data!!
                    val inputStream = contentResolver.openInputStream(uri)
                    val destFile = java.io.File(filesDir, "widget_custom_bg.png")
                    val outputStream = java.io.FileOutputStream(destFile)
                    inputStream?.use { input ->
                        outputStream.use { output ->
                            input.copyTo(output)
                        }
                    }
                    pendingImageResult?.success(destFile.absolutePath)
                } catch (e: Exception) {
                    pendingImageResult?.error("FILE_SAVE_ERROR", e.message, null)
                }
            } else {
                pendingImageResult?.success(null)
            }
            pendingImageResult = null
        }
    }

    private fun handleIntent(intent: Intent?) {
        intent?.getStringExtra("open_route")?.let {
            initialRoute = it
        }
        if (intent != null && intent.hasExtra("target_tab")) {
            initialTargetTab = intent.getIntExtra("target_tab", -1)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
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
                                    val intent = Intent(context, cls).apply {
                                        action = "com.tramkien.hau.ACTION_UPDATE_WIDGET"
                                        putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
                                    }
                                    context.sendBroadcast(intent)
                                }
                            } catch (_: Exception) {}
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("UPDATE_FAILED", e.message, null)
                    }
                }
                "pinWidget" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            val appWidgetManager = AppWidgetManager.getInstance(context)
                            val layoutMode = call.argument<String>("layoutMode") ?: "single_day"
                            val variant = call.argument<String>("variant") ?: ""

                            val providerClass = when {
                                layoutMode == "single_day" ->
                                    SingleDayScheduleWidgetProvider::class.java
                                layoutMode == "tomorrow" ->
                                    TomorrowScheduleWidgetProvider::class.java
                                layoutMode == "three_days" ->
                                    ThreeDaysScheduleWidgetProvider::class.java
                                layoutMode == "weekly_strip" || (layoutMode == "seven_days" && variant == "strip") ->
                                    WeeklyStripScheduleWidgetProvider::class.java
                                layoutMode == "seven_days" ->
                                    WeeklyScheduleWidgetProvider::class.java
                                else ->
                                    SingleDay2x2ScheduleWidgetProvider::class.java
                            }

                            val myProvider = ComponentName(context, providerClass)
                            if (appWidgetManager.isRequestPinAppWidgetSupported) {
                                val pinSuccessIntent = Intent(context, WidgetPinSuccessReceiver::class.java).apply {
                                    action = "com.tramkien.hau.ACTION_PIN_WIDGET_SUCCESS"
                                }
                                val piFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
                                } else {
                                    PendingIntent.FLAG_UPDATE_CURRENT
                                }
                                val successCallback = PendingIntent.getBroadcast(
                                    context,
                                    0,
                                    pinSuccessIntent,
                                    piFlags
                                )
                                val success = appWidgetManager.requestPinAppWidget(myProvider, null, successCallback)
                                result.success(success)
                                return@setMethodCallHandler
                            }
                        }
                        result.success(false)
                    } catch (e: Exception) {
                        result.error("PIN_FAILED", e.message, null)
                    }
                }
                "minimizeApp" -> {
                    try {
                        val minimized = moveTaskToBack(true)
                        result.success(minimized)
                    } catch (e: Exception) {
                        result.error("MINIMIZE_FAILED", e.message, null)
                    }
                }
                "renderWidgetPreview" -> {
                    try {
                        val layoutMode = call.argument<String>("layoutMode") ?: "single_day"
                        val variant = call.argument<String>("variant") ?: "2x2"
                        val themeJson = call.argument<String>("themeJson")
                        val dataJson = call.argument<String>("dataJson")

                        val layoutResId: Int
                        val layoutType: String
                        val widthPx: Int
                        val heightPx: Int

                        when {
                            layoutMode == "three_days" -> {
                                layoutResId = R.layout.widget_schedule_three_days
                                layoutType = "three_days"
                                widthPx = 800
                                heightPx = 400
                            }
                            layoutMode == "seven_days" -> {
                                layoutResId = R.layout.widget_schedule_weekly
                                layoutType = "seven_days"
                                widthPx = 800
                                heightPx = 800
                            }
                            layoutMode == "single_day" && variant == "4x2" -> {
                                layoutResId = R.layout.widget_schedule_single_day
                                layoutType = "single_day"
                                widthPx = 800
                                heightPx = 400
                            }
                            else -> {
                                layoutResId = R.layout.widget_schedule_single_day_2x2
                                layoutType = "single_day_2x2"
                                widthPx = 450
                                heightPx = 450
                            }
                        }

                        val remoteViews = ScheduleWidgetProvider.buildRemoteViews(
                            context,
                            themeJson,
                            dataJson,
                            layoutResId,
                            layoutType,
                            targetWidthPx = widthPx,
                            targetHeightPx = heightPx
                        )

                        val frame = FrameLayout(context)
                        val view = remoteViews.apply(context, frame)

                        view.measure(
                            View.MeasureSpec.makeMeasureSpec(widthPx, View.MeasureSpec.EXACTLY),
                            View.MeasureSpec.makeMeasureSpec(heightPx, View.MeasureSpec.EXACTLY)
                        )
                        view.layout(0, 0, widthPx, heightPx)

                        val bitmap = Bitmap.createBitmap(widthPx, heightPx, Bitmap.Config.ARGB_8888)
                        val canvas = Canvas(bitmap)
                        view.draw(canvas)

                        val stream = ByteArrayOutputStream()
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                        result.success(stream.toByteArray())
                    } catch (e: Exception) {
                        result.error("RENDER_FAILED", e.message, null)
                    }
                }
                "getInitialRoute" -> {
                    val r = initialRoute
                    initialRoute = null
                    result.success(r)
                }
                "getInitialTargetTab" -> {
                    val t = initialTargetTab
                    initialTargetTab = null
                    result.success(t)
                }
                "pickImage" -> {
                    try {
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "image/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }
                        pendingImageResult = result
                        startActivityForResult(Intent.createChooser(intent, "Chọn ảnh nền Widget"), PICK_IMAGE_REQUEST)
                    } catch (e: Exception) {
                        result.error("PICK_IMAGE_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
