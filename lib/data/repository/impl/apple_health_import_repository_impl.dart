import 'package:health/health.dart';

import '../../../health/health_data_source.dart';
import '../contract/apple_health_import_repository.dart';

/// Port of the Kotlin `AppleHealthImportRepository`.
///
/// The Kotlin version bulk-inserts AndroidX `Record`s and queries them by
/// `clientRecordId`. The `health` package exposes neither a bulk insert nor a
/// clientRecordId query, so these operations are best-effort no-ops here.
class AppleHealthImportRepositoryImpl implements AppleHealthImportRepository {
  AppleHealthImportRepositoryImpl(this._dataSource);

  final HealthDataSource _dataSource;

  @override
  bool isMindfulnessAvailable() => _dataSource.isMindfulnessSessionAvailable();

  @override
  // TODO(health-pkg): no bulk `insertRecords` API; Apple Health import must be
  //   re-implemented per HealthDataType via writeHealthData. No-op for now.
  Future<void> insertImportedRecords(List<HealthDataPoint> records) async {}

  @override
  // TODO(health-pkg): clientRecordId is not queryable via the health package;
  //   imported-record de-duplication cannot be resolved. Returns empty.
  Future<Set<String>> findMatchingImportedClientRecordIds(
    HealthDataType recordType,
    DateTime start,
    DateTime end,
    Set<String> wantedIds,
  ) async =>
      const <String>{};
}
