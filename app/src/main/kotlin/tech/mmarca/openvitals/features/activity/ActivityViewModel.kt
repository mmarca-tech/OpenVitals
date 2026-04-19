package tech.mmarca.openvitals.features.activity

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import tech.mmarca.openvitals.data.model.ActivityProgressPoint
import tech.mmarca.openvitals.data.model.DailyNutrition
import tech.mmarca.openvitals.data.model.DailySteps
import tech.mmarca.openvitals.data.model.TimeRange
import tech.mmarca.openvitals.data.repository.ActivityRepository
import tech.mmarca.openvitals.ui.components.periodFor
import java.time.LocalDate
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ActivityUiState(
    val isLoading: Boolean = true,
    val selectedRange: TimeRange = TimeRange.WEEK,
    val selectedDate: LocalDate = LocalDate.now(),
    val dailySteps: List<DailySteps> = emptyList(),
    val nutrition: List<DailyNutrition> = emptyList(),
    val activityProgress: List<ActivityProgressPoint> = emptyList(),
    val error: String? = null,
)

class ActivityViewModel(private val repository: ActivityRepository) : ViewModel() {

    private val _uiState = MutableStateFlow(ActivityUiState())
    val uiState: StateFlow<ActivityUiState> = _uiState.asStateFlow()

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
        val today = LocalDate.now()
        if (!periodFor(_uiState.value.selectedRange, nextDate).end.isAfter(today)) {
            _uiState.value = _uiState.value.copy(selectedDate = nextDate)
            load()
        }
    }

    fun selectDate(date: LocalDate) {
        _uiState.value = _uiState.value.copy(
            selectedDate = date.coerceAtMost(LocalDate.now()),
        )
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
                    val stepsDeferred = async { repository.loadDailySteps(period.start, period.end) }
                    val nutritionDeferred = async { repository.loadDailyNutrition(period.start, period.end) }
                    val progressDeferred = async {
                        if (range == TimeRange.DAY) repository.loadActivityProgress(period.start) else emptyList()
                    }
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        selectedDate = date,
                        dailySteps = stepsDeferred.await(),
                        nutrition = nutritionDeferred.await(),
                        activityProgress = progressDeferred.await(),
                    )
                }
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

