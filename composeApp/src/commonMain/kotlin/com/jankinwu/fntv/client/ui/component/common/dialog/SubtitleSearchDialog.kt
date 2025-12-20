package com.jankinwu.fntv.client.ui.component.common.dialog

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.hoverable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsHoveredAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Arrangement.spacedBy
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.ui.providable.LocalStore
import com.jankinwu.fntv.client.ui.providable.LocalTypography
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.convertor.convertToSubtitleItemList
import com.jankinwu.fntv.client.icons.Download
import com.jankinwu.fntv.client.ui.component.common.AnimatedScrollbarLazyColumn
import com.jankinwu.fntv.client.ui.component.common.EmptyFolder
import com.jankinwu.fntv.client.ui.component.common.FlyoutButton
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingProgressRing
import com.jankinwu.fntv.client.ui.component.common.ToastType
import com.jankinwu.fntv.client.ui.providable.LocalToastManager
import com.jankinwu.fntv.client.viewmodel.SubtitleDownloadViewModel
import com.jankinwu.fntv.client.viewmodel.SubtitleSearchViewModel
import com.jankinwu.fntv.client.viewmodel.UiState
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.DialogSize
import io.github.composefluent.component.FluentDialog
import io.github.composefluent.component.FlyoutPlacement
import io.github.composefluent.component.Icon
import io.github.composefluent.component.MenuFlyoutContainer
import io.github.composefluent.component.MenuFlyoutItem
import io.github.composefluent.component.ProgressRing
import io.github.composefluent.component.ProgressRingSize
import io.github.composefluent.component.Text
import io.github.composefluent.icons.Icons
import io.github.composefluent.icons.regular.Checkmark
import io.github.composefluent.icons.regular.Dismiss
import org.koin.compose.viewmodel.koinViewModel

@Composable
fun SubtitleSearchDialog(
    title: String,
    visible: Boolean,
    size: DialogSize = DialogSize.Max,
    mediaGuid: String,
    trimIdList: List<String>,
    mediaFileName: String,
    onDismissRequest: () -> Unit = {},
    onSubtitleDownloadSuccess: (String) -> Unit = {},
    onSubtitleDownloadFailed: (String) -> Unit = {_ ->}
) {
    var language by remember(visible) { mutableStateOf("zh-CN") }
    val subtitleSearchViewModel: SubtitleSearchViewModel = koinViewModel()
    val subtitleSearchState by subtitleSearchViewModel.uiState.collectAsState()
    LaunchedEffect(language, mediaGuid, visible) {
        if (mediaGuid.isNotBlank() && visible) {
            subtitleSearchViewModel.searchSubtitles(language, mediaGuid)
        }
    }

    FluentDialog(visible, size) {
        Column {
            Column(
                Modifier
                    .fillMaxWidth()
                    .heightIn(max = 500.dp)
//                    .background(FluentTheme.colors.background.layer.alt)
                    .padding(24.dp),
                verticalArrangement = spacedBy(16.dp)
            ) {
                Row(
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth().padding(bottom = 16.dp)
                ) {
                    Text(
                        style = FluentTheme.typography.subtitle,
                        fontSize = 16.sp,
                        text = title,
                    )
                    Icon(
                        imageVector = Icons.Regular.Dismiss,
                        contentDescription = "",
                        tint = FluentTheme.colors.text.text.primary,
                        modifier = Modifier
                            .clickable(
                                onClick = {
                                    onDismissRequest()
                                }
                            )
                            .size(24.dp)
                            .pointerHoverIcon(PointerIcon.Hand)
                    )
                }
                Row(
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                ) {
                    Text(
                        style = LocalTypography.current.subtitle,
                        text = mediaFileName,
                        modifier = Modifier.weight(1f)
                    )
                    LanguageSwitchFlyout(onLanguageSelected = { language = it })
                }
                Text(
                    style = LocalTypography.current.body,
                    text = "按相关度排序：",
                    modifier = Modifier
                )
                when (subtitleSearchState) {
                    is UiState.Loading -> {
                        ImgLoadingProgressRing()
                    }

                    is UiState.Success -> {
                        val subtitleSearchResponse =
                            (subtitleSearchState as UiState.Success).data
                        val subtitleItemList =
                            convertToSubtitleItemList(subtitleSearchResponse.subtitles)
                        SubtitleResultList(subtitleItemList, mediaGuid, trimIdList, onSubtitleDownloadSuccess, onSubtitleDownloadFailed)
                    }

                    else -> {}
                }
            }
        }
    }
}

@Composable
private fun LanguageSwitchFlyout(
    onLanguageSelected: (String) -> Unit,
) {
    var buttonName by remember { mutableStateOf("中文") }
    val store = LocalStore.current
    MenuFlyoutContainer(
        flyout = {
            languageList.forEach { language ->
                MenuFlyoutItem(
                    text = {
                        Row(
                            horizontalArrangement = Arrangement.SpaceBetween,
                            modifier = Modifier
                                .fillMaxWidth()
                        ) {
                            Text(
                                text = language.name,
                                color = FluentTheme.colors.text.text.secondary,
                                fontWeight = FontWeight.Normal,
                                fontSize = 14.sp,
                                modifier = Modifier
                                    .width(120.dp)
                            )
                        }
                    },
                    onClick = {
                        isFlyoutVisible = false
                        buttonName = language.buttonName
                        onLanguageSelected(language.code)
                    },
                    modifier = Modifier
                        .background(if (store.darkMode) Colors.BackgroundColorDark else Colors.BackgroundColorLight)
                        .pointerHoverIcon(PointerIcon.Hand)
                )
            }
        },
        content = {
            FlyoutButton(
                isSelected = isFlyoutVisible,
                onClick = {
                    isFlyoutVisible = !isFlyoutVisible
                },
                buttonText = buttonName,
                modifier = Modifier
                    .pointerHoverIcon(PointerIcon.Hand),
                horizontalPadding = 14.dp,
                verticalPadding = 8.dp
            )
        },
        placement = FlyoutPlacement.BottomAlignedEnd,
        modifier = Modifier
    )
}

@Composable
fun SubtitleResultList(results: List<SubtitleItemData>,
                       mediaGuid: String,
                       trimIdList: List<String>,
                       onSubtitleDownloadSuccess: (String) -> Unit = {},
                       onSubtitleDownloadFailed: (String) -> Unit = {_ ->}
) {
    val subtitleDownloadViewModel: SubtitleDownloadViewModel = koinViewModel()
    val subtitleDownloadState by subtitleDownloadViewModel.uiState.collectAsState()
    // 创建一个可变Map，用于存储每个trimId对应的下载状态, 初始值为0, 下载中为1, 下载完成为2
    val downloadStatusMap = remember(mediaGuid) { mutableStateMapOf<String, Int>() }
    val listState = rememberLazyListState()
    val toastManager = LocalToastManager.current

    LaunchedEffect(subtitleDownloadState) {
        if (subtitleDownloadState is UiState.Success) {
            val subtitleDownloadResponse =
                (subtitleDownloadState as UiState.Success).data
            downloadStatusMap[subtitleDownloadResponse.trimId] = 2
            toastManager.showToast("下载成功")
            onSubtitleDownloadSuccess(subtitleDownloadResponse.trimId)
            subtitleDownloadViewModel.clearError()
        } else if (subtitleDownloadState is UiState.Error) {
            val subtitleDownloadError =
                (subtitleDownloadState as UiState.Error).message
            val operationId: String? = (subtitleDownloadState as UiState.Error).operationId
            downloadStatusMap[operationId as String] = 0
            toastManager.showToast(subtitleDownloadError, ToastType.Failed)
            onSubtitleDownloadFailed(subtitleDownloadError)
            subtitleDownloadViewModel.clearError()
        }
    }

    LaunchedEffect(trimIdList) {
        for (trimId in trimIdList) {
            downloadStatusMap[trimId] = 2
        }
    }
    if (results.isNotEmpty()) {
        AnimatedScrollbarLazyColumn(listState = listState, modifier = Modifier.fillMaxSize(), scrollbarOffsetX = 10.dp) {
            items(results, key = { item -> item.trimId }) { item ->
                val downloadStatus = downloadStatusMap[item.trimId] ?: 0
                SubtitleListItem(item, downloadStatus) { trimId ->
                    subtitleDownloadViewModel.downloadSubtitle(mediaGuid, trimId)
                    downloadStatusMap[trimId] = 1
                }
            }
        }
    } else {
        EmptyFolder(modifier = Modifier.fillMaxSize(), "未搜索到相关字幕")
    }
}

// --- 组件：单行字幕项 ---
@Composable
fun SubtitleListItem(
    item: SubtitleItemData,
    downloadStatus: Int = 0,
    onDownload: (String) -> Unit = {}
) {
    Column(modifier = Modifier.fillMaxWidth().padding(vertical = 8.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = item.fileName,
                color = FluentTheme.colors.text.text.primary,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier.weight(1f).padding(end = 8.dp)
            )

            Text(
                text = "下载量: ${item.download}",
                color = FluentTheme.colors.text.text.secondary,
                fontSize = 12.sp
            )
        }

        Spacer(modifier = Modifier.height(8.dp))
        val interactionSource = remember { MutableInteractionSource() }
        val isHovered by interactionSource.collectIsHoveredAsState()
        val backgroundColor by animateColorAsState(
            targetValue = if (isHovered || downloadStatus == 2) FluentTheme.colors.stroke.control.default else Color.Transparent
        )

        Row(
            modifier = Modifier
                .clip(CircleShape)
                .border(1.dp, Color.Gray.copy(alpha = 0.4f), CircleShape)
                .background(backgroundColor)
                .clickable(
                    interactionSource = interactionSource,
                    indication = null,
                    onClick = {
                        if (downloadStatus != 2) {
                            onDownload(item.trimId)
                        }
                    }
                )
                .hoverable(interactionSource)
                .pointerHoverIcon(PointerIcon.Hand)
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = spacedBy(4.dp, Alignment.CenterHorizontally)
        ) {
            when (downloadStatus) {
                0 -> Icon(
                    imageVector = Download,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                    tint = FluentTheme.colors.text.text.secondary
                )

                1 -> ProgressRing(
                    size = ProgressRingSize.Small,
                    color = FluentTheme.colors.text.text.tertiary
                )

                2 -> Icon(
                    imageVector = Icons.Regular.Checkmark,
                    contentDescription = null,
                    modifier = Modifier.size(16.dp),
                    tint = FluentTheme.colors.text.text.secondary
                )
            }
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = if (downloadStatus == 2) "下载完成" else "下载字幕",
                fontSize = 12.sp,
                color = FluentTheme.colors.text.text.secondary
            )
        }
        Spacer(modifier = Modifier.height(8.dp))
    }
}


private data class Language(
    val name: String,
    val code: String,
    val buttonName: String
)

private val languageList = listOf(
    Language("简体中文", "zh-CN", "中文"),
    Language("英文", "en", "英文")
)

data class SubtitleItemData(
    val fileName: String,
    val download: Int,
    val trimId: String,
)

