import 'package:health/health.dart';

/// Port of the Kotlin `AppleHealthImportRepository` contract.
///
/// The Kotlin version takes/returns AndroidX `Record`/`KClass<out Record>`
/// types. The Dart `health` package models imported points as
/// [HealthDataPoint]s and identifies records by [HealthDataType], so the
/// signatures are adapted accordingly.
///
// TODO(health-pkg): the `health` package has no bulk `insertRecords(records)`
//   equivalent nor a clientRecordId query API; imports must be written one
//   HealthDataType at a time via `writeHealthData(clientRecordId: ...)` and
//   matched by reading points back and inspecting their metadata. The impl is
//   therefore best-effort.
abstract interface class AppleHealthImportRepository {
  bool isMindfulnessAvailable();

  Future<void> insertImportedRecords(List<HealthDataPoint> records);

  Future<Set<String>> findMatchingImportedClientRecordIds(
    HealthDataType recordType,
    DateTime start,
    DateTime end,
    Set<String> wantedIds,
  );
}
