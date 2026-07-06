import '../../../core/period/period_load_query.dart';
import '../../../core/time/local_date.dart';
import '../../../domain/model/caffeine_models.dart';
import '../../../domain/model/nutrition_models.dart';
import '../../../domain/model/refresh_mode.dart';
import '../../../domain/query/hydration_period_data.dart';

/// Port of the Kotlin `HydrationRepository` contract.
abstract interface class HydrationRepository {
  Set<String> get hydrationWritePermissions;

  Map<String, double> hydrationContainerVolumeMilliliters();

  void setHydrationContainerVolumeMilliliters(
    String containerId,
    double milliliters,
  );

  double? lastCustomHydrationAmountMilliliters();

  void setLastCustomHydrationAmountMilliliters(double milliliters);

  List<CustomHydrationDrink> customHydrationDrinks();

  void saveCustomHydrationDrink(CustomHydrationDrink drink);

  void deleteCustomHydrationDrink(String drinkId);

  void reorderCustomHydrationDrinks(List<String> drinkIds);

  void moveCustomHydrationDrinkToCategory(
    String drinkId,
    CaffeineSourceCategory? category,
  );

  double hydrationDailyGoalLiters();

  Future<HydrationPeriodData> loadHydrationPeriod(
    PeriodLoadQuery query, {
    RefreshMode refreshMode = RefreshMode.normal,
  });

  Future<List<DailyHydration>> loadDailyHydration(LocalDate start, LocalDate end);

  Future<List<HydrationEntry>> loadHydrationEntries(
    LocalDate start,
    LocalDate end,
  );

  Future<bool> hasHydrationWritePermission();

  Future<String> writeHydrationEntry(HydrationWriteRequest request);

  Future<HydrationEntry?> loadHydrationEntry(String id);

  Future<void> updateHydrationEntry(String id, HydrationWriteRequest request);

  Future<void> deleteHydrationEntry(String id);
}
