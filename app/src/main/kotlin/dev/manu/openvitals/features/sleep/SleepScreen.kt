package dev.manu.openvitals.features.sleep

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
import androidx.compose.foundation.layout.width
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
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import dev.manu.openvitals.data.model.SleepData
import dev.manu.openvitals.data.model.SleepStage
import dev.manu.openvitals.data.model.TimeRange
import dev.manu.openvitals.ui.components.DatePeriod
import dev.manu.openvitals.ui.components.ErrorMessage
import dev.manu.openvitals.ui.components.HealthDatePickerDialog
import dev.manu.openvitals.ui.components.PeriodNavigator
import dev.manu.openvitals.ui.components.PullToRefreshBox
import dev.manu.openvitals.ui.components.SectionHeader
import dev.manu.openvitals.ui.components.SourceChip
import dev.manu.openvitals.ui.components.TimeRangeSelector
import dev.manu.openvitals.ui.components.periodFor
import dev.manu.openvitals.ui.components.periodTitle
import dev.manu.openvitals.ui.theme.SleepColor
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

private val dayFormatter = DateTimeFormatter.ofPattern("EEE d")
private val dateFormatter = DateTimeFormatter.ofPattern("EEE d MMM")
private val timeFormatter = DateTimeFormatter.ofPattern("HH:mm")

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SleepScreen(viewModel: SleepViewModel) {
    val state by viewModel.uiState.collectAsState()
    var showDatePicker by remember { mutableStateOf(false) }
    val period = periodFor(state.selectedRange, state.selectedDate)
    val primarySession = remember(state.sessions) {
        state.sessions.maxByOrNull { it.durationMs }
    }

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

            when {
                state.selectedRange == TimeRange.DAY && primarySession != null -> {
                    item {
                        SleepSessionTimelineCard(
                            session = primarySession,
                            selectedDate = state.selectedDate,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 8.dp),
                        )
                    }
                }

                state.selectedRange != TimeRange.DAY && state.sessions.isNotEmpty() -> {
                    item {
                        SleepDurationChart(
                            sessions = state.sessions,
                            selectedRange = state.selectedRange,
                            period = period,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 8.dp),
                        )
                    }

                    item { SectionHeader("Sleep sessions") }
                    items(state.sessions.sortedByDescending { it.endTime }) { session ->
                        SleepSessionItem(
                            session = session,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp, vertical = 4.dp),
                        )
                    }
                }

                !state.isLoading -> {
                    item {
                        Text(
                            text = if (state.selectedRange == TimeRange.DAY) {
                                "No sleep data for the selected day."
                            } else {
                                "No sleep data in the selected period."
                            },
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(16.dp),
                        )
                    }
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
private fun SleepDurationChart(
    sessions: List<SleepData>,
    selectedRange: TimeRange,
    period: DatePeriod,
    modifier: Modifier = Modifier,
) {
    val points = sleepDurationPoints(sessions, period)
    val maxHours = points.maxOfOrNull { it.hours }?.coerceAtLeast(1.0) ?: 1.0
    val labelStride = when (selectedRange) {
        TimeRange.DAY,
        TimeRange.WEEK -> 1
        TimeRange.MONTH -> 5
        TimeRange.YEAR -> 30
    }
    val nightsWithSleep = points.filter { it.hours > 0.0 }
    val averageHours = nightsWithSleep.map { it.hours }.average().takeIf { !it.isNaN() } ?: 0.0

    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainer,
        ),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "Sleep duration",
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(Modifier.height(12.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(4.dp),
                verticalAlignment = Alignment.Bottom,
            ) {
                points.forEachIndexed { index, point ->
                    val fraction = if (maxHours > 0) (point.hours / maxHours).toFloat() else 0f
                    Column(
                        modifier = Modifier.weight(1f),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Canvas(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height((100 * fraction + 4).dp),
                        ) {
                            drawRoundRect(
                                color = SleepColor.copy(alpha = 0.75f),
                                cornerRadius = CornerRadius(4.dp.toPx()),
                            )
                        }
                        if (index % labelStride == 0 || index == points.lastIndex) {
                            Text(
                                text = dayFormatter.format(point.date),
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(top = 4.dp),
                            )
                        } else {
                            Spacer(Modifier.height(20.dp))
                        }
                    }
                }
            }
            Spacer(Modifier.height(8.dp))
            Text(
                text = "${periodTitle(selectedRange, period)} · Avg %.1fh · %d nights".format(
                    averageHours,
                    nightsWithSleep.size,
                ),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

@Composable
private fun SleepSessionTimelineCard(
    session: SleepData,
    selectedDate: LocalDate,
    modifier: Modifier = Modifier,
) {
    val zone = ZoneId.systemDefault()
    val start = session.startTime.atZone(zone)
    val end = session.endTime.atZone(zone)

    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainer,
        ),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = session.durationFormatted,
                        style = MaterialTheme.typography.headlineMedium,
                        color = SleepColor,
                    )
                    Text(
                        text = if (selectedDate == LocalDate.now()) {
                            "Sleep ending today"
                        } else {
                            "Sleep ending on ${dateFormatter.format(selectedDate)}"
                        },
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                SourceChip(source = session.source)
            }

            Spacer(Modifier.height(12.dp))
            Text(
                text = "${dateFormatter.format(start)}  ·  ${timeFormatter.format(start)} - ${timeFormatter.format(end)}",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface,
            )

            if (session.stages.isNotEmpty()) {
                Spacer(Modifier.height(16.dp))
                SleepStagesBar(
                    stages = session.stages,
                    totalMs = session.durationMs,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(24.dp),
                )
                Spacer(Modifier.height(8.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                ) {
                    Text(
                        text = timeFormatter.format(start),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    Text(
                        text = timeFormatter.format(end),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Spacer(Modifier.height(12.dp))
                SleepStageLegend(stages = session.stages)
            }
        }
    }
}

@Composable
private fun SleepSessionItem(session: SleepData, modifier: Modifier = Modifier) {
    val zone = ZoneId.systemDefault()
    val start = session.startTime.atZone(zone)
    val end = session.endTime.atZone(zone)

    Card(
        modifier = modifier,
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceContainer,
        ),
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column {
                    Text(
                        text = dateFormatter.format(end),
                        style = MaterialTheme.typography.titleSmall,
                    )
                    Text(
                        text = "${timeFormatter.format(start)} - ${timeFormatter.format(end)}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text(
                        text = session.durationFormatted,
                        style = MaterialTheme.typography.titleMedium,
                        color = SleepColor,
                    )
                    SourceChip(source = session.source)
                }
            }

            if (session.stages.isNotEmpty()) {
                Spacer(Modifier.height(12.dp))
                SleepStagesBar(
                    stages = session.stages,
                    totalMs = session.durationMs,
                )
                Spacer(Modifier.height(8.dp))
                SleepStageLegend(stages = session.stages)
            }
        }
    }
}

@Composable
private fun SleepStagesBar(
    stages: List<SleepStage>,
    totalMs: Long,
    modifier: Modifier = Modifier,
) {
    if (totalMs == 0L) return
    Canvas(modifier = modifier) {
        var x = 0f
        stages.sortedBy { it.startTime }.forEach { stage ->
            val fraction = stage.durationMs.toFloat() / totalMs
            val width = size.width * fraction
            drawRoundRect(
                color = stageColor(stage.stageType),
                topLeft = Offset(x, 0f),
                size = Size(width, size.height),
                cornerRadius = CornerRadius(4.dp.toPx()),
            )
            x += width
        }
    }
}

@Composable
private fun SleepStageLegend(stages: List<SleepStage>) {
    val stageTotals = stages
        .groupBy { it.stageType }
        .mapValues { (_, list) -> list.sumOf { it.durationMs } }
        .toList()
        .sortedByDescending { it.second }

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        stageTotals.forEach { (stageType, durationMs) ->
            val hours = durationMs / 3_600_000
            val mins = (durationMs % 3_600_000) / 60_000
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Canvas(modifier = Modifier.height(8.dp).width(8.dp)) {
                    drawCircle(color = stageColor(stageType))
                }
                Text(
                    text = SleepStage.stageLabel(stageType),
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Text(
                    text = if (hours > 0) "${hours}h ${mins}m" else "${mins}m",
                    style = MaterialTheme.typography.labelSmall,
                )
            }
        }
    }
}

private fun sleepDurationPoints(
    sessions: List<SleepData>,
    period: DatePeriod,
): List<SleepDurationPoint> {
    val zone = ZoneId.systemDefault()
    val sessionByDate = sessions
        .groupBy { it.endTime.atZone(zone).toLocalDate() }
        .mapValues { (_, dailySessions) -> dailySessions.maxByOrNull { it.durationMs } }

    return generateSequence(period.start) { current ->
        current.plusDays(1).takeUnless { it.isAfter(period.end) }
    }.map { date ->
        SleepDurationPoint(
            date = date,
            hours = sessionByDate[date]?.durationHours ?: 0.0,
        )
    }.toList()
}

private data class SleepDurationPoint(
    val date: LocalDate,
    val hours: Double,
)

private fun stageColor(stageType: Int): Color = when (stageType) {
    SleepStage.STAGE_AWAKE -> Color(0xFFFFB74D)
    SleepStage.STAGE_LIGHT -> Color(0xFF90CAF9)
    SleepStage.STAGE_DEEP -> Color(0xFF3949AB)
    SleepStage.STAGE_REM -> Color(0xFF7E57C2)
    SleepStage.STAGE_SLEEPING -> Color(0xFF5C6BC0)
    SleepStage.STAGE_OUT_OF_BED -> Color(0xFFEF9A9A)
    else -> Color(0xFF90A4AE)
}
