package tech.mmarca.openvitals.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material.icons.outlined.ChevronLeft
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import tech.mmarca.openvitals.data.model.TimeRange
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.time.temporal.TemporalAdjusters

private val dateFormatter = DateTimeFormatter.ofPattern("EEE d MMM")
private val monthFormatter = DateTimeFormatter.ofPattern("LLLL yyyy")
private val yearFormatter = DateTimeFormatter.ofPattern("yyyy")

data class DatePeriod(
    val start: LocalDate,
    val end: LocalDate,
)

fun periodFor(range: TimeRange, anchorDate: LocalDate): DatePeriod {
    val today = LocalDate.now()
    return when (range) {
        TimeRange.DAY -> DatePeriod(
            start = anchorDate,
            end = anchorDate,
        )
        TimeRange.WEEK -> {
            val start = anchorDate.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY))
            val end = start.plusDays(6).coerceAtMost(today)
            DatePeriod(start = start, end = end)
        }
        TimeRange.MONTH -> {
            val start = anchorDate.withDayOfMonth(1)
            val end = anchorDate.withDayOfMonth(anchorDate.lengthOfMonth()).coerceAtMost(today)
            DatePeriod(start = start, end = end)
        }
        TimeRange.YEAR -> {
            val start = anchorDate.withDayOfYear(1)
            val end = anchorDate.withDayOfYear(anchorDate.lengthOfYear()).coerceAtMost(today)
            DatePeriod(start = start, end = end)
        }
    }
}

fun periodTitle(range: TimeRange, period: DatePeriod): String {
    val today = LocalDate.now()
    return when (range) {
        TimeRange.DAY -> when (period.start) {
            today -> "Today"
            today.minusDays(1) -> "Yesterday"
            else -> dateFormatter.format(period.start)
        }
        TimeRange.WEEK -> if (period.end == today) "This week" else "Week of ${dateFormatter.format(period.start)}"
        TimeRange.MONTH -> if (period.end == today) "This month" else monthFormatter.format(period.start)
        TimeRange.YEAR -> if (period.end == today) "This year" else yearFormatter.format(period.start)
    }
}

fun periodSubtitle(range: TimeRange, period: DatePeriod): String = when (range) {
    TimeRange.DAY -> dateFormatter.format(period.start)
    TimeRange.WEEK -> "${dateFormatter.format(period.start)} - ${dateFormatter.format(period.end)}"
    TimeRange.MONTH,
    TimeRange.YEAR -> "${dateFormatter.format(period.start)} - ${dateFormatter.format(period.end)}"
}

@Composable
fun PeriodNavigator(
    selectedRange: TimeRange,
    period: DatePeriod,
    canGoForward: Boolean,
    onPreviousPeriod: () -> Unit,
    onNextPeriod: () -> Unit,
    onOpenCalendar: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Surface(
        color = MaterialTheme.colorScheme.surfaceContainerLow,
        shape = MaterialTheme.shapes.large,
        modifier = modifier.fillMaxWidth(),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp),
        ) {
            IconButton(onClick = onPreviousPeriod) {
                Icon(
                    imageVector = Icons.Outlined.ChevronLeft,
                    contentDescription = "Previous period",
                )
            }

            TextButton(
                onClick = onOpenCalendar,
                modifier = Modifier.weight(1f),
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = periodTitle(selectedRange, period),
                        style = MaterialTheme.typography.titleMedium,
                        textAlign = TextAlign.Center,
                    )
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Icon(
                            imageVector = Icons.Outlined.CalendarMonth,
                            contentDescription = null,
                        )
                        Text(
                            text = periodSubtitle(selectedRange, period),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            textAlign = TextAlign.Center,
                        )
                    }
                }
            }

            IconButton(
                onClick = onNextPeriod,
                enabled = canGoForward,
            ) {
                Icon(
                    imageVector = Icons.Outlined.ChevronRight,
                    contentDescription = "Next period",
                )
            }
        }
    }
}
