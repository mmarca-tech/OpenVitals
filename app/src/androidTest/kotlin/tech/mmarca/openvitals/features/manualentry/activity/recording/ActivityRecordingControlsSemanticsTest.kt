package tech.mmarca.openvitals.features.manualentry.activity.recording

import androidx.compose.ui.test.assertHasClickAction
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import org.junit.Rule
import org.junit.Test
import tech.mmarca.openvitals.R
import tech.mmarca.openvitals.testing.string
import tech.mmarca.openvitals.ui.theme.OpenVitalsTheme

/**
 * Recording primary controls must stay labelled buttons, not anonymous chrome.
 * TalkBack users pause/finish through these labels.
 */
class ActivityRecordingControlsSemanticsTest {

    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun pausedControlsAnnounceResumeAndFinish() {
        composeRule.setContent {
            OpenVitalsTheme {
                TimedRecordingControls(
                    state = ActivityRecordingState(status = ActivityRecordingStatus.PAUSED),
                    onPauseRecording = {},
                    onResumeRecording = {},
                    onEnterFocusMode = {},
                    onFinishRecording = {},
                )
            }
        }

        composeRule.onNodeWithText(string(R.string.action_resume))
            .assertIsDisplayed()
            .assertHasClickAction()
        composeRule.onNodeWithText(string(R.string.action_finish))
            .assertIsDisplayed()
            .assertHasClickAction()
    }
}
