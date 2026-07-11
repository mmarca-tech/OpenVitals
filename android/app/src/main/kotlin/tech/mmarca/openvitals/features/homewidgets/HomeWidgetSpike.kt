package tech.mmarca.openvitals.features.homewidgets

import androidx.compose.runtime.Composable
import androidx.glance.GlanceModifier
import androidx.glance.GlanceTheme
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.provideContent
import androidx.glance.background
import androidx.glance.currentState
import androidx.glance.layout.Column
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.state.GlanceStateDefinition
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import es.antonborri.home_widget.HomeWidgetGlanceState
import es.antonborri.home_widget.HomeWidgetGlanceStateDefinition
import es.antonborri.home_widget.HomeWidgetGlanceWidgetReceiver

/**
 * PHASE-0 SPIKE — proves Glance + the Compose compiler build under AGP 9 /
 * Flutter's Built-in Kotlin before the six real widgets are written.
 *
 * It also pins down the two load-bearing APIs the real widgets rely on:
 * rendering from [HomeWidgetGlanceStateDefinition] (the shared
 * `HomeWidgetPreferences` file that Dart's `pushSnapshot` writes), and the
 * [HomeWidgetGlanceWidgetReceiver] base that re-renders on `updateWidget`.
 *
 * Delete once HomeDailyReadinessWidget lands.
 */
internal class HomeWidgetSpike : GlanceAppWidget() {

    override val stateDefinition: GlanceStateDefinition<HomeWidgetGlanceState> =
        HomeWidgetGlanceStateDefinition()

    override suspend fun provideGlance(
        context: android.content.Context,
        id: androidx.glance.GlanceId,
    ) {
        provideContent { GlanceTheme { Content() } }
    }

    @Composable
    private fun Content() {
        val prefs = currentState<HomeWidgetGlanceState>().preferences
        val title = prefs.getString("title", null) ?: "OpenVitals"
        Column(
            modifier = GlanceModifier
                .fillMaxSize()
                .background(HomeWidgetTokens.BackgroundProvider)
                .padding(16.dp),
        ) {
            Text(
                text = title,
                style = TextStyle(
                    color = HomeWidgetTokens.PrimaryTextProvider,
                    fontSize = 13.sp,
                ),
            )
        }
    }
}

internal class HomeWidgetSpikeReceiver : HomeWidgetGlanceWidgetReceiver<HomeWidgetSpike>() {
    override val glanceAppWidget = HomeWidgetSpike()
}
