package dev.manu.openvitals

import android.app.Application
import dev.manu.openvitals.data.repository.ActivityRepository
import dev.manu.openvitals.data.repository.BodyRepository
import dev.manu.openvitals.data.repository.HeartRepository
import dev.manu.openvitals.data.repository.HealthRepository
import dev.manu.openvitals.data.repository.SleepRepository
import dev.manu.openvitals.healthconnect.HealthConnectManager

class OpenVitalsApp : Application() {

    val healthConnectManager: HealthConnectManager by lazy {
        HealthConnectManager(this)
    }

    val healthRepository: HealthRepository by lazy {
        HealthRepository(healthConnectManager)
    }

    val activityRepository: ActivityRepository by lazy {
        ActivityRepository(healthConnectManager)
    }

    val sleepRepository: SleepRepository by lazy {
        SleepRepository(healthConnectManager)
    }

    val heartRepository: HeartRepository by lazy {
        HeartRepository(healthConnectManager)
    }

    val bodyRepository: BodyRepository by lazy {
        BodyRepository(healthConnectManager)
    }
}
