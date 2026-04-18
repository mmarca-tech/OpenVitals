package dev.manu.hcdashboard.features.body

import androidx.compose.foundation.Canvas
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
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.unit.dp
import dev.manu.hcdashboard.data.model.WeightEntry
import dev.manu.hcdashboard.ui.components.ErrorMessage
import dev.manu.hcdashboard.ui.components.HealthDatePickerDialog
import dev.manu.hcdashboard.ui.components.PeriodNavigator
import dev.manu.hcdashboard.ui.components.PullToRefreshBox
import dev.manu.hcdashboard.ui.components.SectionHeader
import dev.manu.hcdashboard.ui.components.SourceChip
import dev.manu.hcdashboard.ui.components.TimeRangeSelector
import dev.manu.hcdashboard.ui.components.periodFor
import dev.manu.hcdashboard.ui.theme.WeightColor
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val dateFormatter = DateTimeFormatter.ofPattern("d MMM")
private val dateTimeFormatter = DateTimeFormatter.ofPattern("d MMM HH:mm")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BodyScreen(viewModel: BodyViewModel) {
    val state by viewModel.uiState.collectAsState()
    var showDatePicker by remember { mutableStateOf(false) }
    val period = periodFor(state.selectedRange, state.selectedDate)

    PullToRefreshBox(
        isRefreshing = state.isLoading,
        onRefresh = viewModel::load,
        modifier = Modifier.fillMaxSize(),
    ) {
        LazyColumn(contentPadding = PaddingValues(vertical = 8.dp)) {
            item {
                TimeRangeSelector(
                    selected = state.selectedRange,
                    onSelect = viewModel::selectRange,
                    modifier = Modifier.padding(vertical = 8.dp),
                )
            }

            item {
                PeriodNavigator(
                    selectedRange = state.selectedRange,
                    period = period,
                    canGoForward = !period.end.isEqual(LocalDate.now()),
                    onPreviousPeriod = viewModel::previousPeriod,
                    onNextPeriod = viewModel::nextPeriod,
                    onOpenCalendar = { showDatePicker = true },
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                )
            }

            state.error?.let { err ->
                item { ErrorMessage(err) }
            }

            if (state.weightEntries.isNotEmpty()) {
                // ─── Summary card ─────────────────────────────────────────
                item { SectionHeader("Weight") }
                item {
                    WeightSummaryCard(
                        latestKg = state.latestWeightKg,
                        changeKg = state.weightChangKg,
                        modifier = Modifier.padding(horizontal = 16.dp),
                    )
                }

                // ─── Weight chart ─────────────────────────────────────────
                item { Spacer(Modifier.height(12.dp)) }
                item {
                    WeightLineChart(
                        entries = state.weightEntries,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp),
                    )
                }

                // ─── Entries list ─────────────────────────────────────────
                item { SectionHeader("Entries") }
                items(state.weightEntries.sortedByDescending { it.time }) { entry ->
                    WeightEntryRow(
                        entry = entry,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 4.dp),
                    )
                }
            } else if (!state.isLoading) {
                item {
                    Text(
                        text = "No weight data in the selected period.\n\nSync a scale or wearable that reports weight to Health Connect.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(16.dp),
                    )
                }
            }

            item { Spacer(Modifier.height(16.dp)) }
        }
    }

    if (showDatePicker) {
        HealthDatePickerDialog(
            selectedDate = state.selectedDate,
            onDismiss = { showDatePicker = false },
            onConfirm = { date ->
                showDatePicker = false
                viewModel.selectDate(date)
            },
        )
    }
}

@Composable
private fun WeightSummaryCard(
    latestKg: Double?,
    changeKg: Double?,
    modifier: Modifier = Modifier,
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainer,
        ),
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column {
                Text(
                    text = "Latest",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = latestKg?.let { "%.1f kg".format(it) } ?: "–",
                    style = MaterialTheme.typography.headlineSmall,
                    color = WeightColor,
                )
            }
            if (changeKg != null) {
                Column(horizontalAlignment = Alignment.End) {
                    Text(
                        text = "Change",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    val sign = if (changeKg >= 0) "+" else ""
                    Text(
                        text = "$sign%.1f kg".format(changeKg),
                        style = MaterialTheme.typography.headlineSmall,
                        color = if (changeKg < 0) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.error,
                    )
                }
            }
        }
    }
}

@Composable
private fun WeightLineChart(entries: List<WeightEntry>, modifier: Modifier = Modifier) {
    val sorted = entries.sortedBy { it.time }
    val maxKg = sorted.maxOfOrNull { it.weightKg } ?: 100.0
    val minKg = sorted.minOfOrNull { it.weightKg } ?: 50.0
    val range = (maxKg - minKg).coerceAtLeast(0.5)

    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainer,
        ),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(100.dp),
            ) {
                if (sorted.size < 2) return@Canvas
                val stepX = size.width / (sorted.size - 1)
                val points = sorted.mapIndexed { i, entry ->
                    val x = i * stepX
                    val y = size.height * (1f - ((entry.weightKg - minKg) / range).toFloat())
                    Offset(x, y)
                }
                for (i in 0 until points.size - 1) {
                    drawLine(
                        color = WeightColor,
                        start = points[i],
                        end = points[i + 1],
                        strokeWidth = 2.dp.toPx(),
                    )
                }
                points.forEach { pt ->
                    drawCircle(color = WeightColor, radius = 4.dp.toPx(), center = pt)
                }
            }
            Spacer(Modifier.height(8.dp))
            Text(
                text = "%.1f – %.1f kg · %d entries".format(minKg, maxKg, sorted.size),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun WeightEntryRow(entry: WeightEntry, modifier: Modifier = Modifier) {
    val zone = ZoneId.systemDefault()
    val time = entry.time.atZone(zone)
    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainer,
        ),
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column {
                Text(
                    text = dateTimeFormatter.format(time),
                    style = MaterialTheme.typography.bodyMedium,
                )
                SourceChip(source = entry.source)
            }
            Text(
                text = "%.1f kg".format(entry.weightKg),
                style = MaterialTheme.typography.titleMedium,
                color = WeightColor,
            )
        }
    }
}
