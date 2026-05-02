# ============================================================
# flutter_local_notifications — Required ProGuard Rules
# Without these, scheduled notifications (zonedSchedule) will
# silently fail in release builds because R8 strips the
# BroadcastReceiver classes that deliver the alarm.
# ============================================================

-keep class com.dexterous.** { *; }

# Keep Gson (used internally by flutter_local_notifications to
# serialize/deserialize notification data for scheduled alarms)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
