package com.jankinwu.fntv.client.ui.component.detail

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.hoverable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsHoveredAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.model.response.SubtitleStream
import com.jankinwu.fntv.client.icons.ArrowUp
import com.jankinwu.fntv.client.icons.Delete
import com.jankinwu.fntv.client.ui.component.common.AddSubtitleFlyout
import com.jankinwu.fntv.client.ui.component.common.EmptyFolder
import com.jankinwu.fntv.client.ui.component.common.dialog.AddNasSubtitleDialog
import com.jankinwu.fntv.client.ui.component.common.dialog.CustomContentDialog
import com.jankinwu.fntv.client.ui.component.common.dialog.SubtitleSearchDialog
import com.jankinwu.fntv.client.ui.flyoutTitleItemColors
import com.jankinwu.fntv.client.ui.providable.LocalFileInfo
import com.jankinwu.fntv.client.ui.providable.LocalTypography
import com.jankinwu.fntv.client.utils.FileUtil
import com.jankinwu.fntv.client.viewmodel.StreamListViewModel
import com.jankinwu.fntv.client.viewmodel.SubtitleDeleteViewModel
import com.jankinwu.fntv.client.viewmodel.SubtitleMarkViewModel
import com.jankinwu.fntv.client.viewmodel.SubtitleUploadViewModel
import com.jankinwu.fntv.client.viewmodel.UiState
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.ContentDialogButton
import io.github.composefluent.component.DialogSize
import io.github.composefluent.component.FlyoutContainerScope
import io.github.composefluent.component.FlyoutPlacement
import io.github.composefluent.component.Icon
import io.github.composefluent.component.MenuFlyoutContainer
import io.github.composefluent.component.MenuFlyoutItem
import io.github.composefluent.component.ScrollbarContainer
import io.github.composefluent.component.rememberScrollbarAdapter
import io.github.composefluent.icons.Icons
import io.github.composefluent.icons.regular.Checkmark
import io.github.vinceglb.filekit.PlatformFile
import io.github.vinceglb.filekit.name
import io.github.vinceglb.filekit.readBytes
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun StreamSelector(
    streamOptions: List<StreamOptionItem>,
    selectedItemLabel: String,
    onSelected: (String) -> Unit,
    isSubtitle: Boolean = false,
    mediaGuid: String = "",
    guid: String = "",
    selectedIndex: Int = 0,
    trimIdList: List<String> = emptyList(),
) {
    val lazyListState = rememberScrollState(0)
    var showDeleteDialog by remember { mutableStateOf(false) }
    var showAddNasSubtitleDialog by remember { mutableStateOf(false) }
    var showSearchSubtitleDialog by remember { mutableStateOf(false) }
    var deletedItemTitle by remember { mutableStateOf("") }
    var deletedItemGuid by remember { mutableStateOf("") }
    val subtitleDeleteViewModel: SubtitleDeleteViewModel = koinViewModel()
    val subtitleUploadViewModel: SubtitleUploadViewModel = koinViewModel()
    val subtitleDeleteState by subtitleDeleteViewModel.uiState.collectAsState()
    val subtitleUploadState by subtitleUploadViewModel.uiState.collectAsState()
    val subtitleMarkViewModel: SubtitleMarkViewModel = koinViewModel()
    val streamListViewModel: StreamListViewModel = koinViewModel()
    val density = LocalDensity.current
    val fileInfo = LocalFileInfo.current
    val scope = rememberCoroutineScope()
    LaunchedEffect(subtitleDeleteState, subtitleUploadState) {
        // 当字幕上传成功后，刷新stream列表
        if (isSubtitle) {
            if (subtitleDeleteState is UiState.Success) {
                streamListViewModel.loadData(guid)
                subtitleDeleteViewModel.clearError()
            }
            if (subtitleUploadState is UiState.Success) {
                streamListViewModel.loadData(guid)
                subtitleUploadViewModel.clearError()
            }
        }
    }

    if (isSubtitle || streamOptions.isNotEmpty() && streamOptions.size > 1) {
        val interactionSource = remember { MutableInteractionSource() }
        val isHovered by interactionSource.collectIsHoveredAsState()
        var flyoutHeight by remember(streamOptions) {
            mutableStateOf(
                if (isSubtitle && streamOptions.size > 6) {
                    317.dp
                } else if (isSubtitle && streamOptions.size > 1) {
                    57.dp * (streamOptions.size - 1) + 32.dp
                } else if (isSubtitle && streamOptions.size == 1) {
                    317.dp
                } else {
                    57.dp * streamOptions.size
                }
            )
        }
        MenuFlyoutContainer(
            flyout = {
                // 检查是否有 "_no_display_" 选项
                val noDisplayItem = streamOptions.find { it.optionGuid == "_no_display_" }
                val otherItems = streamOptions.filter { it.optionGuid != "_no_display_" }
                if (isSubtitle) {
                    MenuFlyoutItem(
                        text = {
                            Row(
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "字幕",
                                    color = FluentTheme.colors.text.text.primary,
                                    fontWeight = FontWeight.Normal,
                                    fontSize = 16.sp,
                                    modifier = Modifier
                                        .width(120.dp)
                                )
                                // 添加 "字幕" 下拉框
                                AddSubtitleFlyout(
                                    mediaGuid,
                                    modifier = Modifier.hoverable(interactionSource),
                                    onAddNasSubtitleSelected = {
                                        showAddNasSubtitleDialog = true
                                    },
                                    onSearchSubtitleSelected = {
                                        showSearchSubtitleDialog = true
                                    },
                                    onAddLocalSubtitleSelected = {
                                        scope.launch {
                                            try {
                                                val file: PlatformFile? = withContext(Dispatchers.IO) {
                                                    FileUtil.pickFile(
                                                        listOf("ass", "srt", "vtt", "sub", "ssa"),
                                                        "选择字幕文件"
                                                    )
                                                }
                                                if (file != null) {
                                                    val byteArray = withContext(Dispatchers.IO) {
                                                        file.readBytes()
                                                    }
                                                    subtitleUploadViewModel.uploadSubtitle(
                                                        mediaGuid,
                                                        byteArray,
                                                        file.name
                                                    )
                                                }
                                            } catch (e: Exception) {
                                                e.printStackTrace()
                                            }
                                        }
                                    }
                                )
                            }
                        },
                        onClick = {},
                        modifier = Modifier
                            .width(240.dp)
                            .padding(bottom = 4.dp, top = 6.dp)
                            .hoverable(interactionSource),
                        colors = flyoutTitleItemColors()
                    )
                }
                ScrollbarContainer(
                    adapter = rememberScrollbarAdapter(lazyListState),
                    modifier = Modifier
                        .height(flyoutHeight)
//                        .heightIn(max = 310.dp)
                ) {
                    Column(
                        modifier = Modifier
//                            .height(310.dp)
                            .width(240.dp)
                            .verticalScroll(lazyListState)
                    ) {
                        LaunchedEffect(Unit) {
                            delay(100)
                            val itemHeightPx = with(density) { 57.dp.toPx() }
                            val titleHeightPx = with(density) { 36.dp.toPx() }
                            val targetPosition = if (isSubtitle) {
                                (((selectedIndex - 1) * itemHeightPx) + titleHeightPx).toInt()
                            } else {
                                (selectedIndex * itemHeightPx).toInt()
                            }
                            lazyListState.scrollTo(targetPosition)
                        }
                        // 如果有 "_no_display_" 选项，则先显示它
                        if (otherItems.isNotEmpty()) {
                            noDisplayItem?.let { streamOptionItem ->
                                MenuFlyoutItem(
                                    text = {
                                        NoDisplayRow(
                                            modifier = Modifier.hoverable(interactionSource),
                                            title = streamOptionItem.title,
                                            isDefault = streamOptionItem.isDefault,
                                            isSelected = streamOptionItem.isSelected,
                                        )
                                    },
                                    onClick = {
                                        onSelected(streamOptionItem.optionGuid)
                                        isFlyoutVisible = false
                                    },
                                    modifier = Modifier
                                        .width(240.dp)
                                        .hoverable(interactionSource)
                                )
                            }
                        } else if (noDisplayItem != null) {
                            EmptyFolder(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .hoverable(interactionSource),
                                "无内容"
                            )
                        }
                        // 显示其他项目
                        otherItems.forEach { streamOptionItem ->
                            MenuFlyoutItem(
                                text = {
                                    StreamSelectorRow(
                                        modifier = Modifier.hoverable(interactionSource),
                                        title = streamOptionItem.title,
                                        isDefault = streamOptionItem.isDefault,
                                        isSelected = streamOptionItem.isSelected,
                                        isExternal = streamOptionItem.isExternal,
                                        subtitle1 = streamOptionItem.subtitle1,
                                        subtitle2 = streamOptionItem.subtitle2,
                                        subtitle3 = streamOptionItem.subtitle3,
                                        guid = streamOptionItem.optionGuid,
                                        onDelete = {
                                            deletedItemTitle = streamOptionItem.title
                                            deletedItemGuid = streamOptionItem.optionGuid
                                            showDeleteDialog = true
                                        },
                                    )
                                },
                                onClick = {
                                    onSelected(streamOptionItem.optionGuid)
                                    isFlyoutVisible = false
                                },
                                modifier = Modifier
                                    .width(240.dp)
                                    .hoverable(interactionSource)
                            )

                        }
                    }
                }
            },
            content = {
                StreamSelectorLabel(
                    modifier = Modifier.hoverable(interactionSource),
                    selectedLabel = selectedItemLabel,
                    isHovered = isHovered,
                    onFlyoutVisibilityChange = { isVisible -> isFlyoutVisible = isVisible }
                )
            },
//            placement = FlyoutPlacement.BottomAlignedStart,
            placement = FlyoutPlacement.Auto,
            modifier = Modifier
        )
    } else {
        Text(
            text = selectedItemLabel,
            color = FluentTheme.colors.text.text.secondary,
            fontSize = 14.sp
        )
    }
    CustomContentDialog(
        title = "删除外挂字幕",
        visible = showDeleteDialog,
        size = DialogSize.Standard,
        primaryButtonText = "删除",
        secondaryButtonText = "取消",
        onButtonClick = { contentDialogButton ->
            when (contentDialogButton) {
                ContentDialogButton.Secondary -> {
                }

                ContentDialogButton.Primary -> {
                    // 删除外挂字幕
                    subtitleDeleteViewModel.deleteSubtitle(deletedItemGuid)
                    streamListViewModel.loadData(guid)
                }

                ContentDialogButton.Close -> {}
            }
            showDeleteDialog = false
        },
        isWarning = true,
        content = {
            Text(
                "确定要删除 $deletedItemTitle 外挂字幕吗？",
                style = LocalTypography.current.body,
                color = FluentTheme.colors.text.text.primary
            )
        }
    )
    AddNasSubtitleDialog(
        title = "添加 NAS 字幕文件",
        visible = showAddNasSubtitleDialog,
        size = DialogSize.Max,
        primaryButtonText = "选择",
        secondaryButtonText = "取消",
        onButtonClick = { contentDialogButton, selectedPaths ->
            when (contentDialogButton) {
                ContentDialogButton.Primary -> {
                    // 添加 NAS 字幕
                    selectedPaths?.let {
                        subtitleMarkViewModel.markSubtitles(mediaGuid, selectedPaths.toList())
                    }
                }

                ContentDialogButton.Secondary -> {

                }

                ContentDialogButton.Close -> {}
            }
            showAddNasSubtitleDialog = false
        }
    )
    SubtitleSearchDialog(
        title = "添加字幕",
        visible = showSearchSubtitleDialog,
        size = DialogSize.Max,
        mediaGuid,
        trimIdList,
        mediaFileName = fileInfo?.fileName ?: "",
        onDismissRequest = { showSearchSubtitleDialog = false },
        onSubtitleDownloadSuccess = {
            streamListViewModel.loadData(guid)
        }
    )
}

@Composable
fun FlyoutContainerScope.StreamSelectorRow(
    modifier: Modifier = Modifier,
    title: String,
    isDefault: Boolean,
    isSelected: Boolean,
    isExternal: Boolean = false,
    subtitle1: String = "",
    subtitle2: String = "",
    subtitle3: String = "",
    guid: String,
    onDelete: () -> Unit
) {
    val interactionSource = remember { MutableInteractionSource() }
    val isItemHovered by interactionSource.collectIsHoveredAsState()
//    var showDeleteDialog by remember { mutableStateOf(false) }
//    val subtitleDeleteViewModel: SubtitleDeleteViewModel = koinViewModel()
    Row(
        horizontalArrangement = Arrangement.Start,
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp)
            .hoverable(interactionSource)
            .pointerHoverIcon(PointerIcon.Hand)
    ) {
        Column(
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.weight(5f)
        ) {
            Text(
                text = title + if (isDefault) " - 默认" else "",
                color = if (isSelected) Colors.AccentColorDefault else FluentTheme.colors.text.text.primary,
                fontWeight = FontWeight.Normal,
                fontSize = 15.sp,
                modifier = Modifier
                    .width(120.dp)
            )
            Text(
                text = "$subtitle1 $subtitle2  $subtitle3",
                color = if (isSelected) Colors.AccentColorDefault else FluentTheme.colors.text.text.secondary,
                fontWeight = FontWeight.Normal,
                fontSize = 12.sp,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier
//                                            .width(170.dp)
            )
        }
        if (isExternal && isItemHovered) {
            val iconInteractionSource = remember { MutableInteractionSource() }
            val isIconHovered by iconInteractionSource.collectIsHoveredAsState()
            Box(
                modifier = Modifier
                    .hoverable(iconInteractionSource)
                    .size(28.dp)
                    .clickable(
                        interactionSource = interactionSource,
                        indication = null,
                        onClick = {
                            onDelete()
//                            showDeleteDialog = true
                            isFlyoutVisible = false
                        }
                    ),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .hoverable(iconInteractionSource)
//                        .align(Alignment.Center)
                        .background(
                            color = if (isIconHovered) FluentTheme.colors.stroke.control.default else Color.Transparent,
                            shape = CircleShape
                        )
                )

                Icon(
                    imageVector = Delete,
                    contentDescription = "删除字幕",
                    tint = FluentTheme.colors.text.text.secondary,
                    modifier = Modifier
//                        .weight(1f)
                        .size(14.dp)
                )
            }
//            if (showDeleteDialog) {
//                CustomConfirmDialog(
//                    onDismissRequest = { showDeleteDialog = false },
//                    title = "确认删除",
//                    contentText = "确定要删除此外挂字幕吗？此操作不可撤销。",
//                    confirmButtonText = "删除",
//                    onConfirmClick = {
//                        subtitleDeleteViewModel.deleteSubtitle(guid)
//                    }
//                )
//            }
        } else if (isSelected) {
            Icon(
                imageVector = Icons.Regular.Checkmark,
                contentDescription = "已选择",
                tint = Colors.AccentColorDefault,
                modifier = Modifier
                    .weight(1f)
                    .size(18.dp)
            )
        }
    }
}

@Composable
fun NoDisplayRow(
    modifier: Modifier = Modifier,
    title: String,
    isDefault: Boolean,
    isSelected: Boolean,
) {
    Row(
        horizontalArrangement = Arrangement.Start,
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 8.dp)
//            .hoverable(interactionSource)
            .pointerHoverIcon(PointerIcon.Hand)
    ) {
        Column(
            verticalArrangement = Arrangement.Center,
            modifier = Modifier.weight(5f)
        ) {
            Text(
                text = title + if (isDefault) " - 默认" else "",
                color = if (isSelected) Colors.AccentColorDefault else FluentTheme.colors.text.text.primary,
                fontWeight = FontWeight.Normal,
                fontSize = 15.sp,
                modifier = Modifier
                    .width(120.dp)
            )
        }
        if (isSelected) {
            Icon(
                imageVector = Icons.Regular.Checkmark,
                contentDescription = "",
                tint = Colors.AccentColorDefault,
                modifier = Modifier
                    .weight(1f)
                    .size(18.dp)
            )
        }
    }
}


@Composable
fun StreamSelectorLabel(
    selectedLabel: String,
    isHovered: Boolean,
    modifier: Modifier = Modifier,
    onFlyoutVisibilityChange: (Boolean) -> Unit
) {
    val targetRotation = if (isHovered) -180f else 0f
    val animatedRotation by animateFloatAsState(targetValue = targetRotation)

    LaunchedEffect(isHovered) {
        if (isHovered) {
            onFlyoutVisibilityChange(true)
        } else {
            delay(200)
            onFlyoutVisibilityChange(false)
        }
    }

    val interactionSource = remember { MutableInteractionSource() }

    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp),
        modifier = modifier
    ) {
        Text(
            text = selectedLabel,
            color = FluentTheme.colors.text.text.secondary,
            fontSize = 14.sp
        )
        Icon(
            imageVector = ArrowUp,
            contentDescription = "下拉框箭头",
            tint = FluentTheme.colors.text.text.tertiary,
            modifier = Modifier
                .size(16.dp)
                .rotate(animatedRotation)
        )
    }
}

data class StreamOptionItem(
    val optionGuid: String,
    val title: String,
    val subtitle1: String = "",
    val subtitle2: String = "",
    val subtitle3: String = "",
    val isDefault: Boolean = false,
    val isSelected: Boolean = false,
    val isExternal: Boolean = false
)

val noDisplayStream = SubtitleStream(
    mediaGuid = "",
    title = "",
    guid = "_no_display_",
    codecName = "",
    codecType = "",
    language = "关闭",
    forced = 0,
    index = 0,
    isDefault = 0,
    isExternal = 0,
    format = "",
    trimId = "",
    sourceId = "",
    source = "",
    createTime = 0,
    updateTime = 0,
    extraFile = 0,
    isBitmap = 0,
    fileSize = 0
)