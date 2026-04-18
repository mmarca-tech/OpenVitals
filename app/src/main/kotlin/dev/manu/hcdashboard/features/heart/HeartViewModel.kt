package dev.manu.hcdashboard.features.heart

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.manu.hcdashboard.data.model.DailyHrv
import dev.manu.hcdashboard.data.model.DailyRestingHR
import dev.manu.hcdashboard.data.model.HeartRateSample
import dev.manu.hcdashboard.data.model.HeartRateSummary
import dev.manu.hcdashboard.data.model.TimeRange
import dev.manu.hcdashboard.data.repository.HealthRepository
import dev.manu.hcdashboard.ui.components.periodFor
import java.time.LocalDate
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class HeartUiState(
    val isLoading: Boolean = true,
    val selectedRange: TimeRange = TimeRange.WEEK,
    val selectedDate: LocalDate = LocalDate.now(),
    val daySamples: List<HeartRateSample> = emptyList(),
    val dailySummaries: List<HeartRateSummary> = emptyList(),
    val dayRestingBpm: Long? = null,
    val dayHrvMs: Double? = null,
    val dailyRestingHR: List<DailyRestingHR> = emptyList(),
    val dailyHrv: List<DailyHrv> = emptyList(),
    val error: String? = null,
)

class HeartViewModel(private val repository: HealthRepository) : ViewModel() {

    private val _uiState = MutableStateFlow(HeartUiState())
    val uiState: StateFlow<HeartUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun selectRange(range: TimeRange) {
        _uiState.value = _uiState.value.copy(
            selectedRange = range,
            selectedDate = _uiState.value.selectedDate.coerceAtMost(LocalDate.now()),
        )
        load()
    }

    fun previousPeriod() {
        _uiState.value = _uiState.value.copy(
            selectedDate = when (_uiState.value.selectedRange) {
                TimeRange.DAY -> _uiState.value.selectedDate.minusDays(1)
                TimeRange.WEEK -> _uiState.value.selectedDate.minusWeeks(1)
                TimeRange.MONTH -> _uiState.value.selectedDate.minusMonths(1)
                TimeRange.YEAR -> _uiState.value.selectedDate.minusYears(1)
            },
        )
        load()
    }

    fun nextPeriod() {
        val nextDate = when (_uiState.value.selectedRange) {
            TimeRange.DAY -> _uiState.value.selectedDate.plusDays(1)
            TimeRange.WEEK -> _uiState.value.selectedDate.plusWeeks(1)
            TimeRange.MONTH -> _uiState.value.selectedDate.plusMonths(1)
            TimeRange.YEAR -> _uiState.value.selectedDate.plusYears(1)
        }
        if (!periodFor(_uiState.value.selectedRange, nextDate).end.isAfter(LocalDate.now())) {
            _uiState.value = _uiState.value.copy(selectedDate = nextDate)
            load()
        }
    }

    fun selectDate(date: LocalDate) {
        _uiState.value = _uiState.value.copy(selectedDate = date.coerceAtMost(LocalDate.now()))
        load()
    }

    fun load() {
        viewModelScope.launch {
            val range = _uiState.value.selectedRange
            val date = _uiState.value.selectedDate.coerceAtMost(LocalDate.now())
            val period = periodFor(range, date)
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            runCatching {
                coroutineScope {
                    if (range == TimeRange.DAY) {
                        val samples = async { repository.loadHeartRateSamples(date) }
                        val restingBpm = async { repository.loadRestingHeartRate(date) }
                        val hrvMs = async { repository.loadHrvRmssd(date) }
                        HeartLoadResult(
                            daySamples = samples.await(),
                            dailySummaries = emptyList(),
                            dayRestingBpm = restingBpm.await(),
                            dayHrvMs = hrvMs.await(),
                            dailyRestingHR = emptyList(),
                            dailyHrv = emptyList(),
                        )
                    } else {
                        val summaries = async { repository.loadDailyHeartRateSummaries(period.start, period.end) }
                        val restingHR = async { repository.loadDailyRestingHR(period.start, period.end) }
                        val hrv = async { repository.loadDailyHRV(period.start, period.end) }
                        HeartLoadResult(
                            daySamples = emptyList(),
                            dailySummaries = summaries.await(),
                            dayRestingBpm = null,
                            dayHrvMs = null,
                            dailyRestingHR = restingHR.await(),
                            dailyHrv = hrv.await(),
                        )
                    }
                }
            }.onSuccess { result ->
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    selectedDate = date,
                    daySamples = result.daySamples,
                    dailySummaries = result.dailySummaries,
                    dayRestingBpm = result.dayRestingBpm,
                    dayHrvMs = result.dayHrvMs,
                    dailyRestingHR = result.dailyRestingHR,
                    dailyHrv = result.dailyHrv,
                )
            }.onFailure {
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    selectedDate = date,
                    error = it.message,
                )
            }
        }
    }
}

private data class HeartLoadResult(
    val daySamples: List<HeartRateSample>,
    val dailySummaries: List<HeartRateSummary>,
    val dayRestingBpm: Long?,
    val dayHrvMs: Double?,
    val dailyRestingHR: List<DailyRestingHR>,
    val dailyHrv: List<DailyHrv>,
)

