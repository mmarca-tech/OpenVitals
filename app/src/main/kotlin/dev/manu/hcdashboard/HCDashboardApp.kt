package dev.manu.hcdashboard

import android.app.Application
import dev.manu.hcdashboard.data.repository.ActivityRepository
import dev.manu.hcdashboard.data.repository.BodyRepository
import dev.manu.hcdashboard.data.repository.HeartRepository
import dev.manu.hcdashboard.data.repository.HealthRepository
import dev.manu.hcdashboard.data.repository.SleepRepository
import dev.manu.hcdashboard.healthconnect.HealthConnectManager

class HCDashboardApp : Application() {

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
