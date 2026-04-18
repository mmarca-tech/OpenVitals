package dev.manu.hcdashboard.data.repository

import android.util.Log
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.WeightRecord
import dev.manu.hcdashboard.data.model.HealthConnectAvailability
import dev.manu.hcdashboard.data.model.WeightEntry
import dev.manu.hcdashboard.healthconnect.HealthConnectManager
import java.time.LocalDate
import java.time.ZoneId

class BodyRepository(private val hc: HealthConnectManager) {

    companion object {
        private const val TAG = "BodyRepository"
    }

    private val readWeightPermission = HealthPermission.getReadPermission(WeightRecord::class)

    private suspend fun grantedPermissionsIfAvailable(): Set<String> =
        if (hc.availability() == HealthConnectAvailability.AVAILABLE) hc.grantedPermissions() else emptySet()

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
}
