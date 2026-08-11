package tech.mmarca.openvitals.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SwipeToDismissBox
import androidx.compose.material3.SwipeToDismissBoxValue
import androidx.compose.material3.rememberSwipeToDismissBoxState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.CustomAccessibilityAction
import androidx.compose.ui.semantics.customActions
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import tech.mmarca.openvitals.R

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SwipeToDeleteEntryRow(
    onDelete: () -> Unit,
    modifier: Modifier = Modifier,
    shape: Shape = CardDefaults.shape,
    content: @Composable () -> Unit,
) {
    val dismissState = rememberSwipeToDismissBoxState()
    val currentOnDelete by rememberUpdatedState(onDelete)
    val deleteLabel = stringResource(R.string.cd_delete_entry)
    val dismissAction = remember {
        { value: SwipeToDismissBoxValue ->
            if (value == SwipeToDismissBoxValue.EndToStart) {
                currentOnDelete()
            }
        }
    }
    // Swipe is fine for sighted users; TalkBack and switch access need an
    // explicit action — the gesture alone never appears in the semantics tree.
    val deleteSemantics = Modifier.semantics {
        customActions = listOf(
            CustomAccessibilityAction(deleteLabel) {
                currentOnDelete()
                true
            },
        )
    }

    SwipeToDismissBox(
        state = dismissState,
        enableDismissFromStartToEnd = false,
        onDismiss = dismissAction,
        backgroundContent = {
            // Painted only while the row is actually displaced. The
            // background is composed at rest too, and any row whose content
            // is not fully opaque let the delete red bleed straight through.
            if (dismissState.dismissDirection == SwipeToDismissBoxValue.EndToStart) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .clip(shape)
                        .background(MaterialTheme.colorScheme.errorContainer, shape)
                        .padding(horizontal = 24.dp),
                    contentAlignment = Alignment.CenterEnd,
                ) {
                    Icon(
                        imageVector = Icons.Outlined.Delete,
                        contentDescription = deleteLabel,
                        tint = MaterialTheme.colorScheme.onErrorContainer,
                    )
                }
            }
        },
        modifier = modifier
            .clip(shape)
            .then(deleteSemantics),
        content = { content() },
    )
}
