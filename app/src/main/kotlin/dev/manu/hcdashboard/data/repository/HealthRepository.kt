package dev.manu.hcdashboard.data.repository

import android.util.Log
import dev.manu.hcdashboard.data.model.ActivityProgressPoint
import dev.manu.hcdashboard.data.model.DailyHrv
import dev.manu.hcdashboard.data.model.DailyNutrition
import dev.manu.hcdashboard.data.model.DailyRestingHR
import dev.manu.hcdashboard.data.model.DailySteps
import dev.manu.hcdashboard.data.model.DashboardData
import dev.manu.hcdashboard.data.model.ExerciseData
import dev.manu.hcdashboard.data.model.HealthConnectAvailability
import dev.manu.hcdashboard.data.model.HeartRateSample
import dev.manu.hcdashboard.data.model.HeartRateSummary
import dev.manu.hcdashboard.data.model.SleepData
import dev.manu.hcdashboard.data.model.StepProgressPoint
import dev.manu.hcdashboard.data.model.TimeRange
import dev.manu.hcdashboard.data.model.WeightEntry
import dev.manu.hcdashboard.healthconnect.HealthConnectManager
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.DistanceRecord
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.HydrationRecord
import androidx.health.connect.client.records.RestingHeartRateRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.records.TotalCaloriesBurnedRecord
import androidx.health.connect.client.records.WeightRecord
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * Repository layer sitting between ViewModels and [HealthConnectManager].
 *
 * Responsible for:
 * - Composing multi-record reads into domain objects
 * - Providing time-range helpers
 * - (Future) returning cached summaries from Room on fast startup
 */
class HealthRepository(private val hc: HealthConnectManager) {
    companion object {
        private const val TAG = "HealthRepository"
    }

    private val readStepsPermission = HealthPermission.getReadPermission(StepsRecord::class)
    private val readDistancePermission = HealthPermission.getReadPermission(DistanceRecord::class)
    private val readExercisePermission = HealthPermission.getReadPermission(ExerciseSessionRecord::class)
    private val readSleepPermission = HealthPermission.getReadPermission(SleepSessionRecord::class)
    private val readHeartRatePermission = HealthPermission.getReadPermission(HeartRateRecord::class)
    private val readRestingHRPermission = HealthPermission.getReadPermission(RestingHeartRateRecord::class)
    private val readHrvPermission = HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class)
    private val readWeightPermission = HealthPermission.getReadPermission(WeightRecord::class)
    private val readCaloriesPermission =
        HealthPermission.getReadPermission(TotalCaloriesBurnedRecord::class)
    private val readHydrationPermission = HealthPermission.getReadPermission(HydrationRecord::class)

    // ─── Availability + permissions ───────────────────────────────────────────

    fun availability(): HealthConnectAvailability = hc.availability()

    fun permissionContract() = hc.permissionContract()

    val phase1Permissions get() = hc.phase1Permissions
    val phase2Permissions get() = hc.phase2Permissions
    val allPermissions get() = hc.allPermissions

    suspend fun grantedPermissions(): Set<String> = hc.grantedPermissions()

    suspend fun missingPhase1(): Set<String> {
        val granted = hc.grantedPermissions()
        return hc.phase1Permissions.filterNot { it in granted }.toSet()
    }

    private suspend fun grantedPermissionsIfAvailable(): Set<String> =
        if (hc.availability() == HealthConnectAvailability.AVAILABLE) {
            hc.grantedPermissions().also { granted ->
                Log.d(TAG, "grantedPermissionsIfAvailable count=${granted.size} granted=${granted.sorted()}")
            }
        } else {
            Log.w(TAG, "Health Connect unavailable, returning empty granted permissions")
            emptySet()
        }

    // ─── Dashboard ────────────────────────────────────────────────────────────

    /**
     * Fetches only the lightweight data needed for the home dashboard.
     * Heavy history reads (charts, session lists) are done per-feature screen.
     */
    suspend fun loadDashboard(date: LocalDate = LocalDate.now()): DashboardData = coroutineScope {
        val granted = grantedPermissionsIfAvailable()
        Log.d(TAG, "loadDashboard date=$date granted=${granted.sorted()}")

        val steps = if (readStepsPermission in granted) {
            async { hc.readSteps(date) }
        } else null
        val distance = if (readDistancePermission in granted) {
            async { hc.readDistanceMeters(date) }
        } else null
        val workout = if (readExercisePermission in granted) {
            async { hc.readLatestWorkout(date) }
        } else null
        val sleep = if (readSleepPermission in granted) {
            async { hc.readSleepSession(date) }
        } else null
        val calories = if (readCaloriesPermission in granted) {
            async { hc.readCaloriesKcal(date) }
        } else null
        val hydration = if (readHydrationPermission in granted) {
            async { hc.readHydrationLiters(date) }
        } else null
        val weight = if (readWeightPermission in granted) {
            async { hc.readLatestWeight(date) }
        } else null
        val heartRate = if (readHeartRatePermission in granted) {
            async { hc.readAvgHeartRate(date) }
        } else null
        val restingHR = if (readRestingHRPermission in granted) {
            async { hc.readRestingHeartRate(date) }
        } else null

        val missingPerms = hc.phase1Permissions.filterNot { it in granted }.toSet()

        DashboardData(
            date = date,
            steps = steps?.await() ?: 0L,
            distanceMeters = distance?.await() ?: 0.0,
            caloriesKcal = calories?.await(),
            hydrationLiters = hydration?.await(),
            workout = workout?.await(),
            sleep = sleep?.await(),
            weightKg = weight?.await()?.weightKg,
            avgHeartRateBpm = heartRate?.await(),
            restingHeartRateBpm = restingHR?.await(),
            missingPermissions = missingPerms,
        )
    }

    // ─── Activity ─────────────────────────────────────────────────────────────

    suspend fun loadDailySteps(range: TimeRange): List<DailySteps> {
        val granted = grantedPermissionsIfAvailable()
        if (readStepsPermission !in granted || readDistancePermission !in granted) {
            Log.w(TAG, "Skipping loadDailySteps range=$range missing=${listOf(readStepsPermission, readDistancePermission).filterNot { it in granted }}")
            return emptyList()
        }
        val end = LocalDate.now()
        val start = end.minusDays(range.days.toLong() - 1)
        return hc.readDailySteps(start, end)
    }

    suspend fun loadDailySteps(start: LocalDate, end: LocalDate): List<DailySteps> {
        val granted = grantedPermissionsIfAvailable()
        if (readStepsPermission !in granted || readDistancePermission !in granted) {
            Log.w(TAG, "Skipping loadDailySteps start=$start end=$end missing=${listOf(readStepsPermission, readDistancePermission).filterNot { it in granted }}")
            return emptyList()
        }
        return hc.readDailySteps(start, end)
    }

    suspend fun loadStepProgress(date: LocalDate = LocalDate.now()): List<StepProgressPoint> {
        val granted = grantedPermissionsIfAvailable()
        if (readStepsPermission !in granted) {
            Log.w(TAG, "Skipping loadStepProgress date=$date missing=$readStepsPermission")
            return emptyList()
        }
        return hc.readStepProgress(date)
    }

    suspend fun loadActivityProgress(date: LocalDate = LocalDate.now()): List<ActivityProgressPoint> {
        val granted = grantedPermissionsIfAvailable()
        if (readStepsPermission !in granted) {
            Log.w(TAG, "Skipping loadActivityProgress date=$date missing=$readStepsPermission")
            return emptyList()
        }
        return hc.readActivityProgress(
            date = date,
            includeDistance = readDistancePermission in granted,
            includeCalories = readCaloriesPermission in granted,
        )
    }

    suspend fun loadWorkouts(range: TimeRange): List<ExerciseData> {
        val granted = grantedPermissionsIfAvailable()
        if (readExercisePermission !in granted) {
            Log.w(TAG, "Skipping loadWorkouts range=$range missing=$readExercisePermission")
            return emptyList()
        }
        val zone = ZoneId.systemDefault()
        val end = Instant.now()
        val start = LocalDate.now().minusDays((range.days - 1).toLong())
            .atStartOfDay(zone).toInstant()
        return hc.readExerciseSessions(start, end)
    }

    suspend fun loadWorkouts(start: LocalDate, end: LocalDate): List<ExerciseData> {
        val granted = grantedPermissionsIfAvailable()
        if (readExercisePermission !in granted) {
            Log.w(TAG, "Skipping loadWorkouts start=$start end=$end missing=$readExercisePermission")
            return emptyList()
        }
        val zone = ZoneId.systemDefault()
        val startInstant = start.atStartOfDay(zone).toInstant()
        val endInstant = end.plusDays(1).atStartOfDay(zone).toInstant()
        return hc.readExerciseSessions(startInstant, endInstant)
    }

    // ─── Sleep ────────────────────────────────────────────────────────────────

    suspend fun loadSleepSessions(range: TimeRange): List<SleepData> {
        val granted = grantedPermissionsIfAvailable()
        if (readSleepPermission !in granted) {
            Log.w(TAG, "Skipping loadSleepSessions range=$range missing=$readSleepPermission")
            return emptyList()
        }
        val zone = ZoneId.systemDefault()
        val end = Instant.now()
        val start = LocalDate.now().minusDays((range.days - 1).toLong())
            .atStartOfDay(zone).toInstant()
        return hc.readSleepSessions(start, end)
    }

    suspend fun loadSleepSessions(start: LocalDate, end: LocalDate): List<SleepData> {
        val granted = grantedPermissionsIfAvailable()
        if (readSleepPermission !in granted) {
            Log.w(TAG, "Skipping loadSleepSessions start=$start end=$end missing=$readSleepPermission")
            return emptyList()
        }
        val zone = ZoneId.systemDefault()
        val queryStart = start.minusDays(1).atStartOfDay(zone).toInstant()
        val queryEnd = end.plusDays(1).atStartOfDay(zone).toInstant()
        return hc.readSleepSessions(queryStart, queryEnd)
            .filter { session ->
                val sessionDate = session.endTime.atZone(zone).toLocalDate()
                !sessionDate.isBefore(start) && !sessionDate.isAfter(end)
            }
    }

    // ─── Heart rate ──────────────────────────────────────────────────────────

    suspend fun loadHeartRateSamples(range: TimeRange): List<HeartRateSample> {
        val granted = grantedPermissionsIfAvailable()
        if (readHeartRatePermission !in granted) {
            Log.w(TAG, "Skipping loadHeartRateSamples range=$range missing=$readHeartRatePermission")
            return emptyList()
        }
        val zone = ZoneId.systemDefault()
        val end = Instant.now()
        val start = LocalDate.now().minusDays((range.days - 1).toLong())
            .atStartOfDay(zone).toInstant()
        return hc.readHeartRateSamples(start, end)
    }

    suspend fun loadHeartRateSamples(date: LocalDate): List<HeartRateSample> {
        val granted = grantedPermissionsIfAvailable()
        if (readHeartRatePermission !in granted) {
            Log.w(TAG, "Skipping loadHeartRateSamples date=$date missing=$readHeartRatePermission")
            return emptyList()
        }
        val zone = ZoneId.systemDefault()
        val start = date.atStartOfDay(zone).toInstant()
        val end = date.plusDays(1).atStartOfDay(zone).toInstant()
        return hc.readHeartRateSamples(start, end)
    }

    suspend fun loadDailyHeartRateSummaries(range: TimeRange): List<HeartRateSummary> {
        val granted = grantedPermissionsIfAvailable()
        if (readHeartRatePermission !in granted) {
            Log.w(TAG, "Skipping loadDailyHeartRateSummaries range=$range missing=$readHeartRatePermission")
            return emptyList()
        }
        val end = LocalDate.now()
        val start = end.minusDays(range.days.toLong() - 1)
        return hc.readDailyHeartRateSummaries(start, end)
    }

    suspend fun loadDailyHeartRateSummaries(start: LocalDate, end: LocalDate): List<HeartRateSummary> {
        val granted = grantedPermissionsIfAvailable()
        if (readHeartRatePermission !in granted) {
            Log.w(TAG, "Skipping loadDailyHeartRateSummaries start=$start end=$end missing=$readHeartRatePermission")
            return emptyList()
        }
        return hc.readDailyHeartRateSummaries(start, end)
    }

    // ─── Resting HR + HRV ────────────────────────────────────────────────────

    suspend fun loadRestingHeartRate(date: LocalDate): Long? {
        val granted = grantedPermissionsIfAvailable()
        if (readRestingHRPermission !in granted) return null
        return hc.readRestingHeartRate(date)
    }

    suspend fun loadDailyRestingHR(start: LocalDate, end: LocalDate): List<DailyRestingHR> {
        val granted = grantedPermissionsIfAvailable()
        if (readRestingHRPermission !in granted) {
            Log.w(TAG, "Skipping loadDailyRestingHR start=$start end=$end missing=$readRestingHRPermission")
            return emptyList()
        }
        return hc.readDailyRestingHR(start, end)
    }

    suspend fun loadHrvRmssd(date: LocalDate): Double? {
        val granted = grantedPermissionsIfAvailable()
        if (readHrvPermission !in granted) return null
        return hc.readHrvRmssd(date)
    }

    suspend fun loadDailyHRV(start: LocalDate, end: LocalDate): List<DailyHrv> {
        val granted = grantedPermissionsIfAvailable()
        if (readHrvPermission !in granted) {
            Log.w(TAG, "Skipping loadDailyHRV start=$start end=$end missing=$readHrvPermission")
            return emptyList()
        }
        return hc.readDailyHRV(start, end)
    }

    // ─── Body ─────────────────────────────────────────────────────────────────

    suspend fun loadWeightEntries(range: TimeRange): List<WeightEntry> {
        val granted = grantedPermissionsIfAvailable()
        if (readWeightPermission !in granted) {
            Log.w(TAG, "Skipping loadWeightEntries range=$range missing=$readWeightPermission")
            return emptyList()
        }
        val zone = ZoneId.systemDefault()
        val end = Instant.now()
        val start = LocalDate.now().minusDays((range.days - 1).toLong())
            .atStartOfDay(zone).toInstant()
        return hc.readWeightEntries(start, end)
    }

    suspend fun loadWeightEntries(start: LocalDate, end: LocalDate): List<WeightEntry> {
        val granted = grantedPermissionsIfAvailable()
        if (readWeightPermission !in granted) {
            Log.w(TAG, "Skipping loadWeightEntries start=$start end=$end missing=$readWeightPermission")
            return emptyList()
        }
        val zone = ZoneId.systemDefault()
        val startInstant = start.atStartOfDay(zone).toInstant()
        val endInstant = end.plusDays(1).atStartOfDay(zone).toInstant()
        return hc.readWeightEntries(startInstant, endInstant)
    }

    // ─── Nutrition ────────────────────────────────────────────────────────────

    suspend fun loadDailyNutrition(range: TimeRange): List<DailyNutrition> {
        val granted = grantedPermissionsIfAvailable()
        if (readHydrationPermission !in granted && readCaloriesPermission !in granted) {
            Log.w(TAG, "Skipping loadDailyNutrition range=$range missing both optional permissions")
            return emptyList()
        }
        val end = LocalDate.now()
        val start = end.minusDays(range.days.toLong() - 1)
        return hc.readDailyNutrition(start, end)
    }

    suspend fun loadDailyNutrition(start: LocalDate, end: LocalDate): List<DailyNutrition> {
        val granted = grantedPermissionsIfAvailable()
        if (readHydrationPermission !in granted && readCaloriesPermission !in granted) {
            Log.w(TAG, "Skipping loadDailyNutrition start=$start end=$end missing both optional permissions")
            return emptyList()
        }
        return hc.readDailyNutrition(start, end)
    }
}
