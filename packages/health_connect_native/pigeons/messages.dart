// Pigeon contract for the `health_connect_native` plugin.
//
// This file defines the Flutter <-> AndroidX Health Connect (Kotlin) bridge.
// It is the SINGLE SOURCE OF TRUTH for the generated message classes:
//
//   * Dart   -> lib/src/messages.g.dart
//   * Kotlin -> android/src/main/kotlin/tech/mmarca/openvitals/health_connect_native/Messages.g.kt
//
// Regenerate both after editing this file (run from the plugin directory):
//
//   dart run pigeon --input pigeons/messages.dart
//
// DESIGN NOTE
// -----------
// Health Connect records are numerous and deeply nested. To keep the Pigeon
// surface small and STABLE across the record-type explosion, records travel the
// bridge as JSON STRINGS (one JSON object per record), while OPERATIONS
// (permissions, feature checks, aggregation, delete/dedup) are strongly typed.
// The canonical record JSON schema is documented in
// `lib/health_connect_native.dart` so the Kotlin (Stage 2) and Dart (Stage 3)
// sides agree without a wide Pigeon data-class surface.
import 'package:pigeon/pigeon.dart';

/// Raw Health Connect availability signals, mapped to the Dart
/// `HealthConnectAvailability` enum on the Flutter side. Kept as separate
/// signals (rather than a native enum) so the enum stays a single source of
/// truth in Dart.
class HealthConnectAvailabilityDetail {
  /// Raw `HealthConnectClient.getSdkStatus` int.
  final int sdkStatus;

  /// True when running in a work/managed profile where Health Connect is
  /// unsupported (Android 13+).
  final bool unsupportedProfile;

  /// True when the standalone Health Connect APK is installed on Android 13-
  /// but the Play Store is not (so it can never be updated).
  final bool standaloneNeedsPlayStore;

  HealthConnectAvailabilityDetail(
    this.sdkStatus,
    this.unsupportedProfile,
    this.standaloneNeedsPlayStore,
  );
}

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut:
        'android/src/main/kotlin/tech/mmarca/openvitals/health_connect_native/Messages.g.kt',
    kotlinOptions: KotlinOptions(
      package: 'tech.mmarca.openvitals.health_connect_native',
    ),
    dartPackageName: 'health_connect_native',
  ),
)

/// Host (Android/Kotlin) API surface backed by `HealthConnectClient`.
///
/// All record payloads are JSON strings; see the record JSON schema in
/// `lib/health_connect_native.dart`. Permission strings are Health Connect
/// permission identifiers (e.g. `android.permission.health.READ_STEPS`).
@HostApi()
abstract class HealthConnectHostApi {
  /// Maps to `HealthConnectClient.getSdkStatus(context)`.
  ///
  /// Returns the raw SDK status int (e.g. `SDK_AVAILABLE`,
  /// `SDK_UNAVAILABLE`, `SDK_UNAVAILABLE_PROVIDER_UPDATE_REQUIRED`).
  int getSdkStatus();

  /// Fuller availability picture than [getSdkStatus]: SDK status plus the
  /// work-profile and standalone-needs-Play-Store overrides, so Dart can resolve
  /// NOT_SUPPORTED / NEEDS_PLAY_STORE / NEEDS_PROVIDER_UPDATE / AVAILABLE.
  HealthConnectAvailabilityDetail availabilityDetail();

  /// Mirrors the user's "pause Health Connect sync" toggle into the native
  /// sync-gate. While disabled, reads short-circuit to empty and writes throw.
  void setSyncEnabled(bool enabled);

  /// Returns the native sync-gate's current state.
  bool getSyncEnabled();

  /// Returns the subset of [permissions] currently granted.
  @async
  List<String> getGrantedPermissions(List<String> permissions);

  /// Launches the Health Connect permission contract via the Activity and
  /// resolves to whether every requested permission ended up granted.
  @async
  bool requestPermissions(List<String> permissions);

  /// Opens the Health Connect page for this app (app-specific permission
  /// management on Android 14+, falling back to Health Connect settings) so the
  /// user can manually grant permissions the runtime dialog reports as
  /// non-requestable (e.g. planned exercise, exercise routes, background/history
  /// access). Returns whether a page was launched.
  @async
  bool openHealthConnectSettings();

  /// Whether an optional Health Connect feature is available on this device,
  /// e.g. `"SKIN_TEMPERATURE"`, `"MINDFULNESS_SESSION"`, `"PLANNED_EXERCISE"`.
  @async
  bool isFeatureAvailable(String feature);

  /// Reads records of [recordType] in the [startEpochMs, endEpochMs] window,
  /// returning one JSON object (as a String) per record. [filterJson] is an
  /// optional JSON object carrying extra read constraints (data origins,
  /// paging, ascending/descending, page size, etc.).
  @async
  List<String> readRecordsJson(
    String recordType,
    int startEpochMs,
    int endEpochMs,
    String? filterJson,
  );

  /// Reads a single record of [recordType] by its Health Connect [recordId],
  /// or `null` if it does not exist.
  @async
  String? readRecordJson(String recordType, String recordId);

  /// Runs an aggregation over [aggregateMetrics] in the given window, returning
  /// a metric-key -> value map (value is `null` when Health Connect has no data
  /// for that metric in the window).
  @async
  Map<String, double?> aggregate(
    List<String> aggregateMetrics,
    int startEpochMs,
    int endEpochMs,
  );

  /// Aggregates [aggregateMetrics] grouped into buckets of [bucketType]
  /// (e.g. `"DAYS"`, `"WEEKS"`, `"MONTHS"`), returning one JSON object (as a
  /// String) per bucket with its time range and aggregated values.
  @async
  List<String> aggregateGroupByPeriodJson(
    List<String> aggregateMetrics,
    int startEpochMs,
    int endEpochMs,
    String bucketType,
  );

  /// Inserts the given records (each a JSON object String matching the canonical
  /// schema) and returns the inserted Health Connect record ids in order.
  @async
  List<String> insertRecordsJson(List<String> recordsJson);

  /// Deletes records of [recordType] by their app-assigned client record ids.
  @async
  void deleteRecordsByClientIds(String recordType, List<String> clientRecordIds);

  /// Deletes records of [recordType] by their Health Connect record ids.
  @async
  void deleteRecordsByIds(String recordType, List<String> recordIds);

  /// Import dedup helper: of the supplied [clientRecordIds], returns the subset
  /// that ALREADY exist in Health Connect for [recordType].
  @async
  List<String> filterExistingClientIds(
    String recordType,
    List<String> clientRecordIds,
  );
}
