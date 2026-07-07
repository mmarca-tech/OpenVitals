@file:Suppress("UNCHECKED_CAST")

package tech.mmarca.openvitals.health_connect_native

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.HealthConnectFeatures
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.records.Record
import androidx.health.connect.client.request.AggregateGroupByPeriodRequest
import androidx.health.connect.client.request.AggregateRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.time.Duration
import java.time.Instant
import java.time.Period
import java.time.ZoneId
import kotlin.reflect.KClass

/**
 * Flutter plugin bridging to the AndroidX Health Connect Kotlin client.
 *
 * STAGE 2: fully implements [HealthConnectHostApi]. Each `@async` method launches
 * a coroutine on a [Dispatchers.Main] + [SupervisorJob] scope, performs the
 * suspending Health Connect call on [Dispatchers.IO], and completes the Pigeon
 * callback with `Result.success`/`Result.failure`. Records cross the bridge as
 * JSON strings per the schema documented in `lib/health_connect_native.dart`.
 */
class HealthConnectNativePlugin :
  FlutterPlugin,
  ActivityAware,
  HealthConnectHostApi {

  private var applicationContext: Context? = null
  private var activityBinding: ActivityPluginBinding? = null
  private var activity: Activity? = null

  private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())

  /** Pending Health Connect permission request state (single in-flight request). */
  private var pendingPermissionCallback: ((Result<Boolean>) -> Unit)? = null
  private var pendingPermissions: List<String> = emptyList()

  /**
   * Result listener for the Health Connect permission contract. On our request
   * code it re-checks the granted permissions and resolves the pending callback
   * with whether every requested permission ended up granted.
   */
  private val activityResultListener =
    PluginRegistry.ActivityResultListener { requestCode: Int, resultCode: Int, _: Intent? ->
      if (requestCode != PERMISSION_REQUEST_CODE) {
        false
      } else {
        Log.i(TAG, "onActivityResult: permission contract returned resultCode=$resultCode")
        val callback = pendingPermissionCallback
        val requested = pendingPermissions
        pendingPermissionCallback = null
        pendingPermissions = emptyList()
        if (callback == null) {
          true
        } else {
          scope.launch {
            try {
              val granted = withContext(Dispatchers.IO) {
                client().permissionController.getGrantedPermissions()
              }
              callback(Result.success(requested.isNotEmpty() && requested.all { it in granted }))
            } catch (e: Throwable) {
              callback(Result.failure(e))
            }
          }
          true
        }
      }
    }

  // ---------------------------------------------------------------------------
  // FlutterPlugin
  // ---------------------------------------------------------------------------

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = binding.applicationContext
    HealthConnectHostApi.setUp(binding.binaryMessenger, this)
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    HealthConnectHostApi.setUp(binding.binaryMessenger, null)
    applicationContext = null
    scope.cancel()
  }

  // ---------------------------------------------------------------------------
  // ActivityAware — needed for the permission-request contract.
  // ---------------------------------------------------------------------------

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activityBinding = binding
    activity = binding.activity
    binding.addActivityResultListener(activityResultListener)
    Log.i(TAG, "onAttachedToActivity: ${binding.activity}")
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  override fun onDetachedFromActivity() {
    activityBinding?.removeActivityResultListener(activityResultListener)
    activityBinding = null
    activity = null
  }

  // ---------------------------------------------------------------------------
  // HealthConnectHostApi
  // ---------------------------------------------------------------------------

  override fun getSdkStatus(): Long {
    val context = applicationContext
      ?: throw IllegalStateException("Plugin not attached to an engine")
    return HealthConnectClient.getSdkStatus(context).toLong()
  }

  override fun getGrantedPermissions(
    permissions: List<String>,
    callback: (Result<List<String>>) -> Unit,
  ) {
    launchCatching(callback) {
      val granted = withContext(Dispatchers.IO) {
        client().permissionController.getGrantedPermissions()
      }
      permissions.filter { it in granted }
    }
  }

  override fun requestPermissions(
    permissions: List<String>,
    callback: (Result<Boolean>) -> Unit,
  ) {
    val currentActivity = activity
    Log.i(TAG, "requestPermissions: ${permissions.size} perms, activity=$currentActivity")
    if (currentActivity == null) {
      Log.w(TAG, "requestPermissions: no activity attached; cannot launch contract")
      callback(Result.success(false))
      return
    }
    if (permissions.isEmpty()) {
      callback(Result.success(true))
      return
    }
    try {
      pendingPermissionCallback = callback
      pendingPermissions = permissions
      val intent = PermissionController
        .createRequestPermissionResultContract()
        .createIntent(currentActivity, permissions.toSet())
      Log.i(TAG, "requestPermissions: launching intent action=${intent.action} pkg=${intent.`package`}")
      currentActivity.startActivityForResult(intent, PERMISSION_REQUEST_CODE)
    } catch (e: Throwable) {
      Log.e(TAG, "requestPermissions: failed to launch permission contract", e)
      pendingPermissionCallback = null
      pendingPermissions = emptyList()
      callback(Result.failure(e))
    }
  }

  override fun isFeatureAvailable(
    feature: String,
    callback: (Result<Boolean>) -> Unit,
  ) {
    launchCatching(callback) {
      val featureConstant = when (feature) {
        "SKIN_TEMPERATURE" -> HealthConnectFeatures.FEATURE_SKIN_TEMPERATURE
        "MINDFULNESS_SESSION" -> HealthConnectFeatures.FEATURE_MINDFULNESS_SESSION
        "PLANNED_EXERCISE" -> HealthConnectFeatures.FEATURE_PLANNED_EXERCISE
        else -> null
      } ?: return@launchCatching false
      val status = withContext(Dispatchers.IO) {
        client().features.getFeatureStatus(featureConstant)
      }
      status == HealthConnectFeatures.FEATURE_STATUS_AVAILABLE
    }
  }

  override fun readRecordsJson(
    recordType: String,
    startEpochMs: Long,
    endEpochMs: Long,
    filterJson: String?,
    callback: (Result<List<String>>) -> Unit,
  ) {
    launchCatching(callback) {
      val recordClass = HealthRecordConverters.recordClassFor(recordType)
        ?: throw IllegalArgumentException("Unknown record type: $recordType")
      val timeRangeFilter = TimeRangeFilter.between(
        Instant.ofEpochMilli(startEpochMs),
        Instant.ofEpochMilli(endEpochMs),
      )
      val records = withContext(Dispatchers.IO) { readAllRecords(recordClass, timeRangeFilter) }
      records.map { HealthRecordConverters.recordToJson(it) }
    }
  }

  override fun readRecordJson(
    recordType: String,
    recordId: String,
    callback: (Result<String?>) -> Unit,
  ) {
    launchCatching(callback) {
      val recordClass = HealthRecordConverters.recordClassFor(recordType)
        ?: throw IllegalArgumentException("Unknown record type: $recordType")
      val record = withContext(Dispatchers.IO) {
        try {
          client().readRecord(recordClass as KClass<Record>, recordId).record
        } catch (e: Throwable) {
          // Health Connect throws when the id does not exist; treat as null.
          null
        }
      }
      record?.let { HealthRecordConverters.recordToJson(it) }
    }
  }

  override fun aggregate(
    aggregateMetrics: List<String>,
    startEpochMs: Long,
    endEpochMs: Long,
    callback: (Result<Map<String, Double?>>) -> Unit,
  ) {
    launchCatching(callback) {
      val specs = aggregateMetrics.mapNotNull { key ->
        HealthAggregateMetrics.specFor(key)?.let { key to it }
      }
      val out = LinkedHashMap<String, Double?>()
      // Unknown metrics resolve to null.
      for (key in aggregateMetrics) out[key] = null
      if (specs.isNotEmpty()) {
        val timeRangeFilter = TimeRangeFilter.between(
          Instant.ofEpochMilli(startEpochMs),
          Instant.ofEpochMilli(endEpochMs),
        )
        val metricSet = specs.map { it.second.metric }.toSet()
        withContext(Dispatchers.IO) {
          val combined = try {
            client().aggregate(AggregateRequest(metricSet, timeRangeFilter))
          } catch (e: Throwable) {
            null
          }
          if (combined != null) {
            for ((key, spec) in specs) {
              out[key] = runCatching { spec.extract(combined) }.getOrNull()
            }
          } else {
            // Fall back to per-metric aggregation so one failing metric
            // (e.g. a missing permission) does not null out the rest.
            for ((key, spec) in specs) {
              out[key] = try {
                spec.extract(client().aggregate(AggregateRequest(setOf(spec.metric), timeRangeFilter)))
              } catch (e: Throwable) {
                null
              }
            }
          }
        }
      }
      out
    }
  }

  override fun aggregateGroupByPeriodJson(
    aggregateMetrics: List<String>,
    startEpochMs: Long,
    endEpochMs: Long,
    bucketType: String,
    callback: (Result<List<String>>) -> Unit,
  ) {
    launchCatching(callback) {
      val specs = aggregateMetrics.mapNotNull { key ->
        HealthAggregateMetrics.specFor(key)?.let { key to it }
      }
      if (specs.isEmpty()) return@launchCatching emptyList()

      val zone = ZoneId.systemDefault()
      val period = when (bucketType) {
        "DAYS" -> Period.ofDays(1)
        "WEEKS" -> Period.ofWeeks(1)
        "MONTHS" -> Period.ofMonths(1)
        "YEARS" -> Period.ofYears(1)
        else -> Period.ofDays(1)
      }
      val timeRangeFilter = TimeRangeFilter.between(
        Instant.ofEpochMilli(startEpochMs).atZone(zone).toLocalDateTime(),
        Instant.ofEpochMilli(endEpochMs).atZone(zone).toLocalDateTime(),
      )
      val metricSet = specs.map { it.second.metric }.toSet()
      val buckets = withContext(Dispatchers.IO) {
        client().aggregateGroupByPeriod(
          AggregateGroupByPeriodRequest(
            metrics = metricSet,
            timeRangeFilter = timeRangeFilter,
            timeRangeSlicer = period,
          ),
        )
      }
      buckets.map { bucket ->
        val values = JSONObject()
        for ((key, spec) in specs) {
          val value = runCatching { spec.extract(bucket.result) }.getOrNull()
          values.put(key, value ?: JSONObject.NULL)
        }
        JSONObject()
          .put("startEpochMs", bucket.startTime.atZone(zone).toInstant().toEpochMilli())
          .put("endEpochMs", bucket.endTime.atZone(zone).toInstant().toEpochMilli())
          .put("values", values)
          .toString()
      }
    }
  }

  override fun insertRecordsJson(
    recordsJson: List<String>,
    callback: (Result<List<String>>) -> Unit,
  ) {
    launchCatching(callback) {
      val records = recordsJson.map { HealthRecordConverters.jsonToRecord(JSONObject(it)) }
      withContext(Dispatchers.IO) {
        client().insertRecords(records).recordIdsList
      }
    }
  }

  override fun deleteRecordsByClientIds(
    recordType: String,
    clientRecordIds: List<String>,
    callback: (Result<Unit>) -> Unit,
  ) {
    launchCatching(callback) {
      val recordClass = HealthRecordConverters.recordClassFor(recordType)
        ?: throw IllegalArgumentException("Unknown record type: $recordType")
      if (clientRecordIds.isNotEmpty()) {
        withContext(Dispatchers.IO) {
          client().deleteRecords(
            recordType = recordClass,
            recordIdsList = emptyList(),
            clientRecordIdsList = clientRecordIds,
          )
        }
      }
      Unit
    }
  }

  override fun deleteRecordsByIds(
    recordType: String,
    recordIds: List<String>,
    callback: (Result<Unit>) -> Unit,
  ) {
    launchCatching(callback) {
      val recordClass = HealthRecordConverters.recordClassFor(recordType)
        ?: throw IllegalArgumentException("Unknown record type: $recordType")
      if (recordIds.isNotEmpty()) {
        withContext(Dispatchers.IO) {
          client().deleteRecords(
            recordType = recordClass,
            recordIdsList = recordIds,
            clientRecordIdsList = emptyList(),
          )
        }
      }
      Unit
    }
  }

  override fun filterExistingClientIds(
    recordType: String,
    clientRecordIds: List<String>,
    callback: (Result<List<String>>) -> Unit,
  ) {
    launchCatching(callback) {
      val recordClass = HealthRecordConverters.recordClassFor(recordType)
        ?: throw IllegalArgumentException("Unknown record type: $recordType")
      if (clientRecordIds.isEmpty()) return@launchCatching emptyList()

      val wanted = clientRecordIds.toSet()
      // Health Connect cannot query directly by clientRecordId, so read the
      // record type over a wide window and match on metadata.clientRecordId.
      val timeRangeFilter = TimeRangeFilter.between(
        Instant.EPOCH,
        Instant.now().plus(Duration.ofDays(1)),
      )
      withContext(Dispatchers.IO) {
        val found = mutableSetOf<String>()
        var pageToken: String? = null
        do {
          val response = client().readRecords(
            ReadRecordsRequest(
              recordType = recordClass as KClass<Record>,
              timeRangeFilter = timeRangeFilter,
              pageSize = READ_PAGE_SIZE,
              pageToken = pageToken,
            ),
          )
          for (record in response.records) {
            val clientRecordId = record.metadata.clientRecordId ?: continue
            if (clientRecordId in wanted) found.add(clientRecordId)
          }
          if (found.size == wanted.size) break
          pageToken = response.pageToken
        } while (pageToken != null)
        found.toList()
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  private fun client(): HealthConnectClient {
    val context = applicationContext
      ?: throw IllegalStateException("Plugin not attached to an engine")
    return HealthConnectClient.getOrCreate(context)
  }

  private suspend fun readAllRecords(
    recordClass: KClass<out Record>,
    timeRangeFilter: TimeRangeFilter,
  ): List<Record> {
    val records = mutableListOf<Record>()
    var pageToken: String? = null
    do {
      val response = client().readRecords(
        ReadRecordsRequest(
          recordType = recordClass as KClass<Record>,
          timeRangeFilter = timeRangeFilter,
          pageSize = READ_PAGE_SIZE,
          pageToken = pageToken,
        ),
      )
      records += response.records
      pageToken = response.pageToken
    } while (pageToken != null)
    return records
  }

  /**
   * Runs [block] on [scope], delivering its result via [callback] and routing
   * any thrown exception to `Result.failure`.
   */
  private fun <T> launchCatching(
    callback: (Result<T>) -> Unit,
    block: suspend () -> T,
  ) {
    scope.launch {
      try {
        callback(Result.success(block()))
      } catch (e: Throwable) {
        callback(Result.failure(e))
      }
    }
  }

  private companion object {
    private const val TAG = "HealthConnectNative"
    private const val PERMISSION_REQUEST_CODE = 0xB1A2
    private const val READ_PAGE_SIZE = 1000
  }
}
