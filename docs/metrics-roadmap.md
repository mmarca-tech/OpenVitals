# Metrics Roadmap

Gap analysis between what the app currently shows and all Health Connect record types that can meaningfully be surfaced to the user, plus a phased implementation plan.

---

## Current coverage

| Category | Metric | HC Record type | Feature screen |
|---|---|---|---|
| Activity | Steps | `StepsRecord` | Steps |
| Activity | Distance | `DistanceRecord` | Steps |
| Activity | Total calories burned | `TotalCaloriesBurnedRecord` | Steps |
| Activity | Hydration | `HydrationRecord` | Steps |
| Exercise | Workout sessions | `ExerciseSessionRecord` | Activities |
| Sleep | Duration + stages | `SleepSessionRecord` | Sleep |
| Heart | Avg heart rate | `HeartRateRecord` | Heart |
| Body | Weight | `WeightRecord` | Body |

---

## Missing data points

### Vitals — widely available from wearables

| HC Record type | Metric | Source examples |
|---|---|---|
| `RestingHeartRateRecord` | Resting HR bpm | Garmin, Polar, Samsung, Fitbit |
| `HeartRateVariabilityRmssdRecord` | HRV RMSSD ms | Garmin, Polar, Whoop |
| `Vo2MaxRecord` | VO2 max mL/kg/min | Garmin, Polar |
| `BloodPressureRecord` | Systolic / diastolic mmHg | Smart BP cuffs, some wearables |
| `OxygenSaturationRecord` | SpO2 % | Most modern wearables |
| `RespiratoryRateRecord` | Breaths per minute | Garmin, Polar |
| `BodyTemperatureRecord` | Body temp °C | Some wearables, manual entry |

### Body composition — mostly smart scales

| HC Record type | Metric |
|---|---|
| `HeightRecord` | Height cm (needed for BMI computation) |
| `BodyFatRecord` | Body fat % |
| `LeanBodyMassRecord` | Lean mass kg |
| `BoneMassRecord` | Bone mass kg |
| `BasalMetabolicRateRecord` | BMR kcal/day |

### Activity extras — wearables and fitness apps

| HC Record type | Metric |
|---|---|
| `FloorsClimbedRecord` | Floors climbed |
| `ActiveCaloriesBurnedRecord` | Active calories (distinct from total) |
| `ElevationGainedRecord` | Elevation gain m |

### Nutrition — food diary apps

| HC Record type | Metric |
|---|---|
| `NutritionRecord` | Calories IN, protein, carbs, fat, fiber, sugar per meal |

### Mindfulness

| HC Record type | Metric |
|---|---|
| `MindfulnessSessionRecord` | Session title + duration |

### Women's health (opt-in)

| HC Record type | Metric |
|---|---|
| `MenstruationFlowRecord` | Flow level per day |
| `MenstruationPeriodRecord` | Cycle period dates |
| `OvulationTestRecord` | LH / ovulation test result |
| `CervicalMucusRecord` | Mucus observation |
| `BasalBodyTemperatureRecord` | BBT for cycle tracking |

---

## Implementation plan

### Phase A — Expand existing screens

Low risk. No new nav destinations. Permissions added to `phase2Permissions`.

#### A1. Heart screen: Resting HR + HRV

**New permissions:** `RestingHeartRateRecord`, `HeartRateVariabilityRmssdRecord`

`HealthConnectManager`:
- `readRestingHeartRate(date: LocalDate): Long?`
- `readDailyRestingHR(start: LocalDate, end: LocalDate): List<DailyRestingHR>`
- `readDailyHRV(start: LocalDate, end: LocalDate): List<DailyHrv>`

New models in `HealthData.kt`:
```kotlin
data class DailyRestingHR(val date: LocalDate, val bpm: Long)
data class DailyHrv(val date: LocalDate, val rmssdMs: Double)
```

`HeartRateSummary` extended: add `restingBpm: Long?` and `hrvRmssdMs: Double?`

`HeartScreen`: add summary tiles and trend charts for Resting HR and HRV below the existing heart rate chart.

`DashboardData`: add `restingHeartRateBpm: Long?`; show in the Heart dashboard card subtitle.

---

#### A2. Body screen: Height + BMI + body composition

**New permissions:** `HeightRecord`, `BodyFatRecord`, `LeanBodyMassRecord`, `BasalMetabolicRateRecord`

`HealthConnectManager`:
- `readLatestHeight(): Double?` — cm
- `readLatestBodyFat(date: LocalDate): Double?` — percent
- `readBodyFatEntries(start: LocalDate, end: LocalDate): List<BodyFatEntry>`
- `readLatestLeanBodyMass(): Double?` — kg
- `readLatestBMR(): Double?` — kcal/day

New models:
```kotlin
data class BodyFatEntry(val time: Instant, val percent: Double, val source: String)
```

BMI computed in the ViewModel when both `heightCm` and `weightKg` are present: `weightKg / (heightCm/100)^2`.

`BodyUiState` extended: `heightCm`, `bodyFatPercent`, `leanMassKg`, `bmrKcal`, `bmi` (derived).

`BodyScreen`: add composition tiles (BMI, body fat %, lean mass, BMR) below the weight chart. Body fat % gets its own mini trend chart if entries exist over the period.

`DashboardData`: add `bodyFatPercent: Double?` for the Body dashboard card subtitle.

---

#### A3. Activity screen: Floors + Active calories + Elevation

**New permissions:** `FloorsClimbedRecord`, `ActiveCaloriesBurnedRecord`, `ElevationGainedRecord`

Rename `DailySteps` → `DailyActivity` and extend:
```kotlin
data class DailyActivity(
    val date: LocalDate,
    val steps: Long,
    val distanceMeters: Double,
    val floorsClimbed: Int?,
    val activeCaloriesKcal: Double?,
    val elevationGainedMeters: Double?,
)
```

`readDailySteps` → `readDailyActivity` — aggregate all five metrics together in a single `aggregateGroupByDuration` call.

`ActivityScreen`: add Floors, Active Calories, and Elevation tiles in the daily summary row alongside Steps and Distance.

`DashboardData`: add `floorsClimbed: Int?`; show in the Daily summary section.

---

### Phase B — New feature screens

Each follows the established feature pattern: `ViewModel` + `Screen` in `features/<name>/`, period navigator, pull-to-refresh, `PeriodNavigator` from `ui.components`.

#### B1. Vitals screen (`features/vitals/`)

**New permissions (phase 3 — shown after first use):**
`BloodPressureRecord`, `OxygenSaturationRecord`, `RespiratoryRateRecord`, `BodyTemperatureRecord`

New models:
```kotlin
data class BloodPressureEntry(val time: Instant, val systolicMmHg: Int, val diastolicMmHg: Int, val source: String)
data class SpO2Entry(val time: Instant, val percent: Double, val source: String)
data class RespiratoryRateEntry(val time: Instant, val breathsPerMinute: Double, val source: String)
data class BodyTempEntry(val time: Instant, val temperatureCelsius: Double, val source: String)
```

`VitalsUiState`: holds lists of each type for the selected period.

`VitalsScreen`: two sections — Cardiovascular (BP chart with systolic/diastolic bands, SpO2 line) and Respiratory (respiratory rate, body temperature).

`DashboardData`: add `latestSystolicMmHg: Int?`, `latestDiastolicMmHg: Int?`, `latestSpO2Percent: Double?`.

Dashboard: new "Vitals" section with a `MetricCard` for BP and SpO2 (placeholder if no data).

Navigation: add `Screen.Vitals` route; wire `onOpenVitals` callback from Dashboard.

---

#### B2. Nutrition screen (`features/nutrition/`)

**New permissions (phase 2):** `NutritionRecord`

Note: `NutritionRecord` covers calories IN (food), distinct from `TotalCaloriesBurnedRecord` (calories OUT). This enables a calories in/out view.

New models:
```kotlin
data class NutritionEntry(
    val time: Instant,
    val mealType: Int,          // MealType constants from HC
    val name: String?,
    val energyKcal: Double?,
    val proteinGrams: Double?,
    val carbsGrams: Double?,
    val fatGrams: Double?,
    val fiberGrams: Double?,
    val sugarGrams: Double?,
    val source: String,
)

data class DailyMacros(
    val date: LocalDate,
    val energyKcal: Double,
    val proteinGrams: Double,
    val carbsGrams: Double,
    val fatGrams: Double,
)
```

`NutritionScreen`: macro summary bar (protein/carbs/fat proportion), daily energy chart, meal entry list.

`DashboardData`: add `caloriesInKcal: Double?`; show alongside `caloriesKcal` (burned) as a calories in/out pair in the Daily summary section.

Navigation: add `Screen.Nutrition` route.

---

#### B3. Mindfulness screen (`features/mindfulness/`)

**New permissions (phase 2):** `MindfulnessSessionRecord`

New model:
```kotlin
data class MindfulnessSession(
    val id: String,
    val title: String?,
    val startTime: Instant,
    val endTime: Instant,
    val durationMs: Long,
    val source: String,
) {
    val durationMinutes: Long get() = durationMs / 60_000
}
```

`MindfulnessScreen`: total minutes per period, session list (mirrors Activities screen structure).

`DashboardData`: add `mindfulnessMinutes: Int?`; show as a small tile in a new "Mind" section.

Navigation: add `Screen.Mindfulness` route.

---

### Phase C — Women's health (opt-in)

Gated behind `Settings` → "Track menstrual cycle" boolean pref. Off by default.

**New permissions (phase 4, only requested when opted in):**
`MenstruationFlowRecord`, `MenstruationPeriodRecord`, `OvulationTestRecord`, `CervicalMucusRecord`, `BasalBodyTemperatureRecord`

`CycleScreen` (`features/cycle/`): monthly calendar view marking period days, flow levels, ovulation markers, and BBT trend.

No dashboard card unless opt-in is enabled (avoids surfacing sensitive data unexpectedly).

---

## Priority order

| Priority | Phase | Effort | Rationale |
|---|---|---|---|
| 1 | A1 — Resting HR + HRV | Low | Very common from Garmin/Polar/Samsung; natural extension of existing Heart screen |
| 2 | A3 — Floors + active calories | Low | Present on virtually all wearables; expands existing Activity screen |
| 3 | A2 — Body composition | Medium | Smart scales; extends existing Body screen |
| 4 | B2 — Nutrition | Medium | High user value; enables calories in/out view |
| 5 | B1 — Vitals | Medium | Requires new screen + phase 3 permissions flow |
| 6 | B3 — Mindfulness | Low | Small scope; mirrors Activities pattern exactly |
| 7 | C — Women's health | High | Niche but important; requires settings gate + dedicated permissions |

---

## Permission phases (updated)

| Phase | Permissions | When requested |
|---|---|---|
| Phase 1 | Steps, Distance, Exercise, Sleep | First launch / onboarding |
| Phase 2 | Heart rate, Weight, Calories, Hydration, Resting HR, HRV, Floors, Active calories, Elevation, Height, Body fat, Lean mass, BMR, Nutrition, Mindfulness | After onboarding |
| Phase 3 | Blood pressure, SpO2, Respiratory rate, Body temperature | On first open of Vitals screen |
| Phase 4 | Menstruation, Ovulation, Cervical mucus, BBT | On opt-in in Settings |
