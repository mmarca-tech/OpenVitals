package tech.mmarca.openvitals.health_connect_native

import android.util.Log
import androidx.health.connect.client.records.ExerciseLap
import androidx.health.connect.client.records.ExerciseRoute
import androidx.health.connect.client.records.ExerciseRouteResult
import androidx.health.connect.client.records.ExerciseSegment
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.records.SpeedRecord
import androidx.health.connect.client.records.metadata.Device
import androidx.health.connect.client.records.metadata.Metadata
import androidx.health.connect.client.time.TimeRangeFilter
import androidx.health.connect.client.units.Length
import java.time.Instant
import java.time.ZoneId
import java.util.UUID
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Ported from the native OpenVitals app (`healthconnect/ActivityHealthReader.kt`
 * + the `toExerciseData` mapper). Covers the record-based activity surface —
 * exercise sessions (read/write/update/delete) and raw speed samples. The
 * aggregate reads (steps/distance/floors/daily/calories) stay on the generic
 * aggregate ops in the data source. Exercise-session dedup stays in Dart.
 */
internal class ActivityHealthReader(
  private val support: HealthConnectReaderSupport,
  private val appPackageName: String,
) {
  suspend fun readExerciseSessions(start: Instant, end: Instant): List<ExerciseDataMsg> =
    support.withLogging("readExerciseSessions[$start..$end]", emptyList()) {
      support.client().readRecordsPaged(
        recordType = ExerciseSessionRecord::class,
        timeRangeFilter = TimeRangeFilter.between(start, end),
        ascendingOrder = false,
        pageSize = 50,
      ).map { it.toMsg() }
    }

  suspend fun readExerciseSessionById(id: String): ExerciseDataMsg? =
    support.withNullableLogging("readExerciseSessionById[$id]") {
      support.client().readRecord(ExerciseSessionRecord::class, id).record.toMsg()
    }

  suspend fun readSpeedSamples(start: Instant, end: Instant): List<SpeedSampleMsg> =
    support.withLogging("readSpeedSamples[$start..$end]", emptyList()) {
      support.client().readRecordsPaged(
        recordType = SpeedRecord::class,
        timeRangeFilter = TimeRangeFilter.between(start, end),
        ascendingOrder = true,
        pageSize = 500,
      ).flatMap { record ->
        val source = record.metadata.dataOrigin.packageName
        record.samples.map { sample ->
          SpeedSampleMsg(
            timeEpochMs = sample.time.toEpochMilli(),
            metersPerSecond = sample.speed.inMetersPerSecond,
            source = source,
          )
        }
      }
    }

  suspend fun writeActivityEntry(request: ActivityWriteRequestMsg): String =
    withContext(Dispatchers.IO) {
      support.requireSyncEnabled()
      val startTime = Instant.ofEpochMilli(request.startEpochMs)
      val clientRecordId = "openvitals_activity_${startTime.toEpochMilli()}_${UUID.randomUUID()}"
      val metadata = Metadata.manualEntry(
        clientRecordId = clientRecordId,
        device = Device(type = Device.TYPE_PHONE),
      )
      Log.d(TAG, "Writing exercise session ${support.diagnosticsSummary()}")
      support.client().insertRecords(listOf(buildSession(request, metadata)))
      clientRecordId
    }

  suspend fun updateActivityEntry(id: String, request: ActivityWriteRequestMsg) =
    withContext(Dispatchers.IO) {
      support.requireSyncEnabled()
      val existing = support.client().readRecord(ExerciseSessionRecord::class, id).record
      existing.requireOpenVitalsOrigin(appPackageName)
      val metadata = Metadata.manualEntryWithId(
        id = id,
        device = existing.metadata.device ?: Device(type = Device.TYPE_PHONE),
      )
      Log.d(TAG, "Updating exercise session ${support.diagnosticsSummary()}")
      support.client().updateRecords(listOf(buildSession(request, metadata)))
    }

  suspend fun deleteActivityEntry(id: String) = withContext(Dispatchers.IO) {
    support.requireSyncEnabled()
    val existing = support.client().readRecord(ExerciseSessionRecord::class, id).record
    existing.requireOpenVitalsOrigin(appPackageName)
    support.client().deleteRecords(
      recordType = ExerciseSessionRecord::class,
      recordIdsList = listOf(existing.metadata.id),
      clientRecordIdsList = emptyList(),
    )
  }

  private fun buildSession(request: ActivityWriteRequestMsg, metadata: Metadata): ExerciseSessionRecord {
    val startTime = Instant.ofEpochMilli(request.startEpochMs)
    val endTime = Instant.ofEpochMilli(request.endEpochMs)
    val zone = ZoneId.systemDefault()
    val segments = request.segments.map { s ->
      ExerciseSegment(
        startTime = Instant.ofEpochMilli(s.startEpochMs),
        endTime = Instant.ofEpochMilli(s.endEpochMs),
        segmentType = s.segmentType.toInt(),
        repetitions = s.repetitions.toInt(),
      )
    }
    val laps = request.laps.map { l ->
      ExerciseLap(
        startTime = Instant.ofEpochMilli(l.startEpochMs),
        endTime = Instant.ofEpochMilli(l.endEpochMs),
        length = l.lengthMeters?.let { Length.meters(it) },
      )
    }
    val route: ExerciseRoute? = request.routePoints
      .takeIf { it.isNotEmpty() }
      ?.map { p ->
        ExerciseRoute.Location(
          time = Instant.ofEpochMilli(p.timeEpochMs),
          latitude = p.latitude,
          longitude = p.longitude,
          horizontalAccuracy = p.horizontalAccuracyMeters?.let { Length.meters(it) },
          verticalAccuracy = p.verticalAccuracyMeters?.let { Length.meters(it) },
          altitude = p.altitudeMeters?.let { Length.meters(it) },
        )
      }
      ?.let { ExerciseRoute(it) }
    return ExerciseSessionRecord(
      startTime = startTime,
      startZoneOffset = zone.rules.getOffset(startTime),
      endTime = endTime,
      endZoneOffset = zone.rules.getOffset(endTime),
      metadata = metadata,
      exerciseType = request.exerciseType.toInt(),
      title = request.title,
      notes = request.notes,
      segments = segments,
      laps = laps,
      exerciseRoute = route,
      plannedExerciseSessionId = request.plannedExerciseSessionId,
    )
  }

  private fun ExerciseSessionRecord.toMsg() = ExerciseDataMsg(
    id = metadata.id,
    title = title,
    exerciseType = exerciseType.toLong(),
    startEpochMs = startTime.toEpochMilli(),
    endEpochMs = endTime.toEpochMilli(),
    source = metadata.dataOrigin.packageName,
    notes = notes,
    clientRecordId = metadata.clientRecordId,
    plannedExerciseSessionId = plannedExerciseSessionId,
    device = metadata.device?.let {
      ExerciseDeviceDataMsg(type = it.type.toLong(), manufacturer = it.manufacturer, model = it.model)
    },
    segments = segments.map { s ->
      ExerciseSegmentMsg(
        startEpochMs = s.startTime.toEpochMilli(),
        endEpochMs = s.endTime.toEpochMilli(),
        segmentType = s.segmentType.toLong(),
        repetitions = s.repetitions.toLong(),
        setIndex = null,
      )
    },
    laps = laps.map { l ->
      ExerciseLapMsg(
        startEpochMs = l.startTime.toEpochMilli(),
        endEpochMs = l.endTime.toEpochMilli(),
        lengthMeters = l.length?.inMeters,
      )
    },
    route = exerciseRouteResult.toRouteMsg(),
    isOpenVitalsEntry = isOpenVitalsRecord(metadata.dataOrigin.packageName, appPackageName),
  )

  private fun ExerciseRouteResult.toRouteMsg(): ExerciseRouteMsg = when (this) {
    is ExerciseRouteResult.Data -> ExerciseRouteMsg(
      status = ExerciseRouteStatusMsg.DATA,
      points = exerciseRoute.route.map { point ->
        ExerciseRoutePointMsg(
          timeEpochMs = point.time.toEpochMilli(),
          latitude = point.latitude,
          longitude = point.longitude,
          altitudeMeters = point.altitude?.inMeters,
          horizontalAccuracyMeters = point.horizontalAccuracy?.inMeters,
          verticalAccuracyMeters = point.verticalAccuracy?.inMeters,
        )
      },
    )
    is ExerciseRouteResult.ConsentRequired ->
      ExerciseRouteMsg(ExerciseRouteStatusMsg.CONSENT_REQUIRED, emptyList())
    is ExerciseRouteResult.NoData ->
      ExerciseRouteMsg(ExerciseRouteStatusMsg.NO_DATA, emptyList())
    else -> ExerciseRouteMsg(ExerciseRouteStatusMsg.NO_DATA, emptyList())
  }

  private companion object {
    private const val TAG = "ActivityHealthReader"
  }
}
