package dev.manu.openvitals.features.activity

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.DirectionsRun
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.manu.openvitals.data.model.ExerciseData
import dev.manu.openvitals.data.model.TimeRange
import dev.manu.openvitals.ui.components.MetricDetailScaffold
import dev.manu.openvitals.ui.components.SectionHeader
import dev.manu.openvitals.ui.components.SourceChip
import dev.manu.openvitals.ui.theme.DistanceColor
import dev.manu.openvitals.ui.theme.WorkoutColor
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlin.math.roundToInt

private val activityDateFormatter = DateTimeFormatter.ofPattern("EEE d MMM")
private val activityTimeFormatter = DateTimeFormatter.ofPattern("HH:mm")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ActivitiesScreen(viewModel: ActivitiesViewModel) {
    val state by viewModel.uiState.collectAsState()

    MetricDetailScaffold(
        isLoading = state.isLoading,
        selectedRange = state.selectedRange,
        selectedDate = state.selectedDate,
        error = state.error,
        onRefresh = viewModel::load,
        onSelectRange = viewModel::selectRange,
        onPreviousPeriod = viewModel::previousPeriod,
        onNextPeriod = viewModel::nextPeriod,
        onSelectDate = viewModel::selectDate,
    ) { _ ->
        if (state.workouts.isNotEmpty()) {
            item { SectionHeader("Activities") }
            items(state.workouts) { workout ->
                WorkoutListItem(
                    workout = workout,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 4.dp),
                )
            }
        } else if (!state.isLoading) {
            item {
                Text(
                    text = "No activities in the selected period.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(16.dp),
                )
            }
        }
    }
}

@Composable
private fun WorkoutListItem(workout: ExerciseData, modifier: Modifier = Modifier) {
    val zone = ZoneId.systemDefault()
    val start = workout.startTime.atZone(zone)

    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainer,
        ),
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            androidx.compose.material3.Icon(
                imageVector = Icons.Outlined.DirectionsRun,
                contentDescription = null,
                tint = WorkoutColor,
            )
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = workout.title ?: exerciseTypeShortLabel(workout.exerciseType),
                    style = MaterialTheme.typography.titleSmall,
                )
                Text(
                    text = "${activityDateFormatter.format(start)}  ·  ${activityTimeFormatter.format(start)}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                workout.totalDistanceMeters?.let { d ->
                    Text(
                        text = if (d >= 1000) "%.2f km".format(d / 1000) else "%d m".format(d.roundToInt()),
                        style = MaterialTheme.typography.bodySmall,
                        color = DistanceColor,
                    )
                }
            }
            Column(horizontalAlignment = Alignment.End) {
                Text(
                    text = "%dh %02dm".format(
                        workout.durationMinutes / 60,
                        workout.durationMinutes % 60,
                    ),
                    style = MaterialTheme.typography.labelLarge,
                )
                Spacer(Modifier.height(4.dp))
                SourceChip(source = workout.source)
            }
        }
    }
}

private fun exerciseTypeShortLabel(type: Int): String = when (type) {
    8, 9 -> "Biking"
    27 -> "Hiking"
    38, 39 -> "Rowing"
    41, 42 -> "Running"
    54 -> "Strength training"
    57, 58 -> "Swimming"
    62 -> "Walking"
    66 -> "Yoga"
    else -> "Exercise"
}
