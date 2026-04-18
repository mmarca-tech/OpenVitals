package dev.manu.hcdashboard.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import dev.manu.hcdashboard.data.repository.ActivityRepository
import dev.manu.hcdashboard.data.repository.BodyRepository
import dev.manu.hcdashboard.data.repository.HeartRepository
import dev.manu.hcdashboard.data.repository.HealthRepository
import dev.manu.hcdashboard.data.repository.SleepRepository
import dev.manu.hcdashboard.features.activity.ActivityScreen
import dev.manu.hcdashboard.features.activity.ActivityViewModel
import dev.manu.hcdashboard.features.activity.ActivitiesScreen
import dev.manu.hcdashboard.features.activity.ActivitiesViewModel
import dev.manu.hcdashboard.features.body.BodyScreen
import dev.manu.hcdashboard.features.body.BodyViewModel
import dev.manu.hcdashboard.features.browse.BrowseScreen
import dev.manu.hcdashboard.features.browse.BrowseViewModel
import dev.manu.hcdashboard.features.dashboard.DashboardScreen
import dev.manu.hcdashboard.features.dashboard.DashboardViewModel
import dev.manu.hcdashboard.features.heart.HeartScreen
import dev.manu.hcdashboard.features.heart.HeartViewModel
import dev.manu.hcdashboard.features.onboarding.OnboardingScreen
import dev.manu.hcdashboard.features.onboarding.OnboardingViewModel
import dev.manu.hcdashboard.features.settings.SettingsScreen
import dev.manu.hcdashboard.features.settings.SettingsViewModel
import dev.manu.hcdashboard.features.sleep.SleepScreen
import dev.manu.hcdashboard.features.sleep.SleepViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AppNavigation(
    repository: HealthRepository,
    activityRepository: ActivityRepository,
    sleepRepository: SleepRepository,
    heartRepository: HeartRepository,
    bodyRepository: BodyRepository,
    startDestination: String,
    onOnboardingComplete: () -> Unit = {},
) {
    val navController = rememberNavController()
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination
    val currentRoute = currentDestination?.route

    val showTopBar = currentRoute != Screen.Onboarding.route
    val canNavigateBack =
        currentRoute != null &&
            currentRoute != Screen.Onboarding.route &&
            currentRoute != Screen.Dashboard.route &&
            navController.previousBackStackEntry != null

    val topBarTitle = when (currentRoute) {
        Screen.Dashboard.route -> "Dashboard"
        Screen.Steps.route -> "Steps"
        Screen.Activity.route -> "Activities"
        Screen.Sleep.route -> "Sleep"
        Screen.Heart.route -> "Heart"
        Screen.Body.route -> "Body"
        Screen.Browse.route -> "Browse"
        Screen.Settings.route -> "Settings"
        else -> ""
    }

    Scaffold(
        topBar = {
            if (showTopBar) {
                TopAppBar(
                    title = { Text(topBarTitle) },
                    navigationIcon = {
                        if (canNavigateBack) {
                            IconButton(onClick = { navController.popBackStack() }) {
                                Icon(
                                    imageVector = Icons.AutoMirrored.Outlined.ArrowBack,
                                    contentDescription = "Back",
                                )
                            }
                        }
                    },
                    actions = {
                        if (currentRoute != Screen.Settings.route) {
                            IconButton(onClick = { navController.navigate(Screen.Settings.route) }) {
                                Icon(Icons.Outlined.Settings, contentDescription = "Settings")
                            }
                        }
                    },
                )
            }
        },
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = startDestination,
            modifier = Modifier.padding(innerPadding),
        ) {
            composable(Screen.Onboarding.route) {
                val onboardingViewModel = remember(repository) { OnboardingViewModel(repository) }
                OnboardingScreen(
                    viewModel = onboardingViewModel,
                    onOnboardingComplete = {
                        onOnboardingComplete()
                        navController.navigate(Screen.Dashboard.route) {
                            popUpTo(Screen.Onboarding.route) { inclusive = true }
                        }
                    },
                )
            }

            composable(Screen.Dashboard.route) {
                val dashboardViewModel = remember(repository) { DashboardViewModel(repository) }
                DashboardScreen(
                    viewModel = dashboardViewModel,
                    onGrantPermissions = { navController.navigate(Screen.Settings.route) },
                    onOpenSteps = { navController.navigate(Screen.Steps.route) },
                    onOpenActivities = { navController.navigate(Screen.Activity.route) },
                    onOpenSleep = { navController.navigate(Screen.Sleep.route) },
                    onOpenHeart = { navController.navigate(Screen.Heart.route) },
                    onOpenBody = { navController.navigate(Screen.Body.route) },
                    onOpenBrowse = { navController.navigate(Screen.Browse.route) },
                )
            }

            composable(Screen.Steps.route) {
                val activityViewModel = remember(activityRepository) { ActivityViewModel(activityRepository) }
                ActivityScreen(viewModel = activityViewModel)
            }

            composable(Screen.Activity.route) {
                val activitiesViewModel = remember(activityRepository) { ActivitiesViewModel(activityRepository) }
                ActivitiesScreen(viewModel = activitiesViewModel)
            }

            composable(Screen.Sleep.route) {
                val sleepViewModel = remember(sleepRepository) { SleepViewModel(sleepRepository) }
                SleepScreen(viewModel = sleepViewModel)
            }

            composable(Screen.Heart.route) {
                val heartViewModel = remember(heartRepository) { HeartViewModel(heartRepository) }
                HeartScreen(viewModel = heartViewModel)
            }

            composable(Screen.Body.route) {
                val bodyViewModel = remember(bodyRepository) { BodyViewModel(bodyRepository) }
                BodyScreen(viewModel = bodyViewModel)
            }

            composable(Screen.Browse.route) {
                val browseViewModel = remember(activityRepository, sleepRepository, bodyRepository) {
                    BrowseViewModel(activityRepository, sleepRepository, bodyRepository)
                }
                BrowseScreen(viewModel = browseViewModel)
            }

            composable(Screen.Settings.route) {
                val settingsViewModel = remember(repository) { SettingsViewModel(repository) }
                SettingsScreen(
                    viewModel = settingsViewModel,
                    onBack = { navController.popBackStack() },
                )
            }
        }
    }
}
