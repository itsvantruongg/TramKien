# Khai báo giữ lại toàn bộ class của flutter_local_notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.** { *; }

# Giữ lại các class liên quan đến Notification của Android Core
-keep class androidx.core.app.** { *; }
-keep class android.support.v4.app.** { *; }

# Giữ lại thư viện Gson (nếu flutter_local_notifications dùng để parse JSON)
-keep class com.google.gson.** { *; }
-keepclassmembers class com.google.gson.** { *; }
