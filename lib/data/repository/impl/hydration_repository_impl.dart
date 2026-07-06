import 'dart:async';

import '../../../core/period/period_load_query.dart';
import '../../../core/period/time_range.dart';
import '../../../core/time/local_date.dart';
import '../../../data/local/beverage/beverage_store.dart';
import '../../../data/prefs/preferences_repository.dart';
import '../../../domain/model/caffeine_models.dart';
import '../../../domain/model/health_connect_availability.dart';
import '../../../domain/model/nutrition_models.dart';
import '../../../domain/model/refresh_mode.dart';
import '../../../domain/query/hydration_period_data.dart';
import '../../../health/health_data_source.dart';
import '../../../health/health_permissions.dart';
import '../contract/hydration_repository.dart';
import 'repository_exceptions.dart';
import 'repository_time.dart';

/// Port of the Kotlin `HydrationRepositoryImpl`.
///
/// Custom-drink state uses the (synchronous) [PreferencesRepository]; category
/// moves delegate to the (async) [BeverageStore] when present, fired without
/// awaiting to preserve the contract's synchronous `void` shape (matching the
/// Kotlin `apply()` semantics).
class HydrationRepositoryImpl implements HydrationRepository {
  HydrationRepositoryImpl(
    this._dataSource, {
    PreferencesRepository? preferencesRepository,
    BeverageStore? beverageStore,
  })  : _preferences = preferencesRepository,
        _beverages = beverageStore;

  final HealthDataSource _dataSource;
  final PreferencesRepository? _preferences;
  final BeverageStore? _beverages;

  Future<Set<String>> _grantedIfAvailable() async =>
      _dataSource.cachedAvailability == HealthConnectAvailability.available
          ? _dataSource.grantedPermissions()
          : <String>{};

  @override
  Set<String> get hydrationWritePermissions => {HcPermissions.writeHydration};

  @override
  Map<String, double> hydrationContainerVolumeMilliliters() =>
      _preferences?.hydrationContainerVolumeMilliliters() ?? <String, double>{};

  @override
  void setHydrationContainerVolumeMilliliters(
    String containerId,
    double milliliters,
  ) =>
      _preferences?.setHydrationContainerVolumeMilliliters(
          containerId, milliliters);

  @override
  double? lastCustomHydrationAmountMilliliters() =>
      _preferences?.lastCustomHydrationAmountMilliliters();

  @override
  void setLastCustomHydrationAmountMilliliters(double milliliters) =>
      _preferences?.setLastCustomHydrationAmountMilliliters(milliliters);

  @override
  List<CustomHydrationDrink> customHydrationDrinks() =>
      _preferences?.customHydrationDrinks() ?? const <CustomHydrationDrink>[];

  @override
  void saveCustomHydrationDrink(CustomHydrationDrink drink) =>
      _preferences?.saveCustomHydrationDrink(drink);

  @override
  void deleteCustomHydrationDrink(String drinkId) =>
      _preferences?.deleteCustomHydrationDrink(drinkId);

  @override
  void reorderCustomHydrationDrinks(List<String> drinkIds) =>
      _preferences?.reorderCustomHydrationDrinks(drinkIds);

  @override
  void moveCustomHydrationDrinkToCategory(
    String drinkId,
    CaffeineSourceCategory? category,
  ) {
    // BeverageStore.moveToCategory is async; fire without awaiting.
    final future = _beverages?.moveToCategory(drinkId, category);
    if (future != null) unawaited(future);
  }

  @override
  double hydrationDailyGoalLiters() =>
      _preferences?.hydrationDailyGoalLiters ?? 2.0;

  @override
  Future<HydrationPeriodData> loadHydrationPeriod(
    PeriodLoadQuery query, {
    RefreshMode refreshMode = RefreshMode.normal,
  }) async {
    final granted = await _grantedIfAvailable();
    final hasPerm = granted.contains(HcPermissions.readHydration);
    final w = query.windows;
    final isDay = query.range == TimeRange.day;

    final entries = hasPerm
        ? await _dataSource.readHydrationEntries(
            localDayStart(w.current.start), localDayEnd(w.current.end))
        : const <HydrationEntry>[];

    final dailyHydration = isDay
        ? _hydrationForDay(entries, query.selectedDate)
        : (hasPerm
            ? await _dataSource.readDailyHydration(w.current.start, w.current.end)
            : const <DailyHydration>[]);
    final previous = hasPerm
        ? await _dataSource.readDailyHydration(w.previous.start, w.previous.end)
        : const <DailyHydration>[];
    final baseline = hasPerm
        ? await _dataSource.readDailyHydration(w.baseline.start, w.baseline.end)
        : const <DailyHydration>[];

    return HydrationPeriodData(
      dailyHydration: dailyHydration,
      previousDailyHydration: previous,
      baselineDailyHydration: baseline,
      hydrationEntries: entries,
    );
  }

  @override
  Future<List<DailyHydration>> loadDailyHydration(
    LocalDate start,
    LocalDate end,
  ) async {
    final granted = await _grantedIfAvailable();
    if (!granted.contains(HcPermissions.readHydration)) return const [];
    return _dataSource.readDailyHydration(start, end);
  }

  @override
  Future<List<HydrationEntry>> loadHydrationEntries(
    LocalDate start,
    LocalDate end,
  ) async {
    final granted = await _grantedIfAvailable();
    if (!granted.contains(HcPermissions.readHydration)) return const [];
    return _dataSource.readHydrationEntries(localDayStart(start), localDayEnd(end));
  }

  @override
  Future<bool> hasHydrationWritePermission() async {
    final granted = await _grantedIfAvailable();
    return granted.containsAll(hydrationWritePermissions);
  }

  @override
  Future<String> writeHydrationEntry(HydrationWriteRequest request) async {
    await _requireWrite();
    return _dataSource.writeHydrationEntry(request);
  }

  @override
  Future<HydrationEntry?> loadHydrationEntry(String id) =>
      _dataSource.readHydrationEntry(id);

  @override
  Future<void> updateHydrationEntry(
    String id,
    HydrationWriteRequest request,
  ) async {
    await _requireWrite();
    await _dataSource.updateHydrationEntry(id, request);
  }

  @override
  Future<void> deleteHydrationEntry(String id) async {
    await _requireWrite();
    final clientRecordId = await _dataSource.deleteHydrationEntry(id);
    if (clientRecordId != null) {
      final granted = await _grantedIfAvailable();
      if (granted.contains(HcPermissions.writeNutrition)) {
        await _dataSource.deleteHydrationNutritionEntry(clientRecordId);
      }
    }
  }

  Future<void> _requireWrite() async {
    final granted = await _grantedIfAvailable();
    if (!granted.containsAll(hydrationWritePermissions)) {
      throw const MissingHealthPermissionException(
        'Missing Health Connect hydration write permission.',
      );
    }
  }

  List<DailyHydration> _hydrationForDay(
    List<HydrationEntry> entries,
    LocalDate selectedDate,
  ) {
    var liters = 0.0;
    for (final entry in entries) {
      final date = LocalDate.fromDateTime(entry.startTime.toLocal());
      if (date == selectedDate) liters += entry.liters;
    }
    if (liters <= 0) return const [];
    return [DailyHydration(date: selectedDate, liters: liters)];
  }
}
