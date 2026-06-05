# Flutter Proguard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.provider.** { *; }
-keep class org.chromium.** { *; }

# Keep system classes
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider
-keep public class * extends android.app.backup.BackupAgentHelper
-keep public class * extends android.preference.Preference

# For standard networking/json serializations (used by Supabase plugins)
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Keep local properties and methods of plugins to avoid reflection issues
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn kotlinx.coroutines.**
-dontwarn com.google.android.play.core.**
