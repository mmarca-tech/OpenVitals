package dev.manu.openvitals

import android.content.SharedPreferences
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import dev.manu.openvitals.navigation.AppNavigation
import dev.manu.openvitals.navigation.Screen
import dev.manu.openvitals.ui.theme.OpenVitalsTheme

private const val PREFS_NAME = "openvitals_prefs"
private const val KEY_ONBOARDING_DONE = "onboarding_done"

class MainActivity : ComponentActivity() {

    private lateinit var prefs: SharedPreferences

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
        val onboardingDone = prefs.getBoolean(KEY_ONBOARDING_DONE, false)

        val app = application as OpenVitalsApp

        setContent {
            OpenVitalsTheme {
                var startDestination by remember {
                    mutableStateOf(
                        if (onboardingDone) Screen.Dashboard.route
                        else Screen.Onboarding.route
                    )
                }

                AppNavigation(
                    repository = app.healthRepository,
                    activityRepository = app.activityRepository,
                    sleepRepository = app.sleepRepository,
                    heartRepository = app.heartRepository,
                    bodyRepository = app.bodyRepository,
                    startDestination = startDestination,
                    onOnboardingComplete = {
                        markOnboardingDone()
                        startDestination = Screen.Dashboard.route
                    },
                )
            }
        }
    }

    /**
     * Called from the onboarding flow to persist the completed state.
     * This is wired through the navigation callback.
     */
    fun markOnboardingDone() {
        prefs.edit().putBoolean(KEY_ONBOARDING_DONE, true).apply()
    }
}
