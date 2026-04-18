package dev.manu.hcdashboard.features.onboarding

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import dev.manu.hcdashboard.data.model.HealthConnectAvailability
import dev.manu.hcdashboard.data.repository.HealthRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class OnboardingUiState(
    val availability: HealthConnectAvailability = HealthConnectAvailability.AVAILABLE,
    val phase1Granted: Boolean = false,
    val phase2Granted: Boolean = false,
    val isCheckingPermissions: Boolean = true,
)

class OnboardingViewModel(private val repository: HealthRepository) : ViewModel() {
    companion object {
        private const val TAG = "OnboardingViewModel"
    }

    private val _uiState = MutableStateFlow(OnboardingUiState())
    val uiState: StateFlow<OnboardingUiState> = _uiState.asStateFlow()

    val phase1Permissions get() = repository.phase1Permissions
    val phase2Permissions get() = repository.phase2Permissions

    init {
        checkState()
    }

    fun checkState() {
        viewModelScope.launch {
            val avail = repository.availability()
            Log.d(TAG, "checkState availability=$avail")
            if (avail != HealthConnectAvailability.AVAILABLE) {
                _uiState.value = OnboardingUiState(
                    availability = avail,
                    isCheckingPermissions = false,
                )
                return@launch
            }
            val granted = repository.grantedPermissions()
            Log.d(TAG, "checkState granted=${granted.sorted()}")
            _uiState.value = OnboardingUiState(
                availability = avail,
                phase1Granted = repository.phase1Permissions.all { it in granted },
                phase2Granted = repository.phase2Permissions.all { it in granted },
                isCheckingPermissions = false,
            )
        }
    }

    fun onPermissionsResult(granted: Set<String>) {
        viewModelScope.launch {
            Log.d(TAG, "onPermissionsResult callbackGranted=${granted.sorted()}")
            val allGranted = repository.grantedPermissions()
            Log.d(TAG, "onPermissionsResult allGranted=${allGranted.sorted()}")
            _uiState.value = _uiState.value.copy(
                phase1Granted = repository.phase1Permissions.all { it in allGranted },
                phase2Granted = repository.phase2Permissions.all { it in allGranted },
            )
        }
    }
}
