// Port of the Kotlin `HealthConnectPermissionService` permission taxonomy.
//
// In the Kotlin source a permission is an AndroidX Health Connect permission
// string (e.g. `android.permission.health.READ_STEPS`). We keep those exact
// string identifiers so the phased sets, `PERMISSION_SET_VERSION`, and any
// persisted permission state remain byte-for-byte faithful to the original.
//
// The mapping from each permission string to the Dart `health` package's
// HealthDataType + HealthDataAccess lives here in HealthPermissionMapping.
// Where a Health Connect record has no `health` package equivalent the mapping
// is null — those permissions are still carried in the taxonomy (so the sets
// match Kotlin) but are skipped when a concrete authorization request is built.
// Every such gap is documented with a `// TODO(health-pkg):` comment.
import 'package:health/health.dart';

import '../domain/model/permission_grant_mode.dart';

/// AndroidX permission-string prefix, mirrored verbatim from Health Connect.
const String _hcPrefix = 'android.permission.health.';

String _read(String record) => '${_hcPrefix}READ_$record';

String _write(String record) => '${_hcPrefix}WRITE_$record';

/// Individual Health Connect permission strings, mirroring the per-record
/// `readXPermission` / `writeXPermission` fields the Kotlin repositories and
/// `DashboardDataLoader` keep. Values are the exact AndroidX permission strings.
abstract final class HcPermissions {
  static final String readSteps = _read('STEPS');
  static final String readDistance = _read('DISTANCE');
  static final String readExercise = _read('EXERCISE');
  static final String readSleep = _read('SLEEP');
  static final String readHeartRate = _read('HEART_RATE');
  static final String readRestingHeartRate = _read('RESTING_HEART_RATE');
  static final String readHrv = _read('HEART_RATE_VARIABILITY');
  static final String readWeight = _read('WEIGHT');
  static final String readHeight = _read('HEIGHT');
  static final String readBodyFat = _read('BODY_FAT');
  static final String readLeanMass = _read('LEAN_BODY_MASS');
  static final String readBmr = _read('BASAL_METABOLIC_RATE');
  static final String readBoneMass = _read('BONE_MASS');
  static final String readBodyWaterMass = _read('BODY_WATER_MASS');
  static final String readTotalCalories = _read('TOTAL_CALORIES_BURNED');
  static final String readActiveCalories = _read('ACTIVE_CALORIES_BURNED');
  static final String readHydration = _read('HYDRATION');
  static final String readNutrition = _read('NUTRITION');
  static final String readBloodPressure = _read('BLOOD_PRESSURE');
  static final String readSpO2 = _read('OXYGEN_SATURATION');
  static final String readVo2Max = _read('VO2_MAX');
  static final String readRespiratoryRate = _read('RESPIRATORY_RATE');
  static final String readBodyTemperature = _read('BODY_TEMPERATURE');
  static final String readBloodGlucose = _read('BLOOD_GLUCOSE');
  static final String readSkinTemperature = _read('SKIN_TEMPERATURE');
  static final String readFloors = _read('FLOORS_CLIMBED');
  static final String readElevation = _read('ELEVATION_GAINED');
  static final String readWheelchairPushes = _read('WHEELCHAIR_PUSHES');
  static final String readMindfulness = _read('MINDFULNESS');
  static final String readMenstruationFlow = _read('MENSTRUATION');
  static final String readMenstruationPeriod = _read('MENSTRUATION_PERIOD');
  static final String readOvulationTest = _read('OVULATION_TEST');
  static final String readCervicalMucus = _read('CERVICAL_MUCUS');
  static final String readBasalBodyTemperature = _read('BASAL_BODY_TEMPERATURE');
  static final String readIntermenstrualBleeding =
      _read('INTERMENSTRUAL_BLEEDING');
  static final String readSexualActivity = _read('SEXUAL_ACTIVITY');

  static final String writeExercise = _write('EXERCISE');
  static final String writeExerciseRoute = _write('EXERCISE_ROUTE');
  static final String writeSteps = _write('STEPS');
  static final String writeDistance = _write('DISTANCE');
  static final String writeElevation = _write('ELEVATION_GAINED');
  static final String writeActiveCalories = _write('ACTIVE_CALORIES_BURNED');
  static final String writeTotalCalories = _write('TOTAL_CALORIES_BURNED');
  static final String writeHydration = _write('HYDRATION');
  static final String writeNutrition = _write('NUTRITION');
  static final String writeWeight = _write('WEIGHT');
  static final String writeHeight = _write('HEIGHT');
  static final String writeBodyFat = _write('BODY_FAT');
  static final String writeBloodPressure = _write('BLOOD_PRESSURE');
  static final String writeSpO2 = _write('OXYGEN_SATURATION');
  static final String writeRespiratoryRate = _write('RESPIRATORY_RATE');
  static final String writeBodyTemperature = _write('BODY_TEMPERATURE');
  static final String writeMindfulness = _write('MINDFULNESS');
}

/// A resolved mapping of a Health Connect permission onto the `health`
/// package's authorization primitives.
///
/// [types] can hold more than one [HealthDataType] (e.g. blood pressure maps to
/// both systolic and diastolic types); [access] is shared by all of them.
class HealthPermissionMapping {
  const HealthPermissionMapping(this.types, this.access);

  final List<HealthDataType> types;
  final HealthDataAccess access;
}

/// Feature-availability inputs that gate parts of the taxonomy, mirroring the
/// Kotlin `isMindfulnessSessionAvailable()` / `isSkinTemperatureAvailable()` /
/// `isPlannedExerciseAvailable()` / history / background feature checks.
///
/// Resolved once from [HealthDataSource] and passed in so the taxonomy stays
/// pure and unit-testable.
class HealthConnectFeatureFlags {
  const HealthConnectFeatureFlags({
    this.mindfulnessAvailable = false,
    this.skinTemperatureAvailable = false,
    this.plannedExerciseAvailable = false,
    this.healthDataHistoryAvailable = false,
    this.backgroundReadAvailable = false,
  });

  /// Health Connect on Android is not exposed as a mindfulness data type by the
  /// `health` package (v13.3.1 only lists `MINDFULNESS` for iOS/HealthKit), so
  /// this is effectively false on Android.
  final bool mindfulnessAvailable;
  final bool skinTemperatureAvailable;

  /// No `health` package equivalent for planned exercise sessions — always
  /// false. Kept for parity with the Kotlin gating.
  final bool plannedExerciseAvailable;
  final bool healthDataHistoryAvailable;
  final bool backgroundReadAvailable;
}

/// Faithful Dart port of `HealthConnectPermissionService`.
///
/// Pure and synchronous: all sets are derived from the injected
/// [HealthConnectFeatureFlags]. Callers resolve the flags from the platform via
/// [HealthDataSource] and construct this once.
class HealthPermissionService {
  const HealthPermissionService([
    this.flags = const HealthConnectFeatureFlags(),
  ]);

  final HealthConnectFeatureFlags flags;

  /// Bump when requestable/managed permissions change so existing users see the
  /// new-permissions prompt. Mirrors the Kotlin constant.
  // ignore: constant_identifier_names
  static const int PERMISSION_SET_VERSION = 2;

  // ── Special (non record-backed) permission strings ────────────────────────
  static final String readExerciseRoutesPermission = _read('EXERCISE_ROUTES');
  static final String writeExerciseRoutePermission = _write('EXERCISE_ROUTE');
  static final String readHealthDataHistoryPermission =
      '${_hcPrefix}READ_HEALTH_DATA_HISTORY';
  static final String readHealthDataInBackgroundPermission =
      '${_hcPrefix}READ_HEALTH_DATA_IN_BACKGROUND';

  // ── Base category sets (mirror the Kotlin `val`s) ─────────────────────────

  Set<String> get corePermissions => {
        _read('STEPS'),
        _read('DISTANCE'),
        _read('EXERCISE'),
        _read('SLEEP'),
      };

  Set<String> get routePermissions => {readExerciseRoutesPermission};

  Set<String> get activityWritePermissions => {
        _write('EXERCISE'),
        _write('DISTANCE'),
        _write('ELEVATION_GAINED'),
        _write('ACTIVE_CALORIES_BURNED'),
        _write('TOTAL_CALORIES_BURNED'),
        writeExerciseRoutePermission,
        _write('HEART_RATE'),
        _write('POWER'),
        _write('SPEED'),
        _write('CYCLING_PEDALING_CADENCE'),
        _write('STEPS_CADENCE'),
      };

  Set<String> get plannedExercisePermissions => flags.plannedExerciseAvailable
      ? {_read('PLANNED_EXERCISE'), _write('PLANNED_EXERCISE')}
      : <String>{};

  Set<String> get heartPermissions => {
        _read('HEART_RATE'),
        _read('RESTING_HEART_RATE'),
        _read('HEART_RATE_VARIABILITY'),
      };

  Set<String> get bodyPermissions => {
        _read('WEIGHT'),
        _read('HEIGHT'),
        _read('BODY_FAT'),
        _read('LEAN_BODY_MASS'),
        _read('BASAL_METABOLIC_RATE'),
        _read('BONE_MASS'),
        _read('BODY_WATER_MASS'),
      };

  Set<String> get activityExtrasPermissions => {
        _read('FLOORS_CLIMBED'),
        _read('ACTIVE_CALORIES_BURNED'),
        _read('ELEVATION_GAINED'),
        _read('WHEELCHAIR_PUSHES'),
        _read('TOTAL_CALORIES_BURNED'),
        _read('SPEED'),
        _read('POWER'),
        _read('STEPS_CADENCE'),
        _read('CYCLING_PEDALING_CADENCE'),
        ...plannedExercisePermissions,
      };

  Set<String> get nutritionHydrationPermissions => {
        _read('HYDRATION'),
        _read('NUTRITION'),
      };

  Set<String> get hydrationWritePermissions => {_write('HYDRATION')};

  Set<String> get nutritionWritePermissions => {_write('NUTRITION')};

  Set<String> get bodyWritePermissions => {
        _write('WEIGHT'),
        _write('HEIGHT'),
        _write('BODY_FAT'),
      };

  Set<String> get mindfulnessPermissions => {_read('MINDFULNESS')};

  Set<String> get mindfulnessWritePermissions => {_write('MINDFULNESS')};

  Set<String> get additionalDataAccessPermissions => {
        if (flags.healthDataHistoryAvailable) readHealthDataHistoryPermission,
        if (flags.backgroundReadAvailable)
          readHealthDataInBackgroundPermission,
      };

  Set<String> get vitalsPermissions => {
        _read('BLOOD_PRESSURE'),
        _read('OXYGEN_SATURATION'),
        _read('RESPIRATORY_RATE'),
        _read('BODY_TEMPERATURE'),
        _read('VO2_MAX'),
        _read('BLOOD_GLUCOSE'),
        if (flags.skinTemperatureAvailable) _read('SKIN_TEMPERATURE'),
      };

  Set<String> get vitalsWritePermissions => {
        _write('BLOOD_PRESSURE'),
        _write('OXYGEN_SATURATION'),
        _write('RESPIRATORY_RATE'),
        _write('BODY_TEMPERATURE'),
      };

  Set<String> get dataImportWritePermissions => {
        _write('STEPS'),
        _write('DISTANCE'),
        _write('EXERCISE'),
        writeExerciseRoutePermission,
        _write('ACTIVE_CALORIES_BURNED'),
        _write('TOTAL_CALORIES_BURNED'),
        _write('FLOORS_CLIMBED'),
        _write('ELEVATION_GAINED'),
        _write('WHEELCHAIR_PUSHES'),
        _write('SPEED'),
        _write('HEART_RATE'),
        _write('RESTING_HEART_RATE'),
        _write('HEART_RATE_VARIABILITY'),
        _write('WEIGHT'),
        _write('HEIGHT'),
        _write('BODY_FAT'),
        _write('LEAN_BODY_MASS'),
        _write('BASAL_METABOLIC_RATE'),
        _write('BONE_MASS'),
        _write('BODY_WATER_MASS'),
        _write('HYDRATION'),
        _write('NUTRITION'),
        _write('SLEEP'),
        _write('BLOOD_PRESSURE'),
        _write('OXYGEN_SATURATION'),
        _write('RESPIRATORY_RATE'),
        _write('BODY_TEMPERATURE'),
        _write('BLOOD_GLUCOSE'),
        _write('VO2_MAX'),
        if (flags.mindfulnessAvailable) _write('MINDFULNESS'),
        _write('MENSTRUATION'),
        _write('OVULATION_TEST'),
        _write('CERVICAL_MUCUS'),
        _write('BASAL_BODY_TEMPERATURE'),
        _write('INTERMENSTRUAL_BLEEDING'),
        _write('SEXUAL_ACTIVITY'),
      };

  Set<String> get cyclePermissions => {
        _read('MENSTRUATION'),
        _read('MENSTRUATION_PERIOD'),
        _read('OVULATION_TEST'),
        _read('CERVICAL_MUCUS'),
        _read('BASAL_BODY_TEMPERATURE'),
        _read('INTERMENSTRUAL_BLEEDING'),
        _read('SEXUAL_ACTIVITY'),
      };

  // ── Derived / phased sets ─────────────────────────────────────────────────

  Set<String> get minimumOnboardingPermissions => {
        ...corePermissions,
        ...heartPermissions,
        ...vitalsPermissions,
      };

  Set<String> get phase1Permissions => corePermissions;

  Set<String> get phase2Permissions => {
        ...heartPermissions,
        ...bodyPermissions,
        ...activityExtrasPermissions,
        ...nutritionHydrationPermissions,
        if (flags.mindfulnessAvailable) ...mindfulnessPermissions,
      };

  Set<String> get phase3Permissions => vitalsPermissions;

  Set<String> get phase4Permissions => cyclePermissions;

  Set<String> get manualOnlyPermissions => routePermissions;

  Set<String> get requestableAllPermissions => {
        ...phase1Permissions,
        ...phase2Permissions,
      };

  Set<String> get requestableWritePermissions => {
        ...activityWritePermissions,
        ...plannedExercisePermissions,
        ...hydrationWritePermissions,
        ...nutritionWritePermissions,
        ...bodyWritePermissions,
        ...vitalsWritePermissions,
        if (flags.mindfulnessAvailable) ...mindfulnessWritePermissions,
      };

  Set<String> get onboardingPermissions => {
        ...requestableAllPermissions,
        ...phase3Permissions,
        ...phase4Permissions,
        ...additionalDataAccessPermissions,
        ...requestableWritePermissions,
        ...dataImportWritePermissions,
      };

  Set<String> get requestableManagedPermissions => {
        ...onboardingPermissions,
        ...phase4Permissions,
      };

  Set<String> get allPermissions => {
        ...requestableAllPermissions,
        ...phase3Permissions,
        ...phase4Permissions,
        ...additionalDataAccessPermissions,
        ...manualOnlyPermissions,
        ...activityWritePermissions,
        ...plannedExercisePermissions,
        ...hydrationWritePermissions,
        ...nutritionWritePermissions,
        ...bodyWritePermissions,
        ...vitalsWritePermissions,
        ...mindfulnessWritePermissions,
        ...dataImportWritePermissions,
      };

  Set<String> get managedPermissions => {
        ...requestableManagedPermissions,
        ...manualOnlyPermissions,
        ...activityWritePermissions,
        ...plannedExercisePermissions,
        ...hydrationWritePermissions,
        ...nutritionWritePermissions,
        ...bodyWritePermissions,
        ...vitalsWritePermissions,
        ...mindfulnessWritePermissions,
        ...dataImportWritePermissions,
      };

  PermissionGrantMode grantModeFor(String permission) =>
      manualOnlyPermissions.contains(permission)
          ? PermissionGrantMode.manual
          : PermissionGrantMode.requestable;

  bool isMindfulnessAvailable() => flags.mindfulnessAvailable;

  // ── Mapping onto the `health` package ─────────────────────────────────────

  /// Resolves a single permission string onto its `health` package
  /// [HealthDataType]s + [HealthDataAccess], or `null` when the underlying
  /// Health Connect record has no `health` package equivalent (see the gap
  /// list below).
  static HealthPermissionMapping? mappingFor(String permission) {
    final isWrite = permission.startsWith('${_hcPrefix}WRITE_');
    final access = isWrite ? HealthDataAccess.WRITE : HealthDataAccess.READ;
    final record = permission
        .replaceFirst('${_hcPrefix}READ_', '')
        .replaceFirst('${_hcPrefix}WRITE_', '');
    final types = _recordToTypes[record];
    if (types == null || types.isEmpty) return null;
    return HealthPermissionMapping(types, access);
  }

  /// Whether [permission] can be expressed with the `health` package.
  static bool isMappable(String permission) => mappingFor(permission) != null;

  /// Builds the parallel `types` / `permissions` lists the `health` package's
  /// `requestAuthorization` / `hasPermissions` expect, skipping unmappable
  /// permissions. A single record permission that maps to multiple types
  /// (blood pressure) expands into multiple entries.
  static ({List<HealthDataType> types, List<HealthDataAccess> accesses})
      resolve(Iterable<String> permissions) {
    final types = <HealthDataType>[];
    final accesses = <HealthDataAccess>[];
    final seen = <String>{};
    for (final permission in permissions) {
      final mapping = mappingFor(permission);
      if (mapping == null) continue;
      for (final type in mapping.types) {
        // De-duplicate on (type, access) so overlapping permission sets don't
        // request the same authorization twice.
        final key = '${type.name}:${mapping.access.name}';
        if (!seen.add(key)) continue;
        types.add(type);
        accesses.add(mapping.access);
      }
    }
    return (types: types, accesses: accesses);
  }

  /// Health Connect record token (the part after `READ_`/`WRITE_`) → the
  /// `health` package [HealthDataType]s it maps to.
  ///
  /// Records intentionally ABSENT from this map are the documented gaps — the
  /// `health` package (v13.3.1) exposes no Android data type for them, so their
  /// permissions are carried in the taxonomy but cannot be requested/queried:
  ///   // TODO(health-pkg): BONE_MASS — no HealthDataType for BoneMassRecord.
  ///   // TODO(health-pkg): ELEVATION_GAINED — no HealthDataType.
  ///   // TODO(health-pkg): WHEELCHAIR_PUSHES — no HealthDataType.
  ///   // TODO(health-pkg): POWER — no HealthDataType.
  ///   // TODO(health-pkg): STEPS_CADENCE — no HealthDataType.
  ///   // TODO(health-pkg): CYCLING_PEDALING_CADENCE — no HealthDataType.
  ///   // TODO(health-pkg): VO2_MAX — no HealthDataType for Vo2MaxRecord.
  ///   // TODO(health-pkg): PLANNED_EXERCISE — no HealthDataType.
  ///   // TODO(health-pkg): MINDFULNESS — Android unsupported (iOS-only in pkg).
  ///   // TODO(health-pkg): MENSTRUATION_PERIOD — only MENSTRUATION_FLOW exists.
  ///   // TODO(health-pkg): OVULATION_TEST / CERVICAL_MUCUS /
  ///   //   BASAL_BODY_TEMPERATURE / INTERMENSTRUAL_BLEEDING / SEXUAL_ACTIVITY.
  ///   // TODO(health-pkg): EXERCISE_ROUTES / EXERCISE_ROUTE / HEALTH_DATA_*
  ///   //   are special (non record) permissions handled via dedicated
  ///   //   `health` package APIs (WORKOUT_ROUTE type, isHealthDataHistory*,
  ///   //   isHealthDataInBackground*), not this record map.
  static final Map<String, List<HealthDataType>> _recordToTypes = {
    'STEPS': [HealthDataType.STEPS],
    'DISTANCE': [HealthDataType.DISTANCE_DELTA],
    'EXERCISE': [HealthDataType.WORKOUT],
    'SLEEP': [HealthDataType.SLEEP_SESSION],
    'HEART_RATE': [HealthDataType.HEART_RATE],
    'RESTING_HEART_RATE': [HealthDataType.RESTING_HEART_RATE],
    'HEART_RATE_VARIABILITY': [HealthDataType.HEART_RATE_VARIABILITY_RMSSD],
    'WEIGHT': [HealthDataType.WEIGHT],
    'HEIGHT': [HealthDataType.HEIGHT],
    'BODY_FAT': [HealthDataType.BODY_FAT_PERCENTAGE],
    'LEAN_BODY_MASS': [HealthDataType.LEAN_BODY_MASS],
    // BasalMetabolicRateRecord is surfaced by the health package as
    // BASAL_ENERGY_BURNED (value = kcal/day).
    'BASAL_METABOLIC_RATE': [HealthDataType.BASAL_ENERGY_BURNED],
    'BODY_WATER_MASS': [HealthDataType.BODY_WATER_MASS],
    'ACTIVE_CALORIES_BURNED': [HealthDataType.ACTIVE_ENERGY_BURNED],
    'TOTAL_CALORIES_BURNED': [HealthDataType.TOTAL_CALORIES_BURNED],
    // FloorsClimbedRecord is surfaced by the health package as FLIGHTS_CLIMBED.
    'FLOORS_CLIMBED': [HealthDataType.FLIGHTS_CLIMBED],
    'SPEED': [HealthDataType.SPEED],
    'HYDRATION': [HealthDataType.WATER],
    'NUTRITION': [HealthDataType.NUTRITION],
    'BLOOD_PRESSURE': [
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    ],
    'OXYGEN_SATURATION': [HealthDataType.BLOOD_OXYGEN],
    'RESPIRATORY_RATE': [HealthDataType.RESPIRATORY_RATE],
    'BODY_TEMPERATURE': [HealthDataType.BODY_TEMPERATURE],
    'BLOOD_GLUCOSE': [HealthDataType.BLOOD_GLUCOSE],
    'SKIN_TEMPERATURE': [HealthDataType.SKIN_TEMPERATURE],
    'MENSTRUATION': [HealthDataType.MENSTRUATION_FLOW],
  };
}
