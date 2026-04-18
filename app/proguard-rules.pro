# Keep Health Connect classes
-keep class androidx.health.connect.** { *; }

# Keep Kotlin coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}

# Keep data classes used with reflection
-keepclassmembers class dev.manu.hcdashboard.data.model.** {
    <fields>;
    <init>(...);
}
