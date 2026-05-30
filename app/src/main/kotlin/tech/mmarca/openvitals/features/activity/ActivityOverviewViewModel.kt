package tech.mmarca.openvitals.features.activity

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dagger.hilt.android.lifecycle.HiltViewModel
import tech.mmarca.openvitals.core.performance.LoadCoordinator
import tech.mmarca.openvitals.data.model.DailyHrv
import tech.mmarca.openvitals.data.model.DailyNutrition
import tech.mmarca.openvitals.data.model.DailyRestingHR
import tech.mmarca.openvitals.data.model.DailySteps
import tech.mmarca.openvitals.data.model.ExerciseData
import tech.mmarca.openvitals.data.model.HeartRateSample
import tech.mmarca.openvitals.data.repository.ActivityRepository
import tech.mmarca.openvitals.data.repository.HeartRepository
import java.time.Duration
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import javax.inject.Inject
import kotlin.math.exp
import kotlin.math.roundToInt
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

private const val ActivityOverviewLookbackDays = 30L
private const val RecentActivityInitialCount = 3
private const val RecentActivityPageSize = 5
private const val MinimumTrimpMinutes = 5.0
private const val GoodHeartRateCoverageMinutes = 10.0
private const val GoodHeartRateCoverageRatio = 0.6
private const val MaxHeartRateSampleGapMinutes = 5.0
private const val ActiveHeartRateReserveThreshold = 0.3
private const val ObservedMaxHeartRateMinimumBpm = 150L
private const val ObservedMaxHeartRateRestingDeltaBpm = 60L

enum class CardioLoadConfidence {
    HIGH,
    MEDIUM,
    LOW,
    NO_DATA,
}

enum class CardioLoadMethod {
    TRIMP_ACTIVITY_WINDOWS,
    TRIMP_ELEVATED_HEART_RATE,
    MOVEMENT_FALLBACK,
    NO_DATA,
}

data class CardioLoadEstimate(
    val score: Int = 0,
    val confidence: CardioLoadConfidence = CardioLoadConfidence.NO_DATA,
    val method: CardioLoadMethod = CardioLoadMethod.NO_DATA,
    val trimpScore: Double? = null,
    val coveredMinutes: Double = 0.0,
    val expectedMinutes: Double = 0.0,
    val restingHeartRateBpm: Long? = null,
    val restingHeartRateObserved: Boolean = false,
    val maxHeartRateBpm: Long? = null,
    val maxHeartRateObserved: Boolean = false,
    val heartRateSampleCount: Int = 0,
    val activityWindowCount: Int = 0,
    val activityWindowMinutes: Double = 0.0,
    val movementFallbackScore: Int = 0,
) {
    companion object {
        val NoData = CardioLoadEstimate()
    }
}

data class ActivityOverviewDay(
    val date: LocalDate,
    val steps: Long = 0L,
    val distanceMeters: Double = 0.0,
    val activeCaloriesKcal: Double? = null,
    val energyBurnedKcal: Double = 0.0,
    val hrvRmssdMs: Double? = null,
    val cardioLoadScore: CardioLoadEstimate = CardioLoadEstimate.NoData,
) {
    val hasActivity: Boolean
        get() = steps > 0L ||
            distanceMeters > 0.0 ||
            activeCaloriesKcal.orZero() > 0.0 ||
            energyBurnedKcal > 0.0 ||
            cardioLoadConfidence != CardioLoadConfidence.NO_DATA

    val cardioLoad: Int
        get() = cardioLoadScore.score

    val cardioLoadConfidence: CardioLoadConfidence
        get() = cardioLoadScore.confidence
}

data class ActivityOverviewUiState(
    val isLoading: Boolean = true,
    val selectedDate: LocalDate = LocalDate.now(),
    val days: List<ActivityOverviewDay> = emptyList(),
    val recentVisibleCount: Int = RecentActivityInitialCount,
    val error: String? = null,
) {
    val today: ActivityOverviewDay
        get() = days.firstOrNull { it.date == selectedDate } ?: ActivityOverviewDay(selectedDate)

    val recentActivities: List<ActivityOverviewDay>
        get() = days.asReversed().filter { it.hasActivity }

    val visibleRecentActivities: List<ActivityOverviewDay>
        get() = recentActivities.take(recentVisibleCount)

    val canLoadMoreRecentActivities: Boolean
        get() = visibleRecentActivities.size < recentActivities.size

    val metricDays: List<ActivityOverviewDay>
        get() = days.takeLast(7)
}

@HiltViewModel
class ActivityOverviewViewModel @Inject constructor(
    private val activityRepository: ActivityRepository,
    private val heartRepository: HeartRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(ActivityOverviewUiState())
    val uiState: StateFlow<ActivityOverviewUiState> = _uiState.asStateFlow()
    private val loadCoordinator = LoadCoordinator()

    init {
        load()
    }

    fun load(today: LocalDate = LocalDate.now()) {
        loadCoordinator.launch(viewModelScope) load@{
            val end = today
            val start = end.minusDays(ActivityOverviewLookbackDays - 1)
            _uiState.value = _uiState.value.copy(
                isLoading = true,
                selectedDate = today,
                error = null,
            )
            runCatching {
                ActivityOverviewLoadResult(
                    steps = activityRepository.loadDailySteps(start, end),
                    nutrition = activityRepository.loadDailyNutrition(start, end),
                    workouts = activityRepository.loadWorkouts(start, end),
                    heartRateSamples = heartRepository.loadHeartRateSamples(start, end),
                    restingHeartRate = heartRepository.loadDailyRestingHR(start, end),
                    hrv = heartRepository.loadDailyHRV(start, end),
                )
            }.onSuccess { result ->
                if (!isCurrent) return@load
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    selectedDate = today,
                    days = result.toDays(start, end),
                    recentVisibleCount = RecentActivityInitialCount,
                )
            }.onFailure { error ->
                if (!isCurrent) return@load
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    selectedDate = today,
                    error = error.message,
                )
            }
        }
    }

    fun loadMoreRecentActivities() {
        val current = _uiState.value
        _uiState.value = current.copy(
            recentVisibleCount = (current.recentVisibleCount + RecentActivityPageSize)
                .coerceAtMost(current.recentActivities.size),
        )
    }

    private data class ActivityOverviewLoadResult(
        val steps: List<DailySteps>,
        val nutrition: List<DailyNutrition>,
        val workouts: List<ExerciseData>,
        val heartRateSamples: List<HeartRateSample>,
        val restingHeartRate: List<DailyRestingHR>,
        val hrv: List<DailyHrv>,
    )

    private fun ActivityOverviewLoadResult.toDays(
        start: LocalDate,
        end: LocalDate,
    ): List<ActivityOverviewDay> {
        val stepsByDate = steps.associateBy { it.date }
        val nutritionByDate = nutrition.associateBy { it.date }
        val hrvByDate = hrv.associateBy { it.date }
        val zone = ZoneId.systemDefault()
        val heartRateSamplesByDate = heartRateSamples
            .sortedBy { it.time }
            .groupBy { it.time.atZone(zone).toLocalDate() }
        val restingHeartRateByDate = restingHeartRate.associateBy { it.date }
        val baselineRestingHeartRate = restingHeartRate
            .map { it.bpm }
            .medianOrNull()
        val observedMaxHeartRate = heartRateSamples.maxOfOrNull { it.beatsPerMinute }
        return generateSequence(start) { date ->
            date.plusDays(1).takeUnless { it.isAfter(end) }
        }.map { date ->
            val daySteps = stepsByDate[date]
            val dayNutrition = nutritionByDate[date]
            val dayHrv = hrvByDate[date]
            val dayWorkouts = workouts.overlapping(date, zone)
            val daySamples = heartRateSamplesByDate[date].orEmpty()
            ActivityOverviewDay(
                date = date,
                steps = daySteps?.steps ?: 0L,
                distanceMeters = daySteps?.distanceMeters ?: 0.0,
                activeCaloriesKcal = daySteps?.activeCaloriesKcal,
                energyBurnedKcal = dayNutrition?.caloriesBurnedKcal ?: 0.0,
                hrvRmssdMs = dayHrv?.rmssdMs,
                cardioLoadScore = calculateCardioLoad(
                    steps = daySteps,
                    samples = daySamples,
                    restingHeartRate = restingHeartRateByDate[date]?.bpm,
                    baselineRestingHeartRate = baselineRestingHeartRate,
                    observedMaxHeartRate = observedMaxHeartRate,
                    activityWindows = dayWorkouts,
                ),
            )
        }.toList()
    }
}

private data class TimeWindow(
    val start: Instant,
    val end: Instant,
) {
    val durationMinutes: Double
        get() = Duration.between(start, end).seconds.coerceAtLeast(0L).toDouble() / 60.0
}

private data class MaxHeartRateContext(
    val bpm: Long,
    val isObservedAvailable: Boolean,
)

private data class TrimpResult(
    val score: Double,
    val coveredMinutes: Double,
    val expectedMinutes: Double,
) {
    val hasGoodCoverage: Boolean
        get() = coveredMinutes >= GoodHeartRateCoverageMinutes &&
            (expectedMinutes <= 0.0 || coveredMinutes / expectedMinutes >= GoodHeartRateCoverageRatio)
}

private fun calculateCardioLoad(
    steps: DailySteps?,
    samples: List<HeartRateSample>,
    restingHeartRate: Long?,
    baselineRestingHeartRate: Long?,
    observedMaxHeartRate: Long?,
    activityWindows: List<TimeWindow>,
): CardioLoadEstimate {
    val fallback = movementFallbackCardioLoad(steps)
    val resting = restingHeartRate ?: baselineRestingHeartRate ?: samples.estimatedRestingHeartRate()
    val maxHeartRate = resting?.let { maxHeartRateContext(observedMaxHeartRate, samples, it) }
    val trimp = if (resting != null && maxHeartRate != null) {
        calculateTrimp(
            samples = samples,
            restingHeartRate = resting,
            maxHeartRate = maxHeartRate.bpm,
            activityWindows = activityWindows,
        )
    } else {
        null
    }

    val activityWindowMinutes = activityWindows.sumOf { it.durationMinutes }
    if (trimp != null && trimp.coveredMinutes >= MinimumTrimpMinutes && trimp.score > 0.0) {
        val confidence = when {
            trimp.hasGoodCoverage && restingHeartRate != null && maxHeartRate?.isObservedAvailable == true ->
                CardioLoadConfidence.HIGH
            trimp.hasGoodCoverage -> CardioLoadConfidence.MEDIUM
            else -> CardioLoadConfidence.LOW
        }
        return CardioLoadEstimate(
            score = trimp.score.roundToInt().coerceAtLeast(1),
            confidence = confidence,
            method = if (activityWindows.isNotEmpty()) {
                CardioLoadMethod.TRIMP_ACTIVITY_WINDOWS
            } else {
                CardioLoadMethod.TRIMP_ELEVATED_HEART_RATE
            },
            trimpScore = trimp.score,
            coveredMinutes = trimp.coveredMinutes,
            expectedMinutes = trimp.expectedMinutes,
            restingHeartRateBpm = resting,
            restingHeartRateObserved = restingHeartRate != null,
            maxHeartRateBpm = maxHeartRate?.bpm,
            maxHeartRateObserved = maxHeartRate?.isObservedAvailable == true,
            heartRateSampleCount = samples.size,
            activityWindowCount = activityWindows.size,
            activityWindowMinutes = activityWindowMinutes,
            movementFallbackScore = fallback,
        )
    }

    return when {
        fallback > 0 -> CardioLoadEstimate(
            score = fallback,
            confidence = CardioLoadConfidence.LOW,
            method = CardioLoadMethod.MOVEMENT_FALLBACK,
            restingHeartRateBpm = resting,
            restingHeartRateObserved = restingHeartRate != null,
            maxHeartRateBpm = maxHeartRate?.bpm,
            maxHeartRateObserved = maxHeartRate?.isObservedAvailable == true,
            heartRateSampleCount = samples.size,
            activityWindowCount = activityWindows.size,
            activityWindowMinutes = activityWindowMinutes,
            movementFallbackScore = fallback,
        )
        else -> CardioLoadEstimate.NoData
    }
}

private fun calculateTrimp(
    samples: List<HeartRateSample>,
    restingHeartRate: Long,
    maxHeartRate: Long,
    activityWindows: List<TimeWindow>,
): TrimpResult? {
    val sortedSamples = samples
        .sortedBy { it.time }
        .distinctBy { it.time }
    if (sortedSamples.size < 2 || maxHeartRate <= restingHeartRate) return null

    var score = 0.0
    var coveredMinutes = 0.0
    val expectedMinutes = activityWindows
        .sumOf { it.durationMinutes }
        .takeIf { activityWindows.isNotEmpty() }

    sortedSamples.zipWithNext().forEach { (start, end) ->
        val interval = TimeWindow(start.time, end.time)
        val rawMinutes = interval.durationMinutes
        if (rawMinutes <= 0.0 || rawMinutes > MaxHeartRateSampleGapMinutes) return@forEach

        val intervalMinutes = if (activityWindows.isNotEmpty()) {
            activityWindows.sumOf { interval.overlapMinutes(it) }
        } else {
            rawMinutes
        }
        if (intervalMinutes <= 0.0) return@forEach

        val averageBpm = (start.beatsPerMinute + end.beatsPerMinute) / 2.0
        val heartRateReserve = ((averageBpm - restingHeartRate) / (maxHeartRate - restingHeartRate).toDouble())
            .coerceIn(0.0, 1.0)
        if (activityWindows.isEmpty() && heartRateReserve < ActiveHeartRateReserveThreshold) {
            return@forEach
        }

        coveredMinutes += intervalMinutes
        score += intervalMinutes * heartRateReserve * 0.64 * exp(1.92 * heartRateReserve)
    }

    if (coveredMinutes <= 0.0) return null
    return TrimpResult(
        score = score,
        coveredMinutes = coveredMinutes,
        expectedMinutes = expectedMinutes ?: coveredMinutes,
    )
}

private fun movementFallbackCardioLoad(steps: DailySteps?): Int {
    steps ?: return 0
    return maxOf(
        steps.steps.toDouble() / 3_000.0,
        steps.distanceMeters / 1_500.0,
        steps.activeCaloriesKcal.orZero() / 75.0,
    ).roundToInt().coerceAtLeast(0)
}

private fun maxHeartRateContext(
    observedMaxHeartRate: Long?,
    samples: List<HeartRateSample>,
    restingHeartRate: Long,
): MaxHeartRateContext? {
    val sampleMax = samples.maxOfOrNull { it.beatsPerMinute }
    val observedMax = listOfNotNull(observedMaxHeartRate, sampleMax).maxOrNull() ?: return null
    val observedAvailable = observedMax >= maxOf(
        ObservedMaxHeartRateMinimumBpm,
        restingHeartRate + ObservedMaxHeartRateRestingDeltaBpm,
    )
    val estimatedMax = maxOf(
        observedMax + 10L,
        restingHeartRate + 70L,
    )
    return MaxHeartRateContext(
        bpm = if (observedAvailable) observedMax else estimatedMax,
        isObservedAvailable = observedAvailable,
    )
}

private fun List<HeartRateSample>.estimatedRestingHeartRate(): Long? {
    if (isEmpty()) return null
    val sorted = map { it.beatsPerMinute }.sorted()
    val index = (sorted.lastIndex * 0.1).roundToInt().coerceIn(sorted.indices)
    return sorted[index].coerceIn(40L, 100L)
}

private fun List<Long>.medianOrNull(): Long? {
    if (isEmpty()) return null
    val sorted = sorted()
    return sorted[sorted.lastIndex / 2]
}

private fun List<ExerciseData>.overlapping(date: LocalDate, zone: ZoneId): List<TimeWindow> {
    val dayStart = date.atStartOfDay(zone).toInstant()
    val dayEnd = date.plusDays(1).atStartOfDay(zone).toInstant()
    return mapNotNull { workout ->
        if (!workout.endTime.isAfter(dayStart) || !workout.startTime.isBefore(dayEnd)) return@mapNotNull null
        TimeWindow(
            start = maxOf(workout.startTime, dayStart),
            end = minOf(workout.endTime, dayEnd),
        ).takeIf { it.durationMinutes > 0.0 }
    }
}

private fun TimeWindow.overlapMinutes(other: TimeWindow): Double {
    val overlapStart = maxOf(start, other.start)
    val overlapEnd = minOf(end, other.end)
    if (!overlapEnd.isAfter(overlapStart)) return 0.0
    return Duration.between(overlapStart, overlapEnd).seconds.toDouble() / 60.0
}

private fun Double?.orZero(): Double = this ?: 0.0
