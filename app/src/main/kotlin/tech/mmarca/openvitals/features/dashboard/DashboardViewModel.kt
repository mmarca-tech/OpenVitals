package tech.mmarca.openvitals.features.dashboard

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import tech.mmarca.openvitals.data.model.DashboardData
import tech.mmarca.openvitals.data.repository.HealthRepository
import java.time.LocalDate
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class DashboardUiState(
    val selectedDate: LocalDate = LocalDate.now(),
    val data: DashboardData? = null,
    val isLoading: Boolean = true,
    val errorMessage: String? = null,
)

class DashboardViewModel(private val repository: HealthRepository) : ViewModel() {

    private val _uiState = MutableStateFlow(DashboardUiState())
    val uiState: StateFlow<DashboardUiState> = _uiState.asStateFlow()

    init {
        load(_uiState.value.selectedDate)
    }

    fun refresh() {
        load(_uiState.value.selectedDate)
    }

    fun load(date: LocalDate) {
        val clampedDate = date.coerceAtMost(LocalDate.now())
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(
                selectedDate = clampedDate,
                isLoading = true,
                errorMessage = null,
            )
            runCatching { repository.loadDashboard(clampedDate) }
                .onSuccess { data ->
                    _uiState.value = _uiState.value.copy(
                        data = data,
                        isLoading = false,
                    )
                }
                .onFailure { error ->
                    _uiState.value = _uiState.value.copy(
                        isLoading = false,
                        errorMessage = error.message ?: "Unknown error",
                    )
                }
        }
    }

    fun previousDay() {
        load(_uiState.value.selectedDate.minusDays(1))
    }

    fun nextDay() {
        val today = LocalDate.now()
        val next = _uiState.value.selectedDate.plusDays(1)
        if (!next.isAfter(today)) {
            load(next)
        }
    }

    fun selectDate(date: LocalDate) {
        load(date)
    }
}
