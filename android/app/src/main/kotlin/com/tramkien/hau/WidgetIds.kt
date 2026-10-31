package com.tramkien.hau

/**
 * Tập hợp hằng số ID, Actions và Request Codes của hệ thống Widget Android
 * Tuân thủ chuẩn SPEC-DYNAMIC-SQLITE-WIDGET-SYSTEM-01 và docs/widgets/ID_REGISTRY.md
 */
object WidgetIds {
    const val APPLICATION_ID = "com.tramkien.hau"
    const val SNAPSHOT_FILE_NAME = "widget_schedule_snapshot.json"
    const val WIDGET_CHANNEL = "com.tramkien.hau/widget"

    // Action strings
    const val ACTION_REFRESH = "com.tramkien.hau.widget.action.REFRESH"
    const val ACTION_PREV = "com.tramkien.hau.widget.action.PREV"
    const val ACTION_NEXT = "com.tramkien.hau.widget.action.NEXT"
    const val ACTION_OPEN_DAY = "com.tramkien.hau.widget.action.OPEN_DAY"
    const val ACTION_OPEN_SESSION = "com.tramkien.hau.widget.action.OPEN_SESSION"

    // Request codes cho PendingIntent (FLAG_IMMUTABLE)
    const val RC_TODAY_REFRESH = 1001
    const val RC_TODAY_OPEN_SESSION = 1002

    const val RC_MONTH_REFRESH = 2001
    const val RC_MONTH_PREV = 2002
    const val RC_MONTH_NEXT = 2003
    const val RC_MONTH_OPEN_DAY = 2004
    const val RC_MONTH_OPEN_SESSION = 2005

    const val RC_THREE_REFRESH = 3001
    const val RC_THREE_OPEN_DAY = 3002
    const val RC_THREE_OPEN_SESSION = 3003

    const val RC_WEEK_REFRESH = 4001
    const val RC_WEEK_PREV = 4002
    const val RC_WEEK_NEXT = 4003
    const val RC_WEEK_OPEN_DAY = 4004
    const val RC_WEEK_OPEN_SESSION = 4005
}
