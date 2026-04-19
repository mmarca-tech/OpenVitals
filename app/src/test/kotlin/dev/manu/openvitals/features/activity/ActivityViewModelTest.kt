package dev.manu.openvitals.features.activity

import dev.manu.openvitals.data.model.ActivityProgressPoint
import dev.manu.openvitals.data.model.DailyNutrition
import dev.manu.openvitals.data.model.DailySteps
import dev.manu.openvitals.data.model.TimeRange
import dev.manu.openvitals.data.repository.ActivityRepository
import dev.manu.openvitals.util.MainDispatcherRule
import io.mockk.coEvery
import io.mockk.coVerify
import io.mockk.mockk
import java.time.LocalDate
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test

class ActivityViewModelTest {

    @get:Rule
    val mainDispatcherRule = MainDispatcherRule()

    private val today = LocalDate.now()
    private val pastAnchor = today.minusWeeks(4) // safely in the past for all ranges

    private fun emptyRepo() = mockk<ActivityRepository>().also { repo ->
        coEvery { repo.loadDailySteps(any(), any()) } returns emptyList()
        coEvery { repo.loadDailyNutrition(any(), any()) } returns emptyList()
        coEvery { repo.loadActivityProgress(any()) } returns emptyList()
    }

    // ─── Initial state ────────────────────────────────────────────────────────

    @Test fun `initial range is WEEK`() = runTest {
        val vm = ActivityViewModel(emptyRepo())
        assertEquals(TimeRange.WEEK, vm.uiState.value.selectedRange)
    }

    @Test fun `initial load clears loading and sets empty lists`() = runTest {
        val vm = ActivityViewModel(emptyRepo())
        val state = vm.uiState.value
        assertFalse(state.isLoading)
        assertTrue(state.dailySteps.isEmpty())
        assertTrue(state.nutrition.isEmpty())
    }

    // ─── Load success / failure ───────────────────────────────────────────────

    @Test fun `load success populates data`() = runTest {
        val steps = listOf(DailySteps(today, 8_000L, 6_000.0))
        val repo = emptyRepo()
        coEvery { repo.loadDailySteps(any(), any()) } returns steps

        val vm = ActivityViewModel(repo)

        assertEquals(steps, vm.uiState.value.dailySteps)
        assertFalse(vm.uiState.value.isLoading)
        assertNull(vm.uiState.value.error)
    }

    @Test fun `load failure sets error and clears loading`() = runTest {
        val repo = mockk<ActivityRepository>()
        coEvery { repo.loadDailySteps(any(), any()) } throws RuntimeException("timeout")
        coEvery { repo.loadDailyNutrition(any(), any()) } returns emptyList()
        coEvery { repo.loadActivityProgress(any()) } returns emptyList()

        val vm = ActivityViewModel(repo)

        assertFalse(vm.uiState.value.isLoading)
        assertEquals("timeout", vm.uiState.value.error)
    }

    // ─── selectRange ──────────────────────────────────────────────────────────

    @Test fun `selectRange updates selectedRange`() = runTest {
        val vm = ActivityViewModel(emptyRepo())
        vm.selectRange(TimeRange.MONTH)
        assertEquals(TimeRange.MONTH, vm.uiState.value.selectedRange)
    }

    @Test fun `selectRange triggers reload`() = runTest {
        val repo = emptyRepo()
        val vm = ActivityViewModel(repo)
        vm.selectRange(TimeRange.MONTH)
        // init load + selectRange load = 2 calls to loadDailySteps
        coVerify(atLeast = 2) { repo.loadDailySteps(any(), any()) }
    }

    // ─── previousPeriod ───────────────────────────────────────────────────────

    @Test fun `previousPeriod DAY moves back one day`() = runTest {
        val vm = ActivityViewModel(emptyRepo())
        vm.selectRange(TimeRange.DAY)
        val before = vm.uiState.value.selectedDate
        vm.previousPeriod()
        assertEquals(before.minusDays(1), vm.uiState.value.selectedDate)
    }

    @Test fun `previousPeriod WEEK moves back one week`() = runTest {
        val vm = ActivityViewModel(emptyRepo())
        val before = vm.uiState.value.selectedDate
        vm.previousPeriod()
        assertEquals(before.minusWeeks(1), vm.uiState.value.selectedDate)
    }

    @Test fun `previousPeriod MONTH moves back one month`() = runTest {
        val vm = ActivityViewModel(emptyRepo())
        vm.selectRange(TimeRange.MONTH)
        val before = vm.uiState.value.selectedDate
        vm.previousPeriod()
        assertEquals(before.minusMonths(1), vm.uiState.value.selectedDate)
    }

    @Test fun `previousPeriod YEAR moves back one year`() = runTest {
        val vm = ActivityViewModel(emptyRepo())
        vm.selectRange(TimeRange.YEAR)
        val before = vm.uiState.value.selectedDate
        vm.previousPeriod()
        assertEquals(before.minusYears(1), vm.uiState.value.selectedDate)
    }

    // ─── nextPeriod ───────────────────────────────────────────────────────────

    @Test fun `nextPeriod DAY is blocked when selectedDate is today`() = runTest {
        val repo = emptyRepo()
        val vm = ActivityViewModel(repo)
        vm.selectRange(TimeRange.DAY)
        // selectedDate should be today after init
        val before = vm.uiState.value.selectedDate

        vm.nextPeriod()

        assertEquals(before, vm.uiState.value.selectedDate)
    }

    @Test fun `nextPeriod DAY advances when selectedDate is in the past`() = runTest {
        val repo = emptyRepo()
        val vm = ActivityViewModel(repo)
        vm.selectRange(TimeRange.DAY)
        vm.selectDate(today.minusDays(2))
        val before = vm.uiState.value.selectedDate

        vm.nextPeriod()

        assertEquals(before.plusDays(1), vm.uiState.value.selectedDate)
    }

    @Test fun `nextPeriod WEEK advances from a past week`() = runTest {
        val repo = emptyRepo()
        val vm = ActivityViewModel(repo)
        vm.selectDate(pastAnchor)
        val before = vm.uiState.value.selectedDate

        vm.nextPeriod()

        assertEquals(before.plusWeeks(1), vm.uiState.value.selectedDate)
    }

    // ─── selectDate ───────────────────────────────────────────────────────────

    @Test fun `selectDate clamps future date to today`() = runTest {
        val vm = ActivityViewModel(emptyRepo())
        vm.selectDate(today.plusDays(10))
        assertEquals(today, vm.uiState.value.selectedDate)
    }

    @Test fun `selectDate accepts past date unchanged`() = runTest {
        val vm = ActivityViewModel(emptyRepo())
        vm.selectDate(pastAnchor)
        assertEquals(pastAnchor, vm.uiState.value.selectedDate)
    }

    // ─── DAY range loads activityProgress ────────────────────────────────────

    @Test fun `load for DAY range calls loadActivityProgress`() = runTest {
        val progress = listOf(ActivityProgressPoint(java.time.Instant.now(), 500L, null, null))
        val repo = emptyRepo()
        coEvery { repo.loadActivityProgress(any()) } returns progress

        val vm = ActivityViewModel(repo)
        vm.selectRange(TimeRange.DAY)

        assertEquals(progress, vm.uiState.value.activityProgress)
    }

    @Test fun `load for WEEK range returns empty activityProgress`() = runTest {
        val vm = ActivityViewModel(emptyRepo())
        // WEEK is the default range
        assertTrue(vm.uiState.value.activityProgress.isEmpty())
        coVerify(exactly = 0) { emptyRepo().loadActivityProgress(any()) }
    }
}
