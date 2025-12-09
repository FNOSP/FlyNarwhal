package com.jankinwu.fntv.client.ui.component.common.dialog

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.ui.providable.LocalTypography
import com.jankinwu.fntv.client.data.convertor.FnDataConvertor
import com.jankinwu.fntv.client.data.model.response.MediaItemResponse
import com.jankinwu.fntv.client.ui.LargeDialogSize
import com.jankinwu.fntv.client.ui.component.common.AnimatedScrollbarLazyColumn
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingProgressRing
import com.jankinwu.fntv.client.ui.customAccentButtonColors
import com.jankinwu.fntv.client.ui.customSelectedCheckBoxColors
import com.jankinwu.fntv.client.ui.providable.LocalToastManager
import com.jankinwu.fntv.client.ui.providable.LocalUserInfo
import com.jankinwu.fntv.client.ui.screen.MediaQualityTag
import com.jankinwu.fntv.client.viewmodel.MediaItemFileViewModel
import com.jankinwu.fntv.client.viewmodel.ScrapViewModel
import com.jankinwu.fntv.client.viewmodel.UiState
import io.github.composefluent.FluentTheme
import io.github.composefluent.LocalContentColor
import io.github.composefluent.LocalTextStyle
import io.github.composefluent.component.AccentButton
import io.github.composefluent.component.Button
import io.github.composefluent.component.CheckBox
import io.github.composefluent.component.CheckBoxDefaults
import io.github.composefluent.component.ContentDialogButton
import io.github.composefluent.component.DialogSize
import io.github.composefluent.component.FluentDialog
import io.github.composefluent.component.Icon
import io.github.composefluent.component.Text
import io.github.composefluent.icons.Icons
import io.github.composefluent.icons.regular.Dismiss
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun VersionManagementDialog(
    visible: Boolean,
    guid: String,
    itemTitle: String,
    onDismiss: () -> Unit,
    onDelete: (guid: String, mediaGuids: List<String>) -> Unit,
    onUnmatchConfirmed: (guid: String, mediaGuids: List<String>) -> Unit,
    onMatchToOther: (guid: String, mediaGuids: List<String>) -> Unit,
    size: DialogSize = LargeDialogSize
) {
    val mediaItemFileViewModel: MediaItemFileViewModel = koinViewModel()
    val scrapViewModel: ScrapViewModel = koinViewModel()
    val scrapState by scrapViewModel.uiState.collectAsState()
    val itemUiState by mediaItemFileViewModel.uiState.collectAsState()
    var selectedMediaGuids by remember { mutableStateOf(setOf<String>()) }
    var showConfirmDialog by remember { mutableStateOf(false) }
    val toastManager = LocalToastManager.current

    LaunchedEffect(visible, guid) {
        if (visible) mediaItemFileViewModel.loadData(guid)
    }

    LaunchedEffect(scrapState) {
        when (scrapState) {
            is UiState.Success -> {
                toastManager.showToast("解除匹配成功")
                onDismiss()
            }
            is UiState.Error -> {
                toastManager.showToast("解除匹配失败：" + (scrapState as UiState.Error).message, false)
            }
            else -> {}
        }
    }

    FluentDialog(visible, size) {
        Column {
            Column(
                Modifier
                    .fillMaxWidth()
                    .heightIn(min = 400.dp, max = 600.dp)
                    .padding(top = 24.dp, bottom = 8.dp, start = 25.dp, end = 25.dp)
            ) {
//                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
//                    Column(Modifier.weight(1f)) {
                        Row(
                            Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(style = FluentTheme.typography.subtitle, text = "管理版本")
                            Icon(
                                imageVector = Icons.Regular.Dismiss,
                                contentDescription = "",
                                tint = FluentTheme.colors.text.text.primary,
                                modifier = Modifier
                                    .clickable(
                                        onClick = {
                                            onDismiss()
                                        }
                                    )
                                    .size(24.dp)
                                    .pointerHoverIcon(PointerIcon.Hand)
                            )
                        }
                        Spacer(Modifier.height(24.dp))
                        Row(
                            Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween
                        ) {
                            Text(
                                style = LocalTypography.current.bodyStrong,
                                fontSize = 18.sp,
                                text = "《$itemTitle》",
                                color = FluentTheme.colors.text.text.secondary
                            )
                            val count = when (itemUiState) {
                                is UiState.Success -> (itemUiState as UiState.Success<List<MediaItemResponse>>).data.size
                                else -> 0
                            }
                            Text(
                                text = "共 $count 个版本",
                                style = FluentTheme.typography.body,
                                color = FluentTheme.colors.text.text.secondary
                            )
                        }
//                    }
//                }
                Spacer(Modifier.height(8.dp))
                CompositionLocalProvider(
                    LocalTextStyle provides FluentTheme.typography.body,
                    LocalContentColor provides FluentTheme.colors.text.text.primary
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                    ) {
                        when (itemUiState) {
                            is UiState.Success -> {
                                val list =
                                    (itemUiState as UiState.Success<List<MediaItemResponse>>).data
                                val listState = rememberLazyListState()
                                AnimatedScrollbarLazyColumn(listState = listState, modifier = Modifier.fillMaxSize()) {
                                    itemsIndexed(list, key = { _, item -> item.mediaGuid }) { index, item ->
                                        VersionItemRow(
                                            index = index,
                                            item = item,
                                            checked = selectedMediaGuids.contains(item.mediaGuid),
                                            onCheckedChange = { checked ->
                                                selectedMediaGuids =
                                                    if (checked) selectedMediaGuids + item.mediaGuid else selectedMediaGuids - item.mediaGuid
                                            }
                                        )
                                    }
                                }
                            }

                            is UiState.Loading -> {
                                ImgLoadingProgressRing()
                            }

                            is UiState.Error -> {
                                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Text((itemUiState as UiState.Error).message)
                                    Button(onClick = { mediaItemFileViewModel.refresh(guid) }) {
                                        Text(
                                            "重试"
                                        )
                                    }
                                }
                            }

                            else -> {}
                        }
                    }
                }
            }
            Box(
                Modifier
                    .height(50.dp)
                    .padding(horizontal = 25.dp, vertical = 8.dp),
                Alignment.CenterEnd
            ) {
                Row(
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Button(
                        modifier = Modifier.pointerHoverIcon(PointerIcon.Hand),
                        onClick = { onDelete(guid, selectedMediaGuids.toList()) },
                        disabled = selectedMediaGuids.isEmpty()
                    ) { Text("删除",
                        style = LocalTypography.current.bodyStrong,
                        color = FluentTheme.colors.text.text.primary) }
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Button(
                            modifier = Modifier.pointerHoverIcon(PointerIcon.Hand),
                            onClick = { showConfirmDialog = true },
                            disabled = selectedMediaGuids.isEmpty()
                        ) { Text("解除与当前影片的匹配",
                            style = LocalTypography.current.bodyStrong,
                            color = FluentTheme.colors.text.text.primary) }
                        AccentButton(
                            modifier = Modifier.pointerHoverIcon(PointerIcon.Hand),
                            onClick = { onMatchToOther(guid, selectedMediaGuids.toList()) },
                            disabled = selectedMediaGuids.isEmpty(),
                            buttonColors = customAccentButtonColors()
                        ) { Text(
                            "匹配为其他影片",
                            style = LocalTypography.current.bodyStrong,
                            color = Color.White
                        ) }
                    }
                }
            }
        }
    }

    if (showConfirmDialog) {
        CustomContentDialog(
            title = "解除影片匹配",
            visible = true,
            size = DialogSize.Standard,
            primaryButtonText = "确认解除",
            secondaryButtonText = "取消",
            onButtonClick = { contentDialogButton ->
                when (contentDialogButton) {
                    ContentDialogButton.Secondary -> {
                        showConfirmDialog = false
                    }

                    ContentDialogButton.Primary -> {
                        onUnmatchConfirmed(guid, selectedMediaGuids.toList())
                        scrapViewModel.scrap(guid, selectedMediaGuids.toList())
                        showConfirmDialog = false
                        onDismiss()
                    }

                    ContentDialogButton.Close -> {}
                }
            },
            content = {
                androidx.compose.material3.Text(
                    "是否解除与当前影片的匹配",
                    style = LocalTypography.current.body,
                    color = FluentTheme.colors.text.text.primary
                )
            }
        )
    }
}

@Composable
private fun VersionItemRow(
    index: Int,
    item: MediaItemResponse,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    val currentUserInfo = LocalUserInfo.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 8.dp)
            .background(FluentTheme.colors.stroke.control.default, RoundedCornerShape(8.dp))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .requiredSize(24.dp)
                .background(Color.Transparent, RoundedCornerShape(12.dp)),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "${index + 1}",
                fontSize = 14.sp,
                color = FluentTheme.colors.text.text.secondary
            )
        }
        Column(Modifier.weight(1f).padding(start = 8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = item.filename,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            Spacer(Modifier.height(4.dp))
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = FnDataConvertor.formatSecondsToCNDateTime(item.duration),
                    fontSize = 12.sp,
                    color = FluentTheme.colors.text.text.secondary
                )
                Text(
                    text = "添加于 ${FnDataConvertor.formatTimestampToDateTime(item.createTime)}",
                    fontSize = 12.sp,
                    color = FluentTheme.colors.text.text.secondary
                )
                item.mediaStream?.resolutions?.forEach { res ->
                    MediaQualityTag(res, 0.92f)
                }
                item.mediaStream?.colorRangeType?.forEach { tag ->
                    MediaQualityTag(tag, 0.92f)
                }
                item.mediaStream?.audioType?.forEach { tag ->
                    MediaQualityTag(tag, 0.92f)
                }
            }
            Spacer(Modifier.height(6.dp))
            Text(
                text = "位置: ${FnDataConvertor.humanizedFilePath(item.filePath, currentUserInfo.userSources)}",
                fontSize = 12.sp,
                color = FluentTheme.colors.text.text.secondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }
        CheckBox(
            label = null,
            checked = checked,
            onCheckStateChange = onCheckedChange,
            colors = if (checked) {
                customSelectedCheckBoxColors()
            } else {
                CheckBoxDefaults.defaultCheckBoxColors()
            },
            modifier = Modifier
                .pointerHoverIcon(PointerIcon.Hand)
                .size(15.dp)
        )
    }
}
