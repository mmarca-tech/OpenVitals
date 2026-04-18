package dev.manu.hcdashboard.features.browse

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import dev.manu.hcdashboard.data.model.ExerciseData
import dev.manu.hcdashboard.data.model.SleepData
import dev.manu.hcdashboard.data.model.WeightEntry
import dev.manu.hcdashboard.ui.components.ErrorMessage
import dev.manu.hcdashboard.ui.components.InlineLoading
import dev.manu.hcdashboard.ui.components.PullToRefreshBox
import dev.manu.hcdashboard.ui.components.SectionHeader
import dev.manu.hcdashboard.ui.components.SourceChip
import dev.manu.hcdashboard.ui.components.TimeRangeSelector
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val dateTimeFormatter = DateTimeFormatter.ofPattern("d MMM yyyy HH:mm")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BrowseScreen(viewModel: BrowseViewModel) {
    val state by viewModel.uiState.collectAsState()

    PullToRefreshBox(
        isRefreshing = state.isLoading,
        onRefresh = viewModel::load,
        modifier = Modifier.fillMaxSize(),
    ) {
        LazyColumn(contentPadding = PaddingValues(vertical = 8.dp)) {
            item {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    BrowseCategory.entries.forEach { cat ->
                        FilterChip(
                            selected = cat == state.selectedCategory,
                            onClick = { viewModel.selectCategory(cat) },
                            label = { Text(cat.label) },
                        )
                    }
                }
            }

            item {
                TimeRangeSelector(
                    selected = state.selectedRange,
                    onSelect = viewModel::selectRange,
                    modifier = Modifier.padding(vertical = 4.dp),
                )
            }

            state.error?.let { err ->
                item { ErrorMessage(err) }
            }

            if (state.isLoading) {
                item { InlineLoading() }
            } else {
                when (state.selectedCategory) {
                    BrowseCategory.WORKOUTS -> {
                        if (state.workouts.isEmpty()) {
                            item { EmptyState("No workouts in the selected period.", Modifier.padding(16.dp)) }
                        } else {
                            item { SectionHeader("${state.workouts.size} workouts") }
                            items(state.workouts) { w ->
                                WorkoutBrowseRow(
                                    workout = w,
                                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                                )
                            }
                        }
                    }

                    BrowseCategory.SLEEP -> {
                        if (state.sleepSessions.isEmpty()) {
                            item { EmptyState("No sleep sessions in the selected period.", Modifier.padding(16.dp)) }
                        } else {
                            item { SectionHeader("${state.sleepSessions.size} sleep sessions") }
                            items(state.sleepSessions) { s ->
                                SleepBrowseRow(
                                    session = s,
                                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                                )
                            }
                        }
                    }

                    BrowseCategory.WEIGHT -> {
                        if (state.weightEntries.isEmpty()) {
                            item { EmptyState("No weight entries in the selected period.", Modifier.padding(16.dp)) }
                        } else {
                            item { SectionHeader("${state.weightEntries.size} weight entries") }
                            items(state.weightEntries.sortedByDescending { it.time }) { w ->
                                WeightBrowseRow(
                                    entry = w,
                                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                                )
                            }
                        }
                    }
                }
            }

            item { Spacer(Modifier.height(16.dp)) }
        }
    }
}

@Composable
private fun EmptyState(message: String, modifier: Modifier = Modifier) {
    Text(
        text = message,
        style = MaterialTheme.typography.bodyMedium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = modifier,
    )
}

@Composable
private fun WorkoutBrowseRow(
    workout: ExerciseData,
    modifier: Modifier = Modifier,
) {
    val zone = ZoneId.systemDefault()
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = workout.title ?: "Exercise",
                    style = MaterialTheme.typography.titleSmall,
                )
                Text(
                    text = dateTimeFormatter.format(workout.startTime.atZone(zone)),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                SourceChip(source = workout.source)
            }
            Text(
                text = "%dh %02dm".format(
                    workout.durationMinutes / 60,
                    workout.durationMinutes % 60,
                ),
                style = MaterialTheme.typography.labelLarge,
            )
        }
    }
}

@Composable
private fun SleepBrowseRow(
    session: SleepData,
    modifier: Modifier = Modifier,
) {
    val zone = ZoneId.systemDefault()
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = dateTimeFormatter.format(session.startTime.atZone(zone)),
                    style = MaterialTheme.typography.bodyMedium,
                )
                Text(
                    text = "${session.stages.size} stages",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                SourceChip(source = session.source)
            }
            Text(
                text = session.durationFormatted,
                style = MaterialTheme.typography.labelLarge,
            )
        }
    }
}

@Composable
private fun WeightBrowseRow(
    entry: WeightEntry,
    modifier: Modifier = Modifier,
) {
    val zone = ZoneId.systemDefault()
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer),
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column {
                Text(
                    text = dateTimeFormatter.format(entry.time.atZone(zone)),
                    style = MaterialTheme.typography.bodyMedium,
                )
                SourceChip(source = entry.source)
            }
            Text(
                text = "%.1f kg".format(entry.weightKg),
                style = MaterialTheme.typography.titleSmall,
            )
        }
    }
}
