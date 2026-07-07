import '../../../features/imports/applehealth/apple_health_import_records.dart';

/// Port of the Kotlin `AppleHealthImportRepository` contract.
///
/// The Kotlin version takes AndroidX `Record` / `KClass<out Record>` types; the
/// Dart importer produces pure-Dart [ImportRecord]s and identifies a record
/// class by its [ImportRecord.targetType] string (e.g. `HeartRateRecord`), so
/// the signatures are adapted accordingly.
///
// TODO(health-pkg): the `health` package has no bulk `insertRecords(records)`
//   equivalent nor a clientRecordId query API; imports are written one
//   HealthDataType at a time via `writeHealthData(clientRecordId: ...)` and
//   duplicate matching by clientRecordId cannot be resolved on read. The impl
//   over [HealthDataSource.insertImportedRecords] is therefore best-effort.
abstract interface class AppleHealthImportRepository {
  bool isMindfulnessAvailable();

  Future<void> insertImportedRecords(List<ImportRecord> records);

  Future<Set<String>> findMatchingImportedClientRecordIds(
    String recordType,
    DateTime start,
    DateTime end,
    Set<String> wantedIds,
  );
}
