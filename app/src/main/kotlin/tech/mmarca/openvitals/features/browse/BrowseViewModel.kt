package tech.mmarca.openvitals.features.browse

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import tech.mmarca.openvitals.data.model.ExerciseData
import tech.mmarca.openvitals.data.model.SleepData
import tech.mmarca.openvitals.data.model.TimeRange
import tech.mmarca.openvitals.data.model.WeightEntry
import tech.mmarca.openvitals.data.repository.ActivityRepository
import tech.mmarca.openvitals.data.repository.BodyRepository
import tech.mmarca.openvitals.data.repository.SleepRepository
import tech.mmarca.openvitals.ui.components.periodFor
import java.time.LocalDate
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

enum class BrowseCategory(val label: String) {
    WORKOUTS("Workouts"),
    SLEEP("Sleep"),
    WEIGHT("Weight"),
}

data class BrowseUiState(
    val isLoading: Boolean = false,
    val selectedCategory: BrowseCategory = BrowseCategory.WORKOUTS,
    val selectedRange: TimeRange = TimeRange.MONTH,
    val selectedDate: LocalDate = LocalDate.now(),
    val workouts: List<ExerciseData> = emptyList(),
    val sleepSessions: List<SleepData> = emptyList(),
    val weightEntries: List<WeightEntry> = emptyList(),
    val error: String? = null,
)

class BrowseViewModel(
    private val activityRepository: ActivityRepository,
    private val sleepRepository: SleepRepository,
    private val bodyRepository: BodyRepository,
) : ViewModel() {

    private val _uiState = MutableStateFlow(BrowseUiState())
    val uiState: StateFlow<BrowseUiState> = _uiState.asStateFlow()

    init {
        load()
    }

    fun selectCategory(category: BrowseCategory) {
        _uiState.value = _uiState.value.copy(selectedCategory = category)
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
            val category = _uiState.value.selectedCategory
            val range = _uiState.value.selectedRange
            val date = _uiState.value.selectedDate.coerceAtMost(LocalDate.now())
            val period = periodFor(range, date)
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            runCatching {
                when (category) {
                    BrowseCategory.WORKOUTS -> {
                        val workouts = activityRepository.loadWorkouts(period.start, period.end)
                        _uiState.value = _uiState.value.copy(isLoading = false, selectedDate = date, workouts = workouts)
                    }
                    BrowseCategory.SLEEP -> {
                        val sessions = sleepRepository.loadSleepSessions(period.start, period.end)
                        _uiState.value = _uiState.value.copy(isLoading = false, selectedDate = date, sleepSessions = sessions)
                    }
                    BrowseCategory.WEIGHT -> {
                        val entries = bodyRepository.loadWeightEntries(period.start, period.end)
                        _uiState.value = _uiState.value.copy(isLoading = false, selectedDate = date, weightEntries = entries)
                    }
                }
            }.onFailure {
                _uiState.value = _uiState.value.copy(isLoading = false, selectedDate = date, error = it.message)
            }
        }
    }
}
