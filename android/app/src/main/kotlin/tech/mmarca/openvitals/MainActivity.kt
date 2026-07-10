package tech.mmarca.openvitals

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationManager
import android.location.altitude.AltitudeConverter
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.RequiresApi
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * The `health` plugin requires the host activity to be a
 * [FlutterFragmentActivity] (a `ComponentActivity`) so that Health Connect
 * permission requests can use `registerForActivityResult`. Extending
 * `FlutterActivity` would make Health Connect permission launches fail at
 * runtime.
 *
 * Also hosts the activity-recording sensor bridge: `sensors_plus` exposes
 * neither the proximity sensor nor the step detector, so the recording
 * controller reads them through the channels registered here (port of the
 * Kotlin `ActivityRecordingService` sensor listener), plus the WGS84→MSL
 * altitude conversion the Kotlin controller performs with [AltitudeConverter].
 */
class MainActivity : FlutterFragmentActivity() {
    private val sensorManager: SensorManager by lazy {
        getSystemService(Context.SENSOR_SERVICE) as SensorManager
    }
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * `AltitudeConverter.addMslAltitudeToLocation` may read its geoid grid from
     * disk, so conversions run off the platform thread (the Kotlin controller
     * hops to a single-thread dispatcher for the same reason).
     */
    private val altitudeExecutor: ExecutorService = Executors.newSingleThreadExecutor()

    /** Kotlin `ActivityRecordingController.altitudeConverter` (API 34+ only). */
    private val altitudeConverter: AltitudeConverter? by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            AltitudeConverter()
        } else {
            null
        }
    }

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasSensor" -> {
                    val type = sensorTypeFor(call.argument<String>("type"))
                    result.success(type != null && sensorManager.getDefaultSensor(type) != null)
                }
                "hasActivityRecognitionPermission" ->
                    result.success(hasActivityRecognitionPermission())
                "requestActivityRecognitionPermission" ->
                    requestActivityRecognitionPermission(result)
                "convertToMsl" -> {
                    val latitude = call.argument<Double>("latitude")
                    val longitude = call.argument<Double>("longitude")
                    val altitudeMeters = call.argument<Double>("altitudeMeters")
                    if (latitude == null || longitude == null || altitudeMeters == null) {
                        result.success(null)
                    } else {
                        convertToMsl(latitude, longitude, altitudeMeters, result)
                    }
                }
                else -> result.notImplemented()
            }
        }
        // Debug-diagnostics bridge: reads the current process logcat so the
        // Dart `DebugLogSanitizer` (port of `PrivacySafeDebugLogExporter`) can
        // privacy-sanitize it. `-v tag` yields the `LEVEL/Tag: message` format
        // the sanitizer regex expects. Privacy handling stays entirely in Dart.
        MethodChannel(messenger, DIAGNOSTICS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "readCurrentProcessLogcat" -> result.success(readCurrentProcessLogcat())
                else -> result.notImplemented()
            }
        }
        // Kotlin registers one SensorEventListener at SENSOR_DELAY_NORMAL per
        // recording; here each event channel owns its listener, registered only
        // while the Dart side is subscribed.
        EventChannel(messenger, PROXIMITY_CHANNEL).setStreamHandler(
            SensorStreamHandler(sensorManager, Sensor.TYPE_PROXIMITY) { event ->
                val value = event.values.firstOrNull() ?: return@SensorStreamHandler null
                mapOf(
                    "value" to value.toDouble(),
                    "timestampMillis" to System.currentTimeMillis(),
                )
            },
        )
        EventChannel(messenger, STEP_DETECTOR_CHANNEL).setStreamHandler(
            SensorStreamHandler(sensorManager, Sensor.TYPE_STEP_DETECTOR) {
                System.currentTimeMillis()
            },
        )
    }

    override fun onDestroy() {
        altitudeExecutor.shutdown()
        super.onDestroy()
    }

    /**
     * Reads this process's logcat buffer (`logcat -d --pid <mypid> -v tag`),
     * mirroring the Kotlin `PrivacySafeDebugLogExporter.readCurrentProcessLogcat`.
     * Returns the raw lines; the Dart side does all privacy sanitizing. Any
     * failure/timeout is surfaced as a single diagnostic line rather than
     * throwing, so the Dart channel call always resolves.
     */
    private fun readCurrentProcessLogcat(): List<String> =
        runCatching {
            val process = ProcessBuilder(
                "logcat",
                "-d",
                "--pid",
                android.os.Process.myPid().toString(),
                "-v",
                "tag",
            )
                .redirectErrorStream(true)
                .start()
            if (!process.waitFor(5, TimeUnit.SECONDS)) {
                process.destroy()
                return listOf("W/OpenVitalsDiagnostics: logcat capture timed out")
            }
            process.inputStream.bufferedReader().useLines { it.toList() }
        }.getOrElse { throwable ->
            listOf(
                "E/OpenVitalsDiagnostics: logcat capture failed " +
                    "type=${throwable::class.java.simpleName}",
            )
        }

    private fun sensorTypeFor(name: String?): Int? =
        when (name) {
            "proximity" -> Sensor.TYPE_PROXIMITY
            "stepDetector" -> Sensor.TYPE_STEP_DETECTOR
            "accelerometer" -> Sensor.TYPE_ACCELEROMETER
            else -> null
        }

    /** Kotlin `ActivityRecordingController.hasActivityRecognitionPermission`. */
    private fun hasActivityRecognitionPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.ACTIVITY_RECOGNITION,
            ) == PackageManager.PERMISSION_GRANTED

    private fun requestActivityRecognitionPermission(result: MethodChannel.Result) {
        if (hasActivityRecognitionPermission()) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            // A request dialog is already up; report the current (denied) state
            // instead of stacking a second system dialog.
            result.success(false)
            return
        }
        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
            ACTIVITY_RECOGNITION_REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (requestCode == ACTIVITY_RECOGNITION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }

    /**
     * Kotlin `Location.withMslAltitude`: convert the fix's WGS84 ellipsoid
     * altitude to mean sea level, best-effort, on a background thread. Returns
     * null below API 34 or on any conversion failure so the Dart side keeps the
     * raw altitude.
     */
    private fun convertToMsl(
        latitude: Double,
        longitude: Double,
        altitudeMeters: Double,
        result: MethodChannel.Result,
    ) {
        val converter = altitudeConverter
        if (converter == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            result.success(null)
            return
        }
        altitudeExecutor.execute {
            val mslAltitudeMeters = runCatching {
                mslAltitudeMetersOrNull(converter, latitude, longitude, altitudeMeters)
            }.getOrNull()
            mainHandler.post { result.success(mslAltitudeMeters) }
        }
    }

    @RequiresApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun mslAltitudeMetersOrNull(
        converter: AltitudeConverter,
        latitude: Double,
        longitude: Double,
        altitudeMeters: Double,
    ): Double? {
        val location = Location(LocationManager.GPS_PROVIDER).apply {
            this.latitude = latitude
            this.longitude = longitude
            this.altitude = altitudeMeters
        }
        converter.addMslAltitudeToLocation(this, location)
        return if (location.hasMslAltitude()) location.mslAltitudeMeters else null
    }

    private companion object {
        const val METHOD_CHANNEL = "tech.mmarca.openvitals/recording_sensors"
        const val DIAGNOSTICS_CHANNEL = "tech.mmarca.openvitals/diagnostics"
        const val PROXIMITY_CHANNEL = "tech.mmarca.openvitals/recording_sensors/proximity"
        const val STEP_DETECTOR_CHANNEL = "tech.mmarca.openvitals/recording_sensors/step_detector"
        const val ACTIVITY_RECOGNITION_REQUEST_CODE = 4031
    }
}

/**
 * Bridges one sensor type onto an [EventChannel]: registers a listener at
 * `SENSOR_DELAY_NORMAL` (matching the Kotlin service's registration) while the
 * Dart stream has a subscriber, and unregisters when it cancels. Emits
 * `endOfStream` immediately when the sensor does not exist so the Dart side
 * completes instead of waiting forever.
 */
private class SensorStreamHandler(
    private val sensorManager: SensorManager,
    private val sensorType: Int,
    private val mapEvent: (SensorEvent) -> Any?,
) : EventChannel.StreamHandler {
    private var listener: SensorEventListener? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        val sensor = sensorManager.getDefaultSensor(sensorType)
        if (sensor == null) {
            events.endOfStream()
            return
        }
        val sensorListener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                if (event.sensor.type != sensorType) return
                mapEvent(event)?.let(events::success)
            }

            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
        }
        listener = sensorListener
        sensorManager.registerListener(sensorListener, sensor, SensorManager.SENSOR_DELAY_NORMAL)
    }

    override fun onCancel(arguments: Any?) {
        listener?.let { runCatching { sensorManager.unregisterListener(it) } }
        listener = null
    }
}
