package dev.manu.hcdashboard

import android.app.Application
import dev.manu.hcdashboard.data.repository.HealthRepository
import dev.manu.hcdashboard.healthconnect.HealthConnectManager

/**
 * Application class used for simple manual DI.
 *
 * ViewModels receive [HealthRepository] as a constructor parameter.
 * Both the manager and repository are lazily created singletons.
 */
class HCDashboardApp : Application() {

    val healthConnectManager: HealthConnectManager by lazy {
        HealthConnectManager(this)
    }

    val healthRepository: HealthRepository by lazy {
        HealthRepository(healthConnectManager)
    }
}
