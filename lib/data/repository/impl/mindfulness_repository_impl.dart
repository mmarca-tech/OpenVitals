import '../../../core/period/period_load_query.dart';
import '../../../core/time/local_date.dart';
import '../../../domain/model/health_connect_availability.dart';
import '../../../domain/model/mindfulness_models.dart';
import '../../../domain/model/refresh_mode.dart';
import '../../../domain/query/mindfulness_period_data.dart';
import '../../../health/health_data_source.dart';
import '../../../health/health_permissions.dart';
import '../contract/mindfulness_repository.dart';
import 'repository_exceptions.dart';
import 'repository_time.dart';

/// Port of the Kotlin `MindfulnessRepositoryImpl`.
class MindfulnessRepositoryImpl implements MindfulnessRepository {
  MindfulnessRepositoryImpl(this._dataSource);

  final HealthDataSource _dataSource;

  Future<Set<String>> _grantedIfAvailable() async =>
      _dataSource.cachedAvailability == HealthConnectAvailability.available
          ? _dataSource.grantedPermissions()
          : <String>{};

  @override
  Set<String> get mindfulnessWritePermissions => {HcPermissions.writeMindfulness};

  @override
  Future<MindfulnessPeriodData> loadMindfulnessPeriod(
    PeriodLoadQuery query, {
    RefreshMode refreshMode = RefreshMode.normal,
  }) async {
    final w = query.windows;
    return MindfulnessPeriodData(
      sessions: await loadMindfulnessSessions(w.current.start, w.current.end),
      previousSessions:
          await loadMindfulnessSessions(w.previous.start, w.previous.end),
      baselineSessions:
          await loadMindfulnessSessions(w.baseline.start, w.baseline.end),
    );
  }

  @override
  Future<List<MindfulnessSession>> loadMindfulnessSessions(
    LocalDate start,
    LocalDate end,
  ) async {
    final granted = await _grantedIfAvailable();
    if (!granted.contains(HcPermissions.readMindfulness)) return const [];
    return _dataSource.readMindfulnessSessions(
        localDayStart(start), localDayEnd(end));
  }

  @override
  bool isMindfulnessAvailable() => _dataSource.isMindfulnessSessionAvailable();

  @override
  Future<bool> hasMindfulnessWritePermission() async {
    final granted = await _grantedIfAvailable();
    return granted.containsAll(mindfulnessWritePermissions);
  }

  @override
  Future<String> writeMindfulnessSessionEntry(
    MindfulnessSessionWriteRequest request,
  ) async {
    await _requireWrite();
    return _dataSource.writeMindfulnessSessionEntry(request);
  }

  @override
  Future<MindfulnessSession?> loadMindfulnessSession(String id) =>
      _dataSource.readMindfulnessSession(id);

  @override
  Future<void> updateMindfulnessSessionEntry(
    String id,
    MindfulnessSessionWriteRequest request,
  ) async {
    await _requireWrite();
    await _dataSource.updateMindfulnessSessionEntry(id, request);
  }

  @override
  Future<void> deleteMindfulnessSessionEntry(String id) async {
    await _requireWrite();
    await _dataSource.deleteMindfulnessSessionEntry(id);
  }

  Future<void> _requireWrite() async {
    if (!isMindfulnessAvailable()) {
      throw const MissingHealthPermissionException(
        'Mindfulness sessions are not available on this platform.',
      );
    }
    final granted = await _grantedIfAvailable();
    if (!granted.containsAll(mindfulnessWritePermissions)) {
      throw const MissingHealthPermissionException(
        'Missing Health Connect mindfulness write permission.',
      );
    }
  }
}
