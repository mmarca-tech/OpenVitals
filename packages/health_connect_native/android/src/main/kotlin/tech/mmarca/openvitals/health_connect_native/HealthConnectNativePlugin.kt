package tech.mmarca.openvitals.health_connect_native

import android.app.Activity
import android.content.Context
import android.content.Intent
import androidx.health.connect.client.HealthConnectClient
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry

/**
 * Flutter plugin bridging to the AndroidX Health Connect Kotlin client.
 *
 * STAGE 1 (skeleton): the plugin wires up the Pigeon [HealthConnectHostApi],
 * holds the [Activity] for the future permission flow, and answers
 * [getSdkStatus] for real. Every other host method is a stub that either returns
 * an empty/false/null result or fails with `UnsupportedOperationException`;
 * Health Connect read/write/aggregate logic lands in Stage 2.
 */
class HealthConnectNativePlugin :
  FlutterPlugin,
  ActivityAware,
  HealthConnectHostApi {

  private var applicationContext: Context? = null
  private var activityBinding: ActivityPluginBinding? = null
  private var activity: Activity? = null

  /**
   * Result listener for the Health Connect permission contract.
   *
   * TODO(stage2): launch [androidx.health.connect.client.PermissionController.createRequestPermissionResultContract]
   * from [requestPermissions] and resolve the pending callback here. For now it
   * handles nothing so it never intercepts another plugin's result.
   */
  private val activityResultListener =
    PluginRegistry.ActivityResultListener { _: Int, _: Int, _: Intent? -> false }

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
  }

  // ---------------------------------------------------------------------------
  // ActivityAware — needed for the Stage 2 permission-request contract.
  // ---------------------------------------------------------------------------

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activityBinding = binding
    activity = binding.activity
    binding.addActivityResultListener(activityResultListener)
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
    // TODO(stage2): query permissionController.getGrantedPermissions().
    callback(Result.success(emptyList()))
  }

  override fun requestPermissions(
    permissions: List<String>,
    callback: (Result<Boolean>) -> Unit,
  ) {
    // TODO(stage2): launch the HC permission contract via the Activity and
    // resolve through activityResultListener.
    callback(Result.success(false))
  }

  override fun isFeatureAvailable(
    feature: String,
    callback: (Result<Boolean>) -> Unit,
  ) {
    // TODO(stage2): map `feature` to HealthConnectFeatures.* and check status.
    callback(Result.success(false))
  }

  override fun readRecordsJson(
    recordType: String,
    startEpochMs: Long,
    endEpochMs: Long,
    filterJson: String?,
    callback: (Result<List<String>>) -> Unit,
  ) {
    callback(Result.failure(UnsupportedOperationException("stage2")))
  }

  override fun readRecordJson(
    recordType: String,
    recordId: String,
    callback: (Result<String?>) -> Unit,
  ) {
    callback(Result.failure(UnsupportedOperationException("stage2")))
  }

  override fun aggregate(
    aggregateMetrics: List<String>,
    startEpochMs: Long,
    endEpochMs: Long,
    callback: (Result<Map<String, Double?>>) -> Unit,
  ) {
    callback(Result.failure(UnsupportedOperationException("stage2")))
  }

  override fun aggregateGroupByPeriodJson(
    aggregateMetrics: List<String>,
    startEpochMs: Long,
    endEpochMs: Long,
    bucketType: String,
    callback: (Result<List<String>>) -> Unit,
  ) {
    callback(Result.failure(UnsupportedOperationException("stage2")))
  }

  override fun insertRecordsJson(
    recordsJson: List<String>,
    callback: (Result<List<String>>) -> Unit,
  ) {
    callback(Result.failure(UnsupportedOperationException("stage2")))
  }

  override fun deleteRecordsByClientIds(
    recordType: String,
    clientRecordIds: List<String>,
    callback: (Result<Unit>) -> Unit,
  ) {
    callback(Result.failure(UnsupportedOperationException("stage2")))
  }

  override fun deleteRecordsByIds(
    recordType: String,
    recordIds: List<String>,
    callback: (Result<Unit>) -> Unit,
  ) {
    callback(Result.failure(UnsupportedOperationException("stage2")))
  }

  override fun filterExistingClientIds(
    recordType: String,
    clientRecordIds: List<String>,
    callback: (Result<List<String>>) -> Unit,
  ) {
    callback(Result.failure(UnsupportedOperationException("stage2")))
  }
}
