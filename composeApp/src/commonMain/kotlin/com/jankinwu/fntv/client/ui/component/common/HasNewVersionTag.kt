package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.unit.dp
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.icons.UpdateNoBorder
import com.jankinwu.fntv.client.ui.component.common.dialog.UpdateDialog
import com.jankinwu.fntv.client.viewmodel.UpdateViewModel
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.Icon
import io.github.composefluent.component.Text
import org.koin.compose.viewmodel.koinViewModel

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun HasNewVersionTag(modifier: Modifier = Modifier) {
    val updateViewModel: UpdateViewModel = koinViewModel()
    val latestVersion by updateViewModel.latestVersion.collectAsState()
    val updateStatus by updateViewModel.status.collectAsState()
    var showUpdateDialog by remember { mutableStateOf(false) }
    var isHovered by remember { mutableStateOf(false) }
    UpdateDialog(
        status = updateStatus,
        showDialog = showUpdateDialog,
        onDownload = { info, force -> updateViewModel.downloadUpdate(info, force) },
        onInstall = { info -> updateViewModel.installUpdate(info) },
        onSkip = { info ->
            updateViewModel.skipVersion(info.version)
            showUpdateDialog = false
        },
        onCancelDownload = {
            updateViewModel.cancelDownload()
            showUpdateDialog = false
        },
        onDeleteAndDismiss = { info ->
            updateViewModel.deleteUpdate(info)
            showUpdateDialog = false
        },
        onBackground = {
            showUpdateDialog = false
        },
        onDismiss = {
            showUpdateDialog = false
        }
    )

    if (latestVersion != null) {
        Row(
            modifier = modifier
                .padding(start = 8.dp)
                .pointerHoverIcon(PointerIcon.Hand)
                .clickable (
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                ){
                    updateViewModel.checkUpdate()
                    showUpdateDialog = true
                }
                .onPointerEvent(PointerEventType.Enter) { isHovered = true }
                .onPointerEvent(PointerEventType.Exit) { isHovered = false }
                .border(1.dp, Colors.AccentColorDefault, RoundedCornerShape(50))
                .background(if (isHovered) FluentTheme.colors.stroke.control.default else Color.Transparent, RoundedCornerShape(50))
                .padding(horizontal = 4.dp, vertical = 1.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                UpdateNoBorder,
                "版本升级", modifier = Modifier.size(10.dp),
                tint = Colors.AccentColorDefault
            )
            Text(
                text = "NEW",
                style = FluentTheme.typography.caption,
                color = Colors.AccentColorDefault,
                modifier = Modifier
                    .padding(start = 2.dp)
            )
        }
    }
}