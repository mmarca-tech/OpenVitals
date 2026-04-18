package dev.manu.hcdashboard.data.repository

import android.util.Log
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.HeartRateRecord
import androidx.health.connect.client.records.HeartRateVariabilityRmssdRecord
import androidx.health.connect.client.records.RestingHeartRateRecord
import dev.manu.hcdashboard.data.model.DailyHrv
import dev.manu.hcdashboard.data.model.DailyRestingHR
import dev.manu.hcdashboard.data.model.HealthConnectAvailability
import dev.manu.hcdashboard.data.model.HeartRateSample
import dev.manu.hcdashboard.data.model.HeartRateSummary
import dev.manu.hcdashboard.healthconnect.HealthConnectManager
import java.time.LocalDate
import java.time.ZoneId

class HeartRepository(private val hc: HealthConnectManager) {

    companion object {
        private const val TAG = "HeartRepository"
    }

    private val readHeartRatePermission = HealthPermission.getReadPermission(HeartRateRecord::class)
    private val readRestingHRPermission = HealthPermission.getReadPermission(RestingHeartRateRecord::class)
    private val readHrvPermission = HealthPermission.getReadPermission(HeartRateVariabilityRmssdRecord::class)

    private suspend fun grantedPermissionsIfAvailable(): Set<String> =
        if (hc.availability() == HealthConnectAvailability.AVAILABLE) hc.grantedPermissions() else emptySet()

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

    suspend fun loadDailyHeartRateSummaries(start: LocalDate, end: LocalDate): List<HeartRateSummary> {
        val granted = grantedPermissionsIfAvailable()
        if (readHeartRatePermission !in granted) {
            Log.w(TAG, "Skipping loadDailyHeartRateSummaries start=$start end=$end missing=$readHeartRatePermission")
            return emptyList()
        }
        return hc.readDailyHeartRateSummaries(start, end)
    }

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
}
