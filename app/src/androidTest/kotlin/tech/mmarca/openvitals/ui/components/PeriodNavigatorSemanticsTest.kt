package tech.mmarca.openvitals.ui.components

import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import java.time.LocalDate
import org.junit.Rule
import org.junit.Test
import tech.mmarca.openvitals.R
import tech.mmarca.openvitals.core.period.DatePeriod
import tech.mmarca.openvitals.core.period.TimeRange
import tech.mmarca.openvitals.testing.string
import tech.mmarca.openvitals.ui.theme.OpenVitalsTheme

/**
 * Pins the period navigator's TalkBack labels. The chevrons and calendar are
 * icon-only; if their content descriptions rot, previous/next and the picker
 * become anonymous buttons.
 */
class PeriodNavigatorSemanticsTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun previousNextAndCalendarAnnounceThemselves() {
        val period = DatePeriod(LocalDate.of(2026, 6, 16), LocalDate.of(2026, 6, 22))
        composeRule.setContent {
            OpenVitalsTheme {
                PeriodNavigator(
                    selectedRange = TimeRange.WEEK,
                    period = period,
                    canGoForward = true,
                    onPreviousPeriod = {},
                    onNextPeriod = {},
                    onOpenCalendar = {},
                )
            }
        }

        composeRule.onNodeWithContentDescription(string(R.string.cd_previous_period))
            .assertIsDisplayed()
            .assertHasClickAction()
        composeRule.onNodeWithContentDescription(string(R.string.cd_next_period))
            .assertIsDisplayed()
            .assertHasClickAction()
        composeRule.onNodeWithContentDescription(string(R.string.cd_open_calendar))
            .assertIsDisplayed()
            .assertHasClickAction()
    }
}
