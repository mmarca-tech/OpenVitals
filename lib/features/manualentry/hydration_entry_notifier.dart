import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/presentation/screen_error.dart';
import '../../core/time/local_date.dart';
import '../../data/repository/contract/hydration_repository.dart';
import '../../data/repository/contract/nutrition_repository.dart';
import '../../di/providers.dart';
import '../../domain/model/nutrition_models.dart';

part 'hydration_entry_notifier.freezed.dart';

const double kMillilitersPerLiter = 1000.0;
const double _maxHealthConnectHydrationLiters = 100.0;
const double kMinHydrationContainerMilliliters = 1.0;
const double kMaxHydrationContainerMilliliters =
    _maxHealthConnectHydrationLiters * kMillilitersPerLiter;

/// Port of the Kotlin `HydrationEntryError`.
enum HydrationEntryError {
  invalidAmount,
  invalidCustomDrink,
  missingWritePermission,
  missingNutritionWritePermission,
  writeFailed,
}

/// Port of the Kotlin `HydrationEntryNotice`.
enum HydrationEntryNotice {
  nonHydratingDrinkSaved,
}

/// Port of the Kotlin `HydrationContainerOption`.
@freezed
abstract class HydrationContainerOption with _$HydrationContainerOption {
  const HydrationContainerOption._();

  const factory HydrationContainerOption({
    required String id,
    required double volumeMilliliters,
  }) = _HydrationContainerOption;

  double get volumeLiters => volumeMilliliters / kMillilitersPerLiter;
}

/// The seven default containers (Kotlin `HydrationContainerOption.Defaults`).
const List<HydrationContainerOption> kDefaultHydrationContainers =
    <HydrationContainerOption>[
  HydrationContainerOption(id: 'coffee_cup', volumeMilliliters: 100.0),
  HydrationContainerOption(id: 'tea_cup', volumeMilliliters: 150.0),
  HydrationContainerOption(id: 'small_cup', volumeMilliliters: 175.0),
  HydrationContainerOption(id: 'medium_glass', volumeMilliliters: 200.0),
  HydrationContainerOption(id: 'large_glass', volumeMilliliters: 300.0),
  HydrationContainerOption(id: 'water_bottle', volumeMilliliters: 500.0),
  HydrationContainerOption(id: 'large_bottle', volumeMilliliters: 1000.0),
];

/// Riverpod port of the Kotlin `HydrationEntryUiState` (form subset). The
/// custom-drink CRUD, frequent-drink ranking and reminder controller are
/// intentionally out of scope for this batch.
@freezed
abstract class HydrationEntryState with _$HydrationEntryState {
  const HydrationEntryState._();

  const factory HydrationEntryState({
    @Default(true) bool isCheckingPermission,
    @Default(<String>{}) Set<String> hydrationWritePermissions,
    @Default(<String>{}) Set<String> nutritionWritePermissions,
    @Default(false) bool canWriteHydration,
    @Default(false) bool canWriteNutrition,
    @Default(0.0) double todayHydrationLiters,
    @Default(2.0) double dailyGoalLiters,
    @Default(false) bool isSavingEntry,
    @Default(kDefaultHydrationContainers)
    List<HydrationContainerOption> containerOptions,
    required HydrationContainerOption selectedContainer,
    double? lastCustomAmountMilliliters,
    @Default(<CustomHydrationDrink>[])
    List<CustomHydrationDrink> customDrinkOptions,
    String? editRecordId,
    DateTime? editTime,
    @Default(false) bool saveCompleted,
    HydrationEntryNotice? entryNotice,
    HydrationEntryError? entryError,
    ScreenError? writeError,
  }) = _HydrationEntryState;

  bool get isEditMode => editRecordId != null;

  Set<String> get writePermissions =>
      {...hydrationWritePermissions, ...nutritionWritePermissions};
}

/// Whether [milliliters] is an acceptable hydration volume. Port of the Kotlin
/// `isValidHydrationContainerMilliliters`.
bool isValidHydrationContainerMilliliters(double milliliters) =>
    milliliters >= kMinHydrationContainerMilliliters &&
    milliliters <= kMaxHydrationContainerMilliliters &&
    milliliters.isFinite;

bool _isValidCustomDrinkHydrationMultiplier(double value) =>
    value >= 0.0 && value <= 1.0 && value.isFinite;

bool _isValidCustomHydrationDrink(CustomHydrationDrink drink) =>
    drink.id.isNotEmpty &&
    drink.name.isNotEmpty &&
    isValidHydrationContainerMilliliters(drink.volumeMilliliters) &&
    _isValidCustomDrinkHydrationMultiplier(drink.hydrationMultiplier);

/// Riverpod port of the Kotlin `HydrationEntryViewModel`. One instance per entry
/// screen, bound to an optional edit record id.
class HydrationEntryNotifier extends Notifier<HydrationEntryState> {
  HydrationEntryNotifier({this.editRecordId});

  final String? editRecordId;

  @override
  HydrationEntryState build() {
    final repo = ref.read(hydrationRepositoryProvider);
    final options = _containerOptions(repo);
    final lastCustom = repo.lastCustomHydrationAmountMilliliters();
    final initial = HydrationEntryState(
      containerOptions: options,
      selectedContainer: options.first,
      dailyGoalLiters: repo.hydrationDailyGoalLiters(),
      lastCustomAmountMilliliters:
          (lastCustom != null && isValidHydrationContainerMilliliters(lastCustom))
              ? lastCustom
              : null,
      customDrinkOptions:
          repo.customHydrationDrinks().where(_isValidCustomHydrationDrink).toList(),
      editRecordId: editRecordId,
    );
    Future.microtask(() async {
      if (!ref.mounted) return;
      await refreshPermission();
      if (ref.mounted) await refreshTodayHydration();
      if (ref.mounted) await _loadEditEntry();
    });
    return initial;
  }

  Future<void> refreshPermission() async {
    final hydrationRepo = ref.read(hydrationRepositoryProvider);
    final nutritionRepo = ref.read(nutritionRepositoryProvider);
    state = state.copyWith(
      isCheckingPermission: true,
      entryError: null,
      writeError: null,
    );
    try {
      final canWriteHydration =
          await hydrationRepo.hasHydrationWritePermission();
      final canWriteNutrition =
          await nutritionRepo.hasNutritionWritePermission();
      if (!ref.mounted) return;
      state = state.copyWith(
        isCheckingPermission: false,
        hydrationWritePermissions: hydrationRepo.hydrationWritePermissions,
        nutritionWritePermissions: nutritionRepo.nutritionWritePermissions,
        canWriteHydration: canWriteHydration,
        canWriteNutrition: canWriteNutrition,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isCheckingPermission: false,
        hydrationWritePermissions: hydrationRepo.hydrationWritePermissions,
        nutritionWritePermissions: nutritionRepo.nutritionWritePermissions,
        canWriteHydration: false,
        canWriteNutrition: false,
        entryError: HydrationEntryError.writeFailed,
        writeError: throwableToScreenError(error),
      );
    }
  }

  Future<void> refreshTodayHydration() async {
    final today = LocalDate.now();
    try {
      final entries = await ref
          .read(hydrationRepositoryProvider)
          .loadDailyHydration(today, today);
      final liters = entries.fold<double>(0.0, (sum, e) => sum + e.liters);
      if (!ref.mounted) return;
      state = state.copyWith(todayHydrationLiters: liters);
    } catch (_) {
      // Best-effort; ignore failures (matches Kotlin `runCatching { }`).
    }
  }

  void selectContainer(HydrationContainerOption container) {
    state = state.copyWith(
      selectedContainer: container,
      saveCompleted: false,
      entryNotice: null,
      entryError: null,
      writeError: null,
    );
  }

  void updateEntryTime(DateTime time) {
    final now = DateTime.now();
    state = state.copyWith(
      editTime: time.isAfter(now) ? now : time,
      saveCompleted: false,
      entryNotice: null,
      entryError: null,
      writeError: null,
    );
  }

  /// Saves the currently-selected container's volume.
  Future<void> addSelectedHydrationEntry() =>
      _saveHydrationEntry(rawLiters: state.selectedContainer.volumeLiters);

  /// Selects [container] and (outside edit mode) immediately logs it.
  Future<void> addContainerHydrationEntry(
    HydrationContainerOption container,
  ) async {
    if (state.isEditMode) {
      selectContainer(container);
      return;
    }
    state = state.copyWith(
      selectedContainer: container,
      saveCompleted: false,
      entryNotice: null,
      entryError: null,
      writeError: null,
    );
    await _saveHydrationEntry(rawLiters: container.volumeLiters);
  }

  /// Logs a free-form custom amount, remembering it as the last custom amount.
  Future<void> addCustomHydrationEntry(double milliliters) async {
    if (!isValidHydrationContainerMilliliters(milliliters)) {
      state = state.copyWith(
        entryError: HydrationEntryError.invalidAmount,
        entryNotice: null,
        writeError: null,
      );
      return;
    }
    state = state.copyWith(
      lastCustomAmountMilliliters: milliliters,
      entryNotice: null,
    );
    ref
        .read(hydrationRepositoryProvider)
        .setLastCustomHydrationAmountMilliliters(milliliters);
    await _saveHydrationEntry(rawLiters: milliliters / kMillilitersPerLiter);
  }

  /// Logs a saved custom drink (with its hydration multiplier + nutrients),
  /// scaling the nutrient values to [amountMilliliters]. Port of the Kotlin
  /// `addSavedCustomDrinkEntry` / `logCustomDrinkEntry`.
  Future<void> addSavedCustomDrinkEntry(
    CustomHydrationDrink drink, {
    double? amountMilliliters,
  }) async {
    final amount = amountMilliliters ?? drink.volumeMilliliters;
    if (!_isValidCustomHydrationDrink(drink)) {
      state = state.copyWith(
        entryError: HydrationEntryError.invalidCustomDrink,
        entryNotice: null,
        writeError: null,
      );
      return;
    }
    if (!isValidHydrationContainerMilliliters(amount)) {
      state = state.copyWith(
        entryError: HydrationEntryError.invalidAmount,
        entryNotice: null,
        writeError: null,
      );
      return;
    }
    final portionMultiplier = amount / drink.volumeMilliliters;
    final scaledNutrients = drink.nutrientValues
        .map((key, value) => MapEntry(key, value * portionMultiplier));
    state = state.copyWith(
      lastCustomAmountMilliliters: amount,
      entryNotice: null,
    );
    ref
        .read(hydrationRepositoryProvider)
        .setLastCustomHydrationAmountMilliliters(amount);
    await _saveHydrationEntry(
      rawLiters: amount / kMillilitersPerLiter,
      hydrationMultiplier: drink.hydrationMultiplier,
      drinkId: drink.id,
      nutritionName: drink.name,
      nutrientValues: scaledNutrients,
    );
  }

  void onSaveCompletedHandled() {
    state = state.copyWith(saveCompleted: false);
  }

  Future<void> _saveHydrationEntry({
    required double rawLiters,
    double hydrationMultiplier = 1.0,
    String? drinkId,
    String? nutritionName,
    Map<NutritionNutrient, double> nutrientValues =
        const <NutritionNutrient, double>{},
  }) async {
    final current = state;
    state = state.copyWith(
      isSavingEntry: true,
      saveCompleted: false,
      entryNotice: null,
      entryError: null,
      writeError: null,
    );
    try {
      final outcome = await _writeHydrationAndNutritionEntry(
        hydrationRepository: ref.read(hydrationRepositoryProvider),
        nutritionRepository: ref.read(nutritionRepositoryProvider),
        rawLiters: rawLiters,
        hydrationMultiplier: hydrationMultiplier,
        drinkId: drinkId,
        nutritionName: nutritionName,
        nutrientValues: nutrientValues,
        fallbackEntryTime: current.editTime,
        editRecordId: current.editRecordId,
        canWriteHydration: current.canWriteHydration,
        canWriteNutrition: current.canWriteNutrition,
      );
      if (!ref.mounted) return;
      if (outcome is _Invalid) {
        state = state.copyWith(
          isSavingEntry: false,
          entryError: outcome.error,
          entryNotice: null,
          writeError: null,
        );
        return;
      }
      final success = (outcome as _Success).value;
      state = state.copyWith(
        isSavingEntry: false,
        todayHydrationLiters:
            (current.isEditMode || !_isToday(success.entryTime))
                ? state.todayHydrationLiters
                : state.todayHydrationLiters + success.effectiveLiters,
        saveCompleted: true,
        entryNotice: success.notice,
        entryError: null,
        writeError: null,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isSavingEntry: false,
        entryError: HydrationEntryError.writeFailed,
        entryNotice: null,
        writeError: throwableToScreenError(error),
      );
    }
  }

  Future<void> _loadEditEntry() async {
    final recordId = editRecordId;
    if (recordId == null) return;
    try {
      final entry =
          await ref.read(hydrationRepositoryProvider).loadHydrationEntry(
                recordId,
              );
      if (!ref.mounted) return;
      if (entry == null || !entry.isOpenVitalsEntry) {
        state = state.copyWith(
          entryError: HydrationEntryError.writeFailed,
          writeError: const ScreenErrorMessage(
            'Only OpenVitals entries can be edited.',
          ),
        );
        return;
      }
      final existingOptions = state.containerOptions;
      final match = existingOptions.where(
        (o) => (o.volumeLiters - entry.liters).abs() < 0.0001,
      );
      final option = match.isNotEmpty
          ? match.first
          : HydrationContainerOption(
              id: 'current_entry',
              volumeMilliliters: entry.liters * kMillilitersPerLiter,
            );
      final options = <HydrationContainerOption>[
        option,
        ...existingOptions,
      ];
      final seen = <String>{};
      final deduped = <HydrationContainerOption>[];
      for (final o in options) {
        if (seen.add(o.id)) deduped.add(o);
      }
      final now = DateTime.now();
      state = state.copyWith(
        containerOptions: deduped,
        selectedContainer: option,
        editTime: entry.startTime.isAfter(now) ? now : entry.startTime,
        entryError: null,
        writeError: null,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = state.copyWith(
        entryError: HydrationEntryError.writeFailed,
        writeError: throwableToScreenError(error),
      );
    }
  }

  List<HydrationContainerOption> _containerOptions(HydrationRepository repo) {
    final overrides = repo.hydrationContainerVolumeMilliliters();
    return kDefaultHydrationContainers.map((option) {
      final override = overrides[option.id];
      if (override != null && isValidHydrationContainerMilliliters(override)) {
        return option.copyWith(volumeMilliliters: override);
      }
      return option;
    }).toList();
  }

  bool _isToday(DateTime time) {
    final today = LocalDate.now();
    final local = time.toLocal();
    return local.year == today.year &&
        local.month == today.month &&
        local.day == today.day;
  }
}

/// Successful hydration/nutrition write result (Kotlin `HydrationDrinkLogSuccess`).
class _Success {
  const _Success(this.value);
  final _HydrationLogSuccess value;
}

class _Invalid {
  const _Invalid(this.error);
  final HydrationEntryError error;
}

class _HydrationLogSuccess {
  const _HydrationLogSuccess({
    required this.effectiveLiters,
    required this.entryTime,
    required this.notice,
  });

  final double effectiveLiters;
  final DateTime entryTime;
  final HydrationEntryNotice? notice;
}

/// Port of the Kotlin `writeHydrationAndNutritionEntry` (HydrationDrinkLogger):
/// writes (or updates) the hydration record and, when nutrient values are
/// present, the associated nutrition record — validating permissions + volume.
Future<Object> _writeHydrationAndNutritionEntry({
  required HydrationRepository hydrationRepository,
  required NutritionRepository nutritionRepository,
  required double rawLiters,
  required double hydrationMultiplier,
  String? drinkId,
  String? nutritionName,
  required Map<NutritionNutrient, double> nutrientValues,
  DateTime? requestedEntryTime,
  DateTime? fallbackEntryTime,
  String? editRecordId,
  required bool canWriteHydration,
  required bool canWriteNutrition,
}) async {
  if (!_isValidCustomDrinkHydrationMultiplier(hydrationMultiplier)) {
    return const _Invalid(HydrationEntryError.invalidCustomDrink);
  }

  final effectiveLiters = rawLiters * hydrationMultiplier;
  final writesHydration = effectiveLiters > 0.0;
  final writesNutrition = nutrientValues.isNotEmpty;

  if (editRecordId != null && !writesHydration) {
    return const _Invalid(HydrationEntryError.invalidAmount);
  }
  if (writesHydration && !canWriteHydration) {
    return const _Invalid(HydrationEntryError.missingWritePermission);
  }
  if (writesNutrition && !canWriteNutrition) {
    return const _Invalid(HydrationEntryError.missingNutritionWritePermission);
  }
  if (writesHydration &&
      effectiveLiters >
          kMaxHydrationContainerMilliliters / kMillilitersPerLiter) {
    return const _Invalid(HydrationEntryError.invalidAmount);
  }
  if (!writesHydration && !writesNutrition) {
    return const _Invalid(HydrationEntryError.invalidCustomDrink);
  }

  final now = DateTime.now();
  DateTime coerce(DateTime t) => t.isAfter(now) ? now : t;
  final entryTime = requestedEntryTime != null
      ? coerce(requestedEntryTime)
      : (fallbackEntryTime != null ? coerce(fallbackEntryTime) : now);

  if (editRecordId == null) {
    String? hydrationClientRecordId;
    if (writesHydration) {
      hydrationClientRecordId = await hydrationRepository.writeHydrationEntry(
        HydrationWriteRequest(
          time: entryTime,
          volumeLiters: effectiveLiters,
          drinkId: drinkId,
        ),
      );
    }
    if (writesNutrition) {
      await nutritionRepository.writeNutritionEntry(
        NutritionWriteRequest(
          time: entryTime,
          nutrientValues: nutrientValues,
          name: nutritionName,
          associatedHydrationClientRecordId: hydrationClientRecordId,
        ),
      );
    }
  } else {
    await hydrationRepository.updateHydrationEntry(
      editRecordId,
      HydrationWriteRequest(time: entryTime, volumeLiters: effectiveLiters),
    );
  }

  return _Success(
    _HydrationLogSuccess(
      effectiveLiters: effectiveLiters,
      entryTime: entryTime,
      notice: (!writesHydration && writesNutrition)
          ? HydrationEntryNotice.nonHydratingDrinkSaved
          : null,
    ),
  );
}
