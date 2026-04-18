package dev.manu.hcdashboard.features.browse

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.manu.hcdashboard.data.model.ExerciseData
import dev.manu.hcdashboard.data.model.SleepData
import dev.manu.hcdashboard.data.model.TimeRange
import dev.manu.hcdashboard.data.model.WeightEntry
import dev.manu.hcdashboard.data.repository.HealthRepository
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
    val workouts: List<ExerciseData> = emptyList(),
    val sleepSessions: List<SleepData> = emptyList(),
    val weightEntries: List<WeightEntry> = emptyList(),
    val error: String? = null,
)

class BrowseViewModel(private val repository: HealthRepository) : ViewModel() {

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
        _uiState.value = _uiState.value.copy(selectedRange = range)
        load()
    }

    fun load() {
        viewModelScope.launch {
            val category = _uiState.value.selectedCategory
            val range = _uiState.value.selectedRange
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)
            runCatching {
                when (category) {
                    BrowseCategory.WORKOUTS -> {
                        val workouts = repository.loadWorkouts(range)
                        _uiState.value = _uiState.value.copy(isLoading = false, workouts = workouts)
                    }
                    BrowseCategory.SLEEP -> {
                        val sessions = repository.loadSleepSessions(range)
                        _uiState.value = _uiState.value.copy(isLoading = false, sleepSessions = sessions)
                    }
                    BrowseCategory.WEIGHT -> {
                        val entries = repository.loadWeightEntries(range)
                        _uiState.value = _uiState.value.copy(isLoading = false, weightEntries = entries)
                    }
                }
            }.onFailure {
                _uiState.value = _uiState.value.copy(isLoading = false, error = it.message)
            }
        }
    }
}
