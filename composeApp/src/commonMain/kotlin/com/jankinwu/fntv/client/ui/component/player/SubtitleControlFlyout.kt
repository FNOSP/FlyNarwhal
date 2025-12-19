package com.jankinwu.fntv.client.ui.component.player

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material.icons.filled.Computer
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupProperties
import com.jankinwu.fntv.client.data.convertor.FnDataConvertor
import com.jankinwu.fntv.client.data.model.PlayingInfoCache
import com.jankinwu.fntv.client.data.model.response.SubtitleStream
import com.jankinwu.fntv.client.icons.Subtitle
import com.jankinwu.fntv.client.ui.component.common.AnimatedScrollbarLazyColumn
import com.jankinwu.fntv.client.ui.providable.IsoTagData
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

import com.jankinwu.fntv.client.icons.Delete

private val FlyoutBackgroundColor = Color.Black.copy(alpha = 0.9f)
private val FlyoutBorderColor = Color.Gray.copy(alpha = 0.5f)
private val SelectedTextColor = Color(0xFF2073DF)
private val HoverBackgroundColor = Color.White.copy(alpha = 0.1f)
private val DefaultTextColor = Color.White.copy(alpha = 0.7843f)
private val MenuWidth = 320.dp
private val FlyoutShape = RoundedCornerShape(8.dp)
private const val HIDE_DELAY_MS = 200L
private const val ANIMATION_DURATION_MS = 200

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun SubtitleControlFlyout(
    playingInfoCache: PlayingInfoCache?,
    isoTagData: IsoTagData?,
    onSubtitleSelected: (SubtitleStream?) -> Unit,
    onOpenSubtitleSearch: () -> Unit,
    onOpenAddNasSubtitle: () -> Unit,
    onOpenAddLocalSubtitle: () -> Unit,
    modifier: Modifier = Modifier,
    onHoverStateChanged: ((Boolean) -> Unit)? = null,
    onRequestDelete: ((SubtitleStream) -> Unit)? = null
) {
    var isExpanded by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()
    var hideJob by remember { mutableStateOf<Job?>(null) }
    var isButtonHovered by remember { mutableStateOf(false) }
    var popupHovered by remember { mutableStateOf(false) }
    var isAddMenuHovered by remember { mutableStateOf(false) }
    var showPopup by remember { mutableStateOf(false) }
    var isAddMenuExpanded by remember { mutableStateOf(false) }

    fun showFlyout() {
        hideJob?.cancel()
        isExpanded = true
        showPopup = true
        isAddMenuHovered = false
        popupHovered = false
        onHoverStateChanged?.invoke(true)
    }

    fun hideFlyoutWithDelay() {
        hideJob = coroutineScope.launch {
            delay(HIDE_DELAY_MS)
            if (!isButtonHovered && !popupHovered && !isAddMenuHovered) {
                isExpanded = false
                isAddMenuExpanded = false
                onHoverStateChanged?.invoke(false)
                delay(ANIMATION_DURATION_MS.toLong())
                showPopup = false
            }
        }
    }

    Box(
        modifier = modifier
            .pointerHoverIcon(PointerIcon.Hand)
            .onPointerEvent(PointerEventType.Enter) {
                isButtonHovered = true
                showFlyout()
            }
            .onPointerEvent(PointerEventType.Exit) {
                isButtonHovered = false
                hideFlyoutWithDelay()
            },
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = Subtitle,
            contentDescription = "字幕",
            tint = Color.White,
            modifier = Modifier.size(24.dp)
        )

        if (showPopup) {
            Popup(
                offset = IntOffset(0, -70),
                alignment = Alignment.BottomCenter,
                properties = PopupProperties(
                    clippingEnabled = false,
                    focusable = false
                ),
                onDismissRequest = {
                    if (!isButtonHovered && !popupHovered && !isAddMenuHovered) {
                        isExpanded = false
                        onHoverStateChanged?.invoke(false)
                    }
                }
            ) {
                Box(
                    modifier = Modifier
                        .pointerHoverIcon(PointerIcon.Hand)
                        .onPointerEvent(PointerEventType.Enter) {
                            popupHovered = true
                            hideJob?.cancel()
                        }
                        .onPointerEvent(PointerEventType.Exit) {
                            popupHovered = false
                            hideFlyoutWithDelay()
                        }
                ) {
                    FlyoutWithAnimation(
                        isExpanded = isExpanded,
                        onAnimationFinished = {
                            if (!isExpanded) {
                                showPopup = false
                            }
                        }
                    ) {
                        SubtitleFlyoutContent(
                            playingInfoCache = playingInfoCache,
                            isoTagData = isoTagData,
                            isAddMenuExpanded = isAddMenuExpanded,
                            onAddMenuExpandedChanged = { isAddMenuExpanded = it },
                            onSubtitleSelected = {
                                onSubtitleSelected(it)
                                isExpanded = false
                                if (!isButtonHovered) {
                                    onHoverStateChanged?.invoke(false)
                                }
                            },
                            onOpenSubtitleSearch = {
                                onOpenSubtitleSearch()
                                isExpanded = false
                                if (!isButtonHovered) {
                                    onHoverStateChanged?.invoke(false)
                                }
                            },
                            onOpenAddNasSubtitle = {
                                onOpenAddNasSubtitle()
                                isExpanded = false
                                if (!isButtonHovered) {
                                    onHoverStateChanged?.invoke(false)
                                }
                            },
                            onOpenAddLocalSubtitle = {
                                onOpenAddLocalSubtitle()
                                isExpanded = false
                                if (!isButtonHovered) {
                                    onHoverStateChanged?.invoke(false)
                                }
                            },
                            onAddMenuHoverChanged = { isHovered ->
                                isAddMenuHovered = isHovered
                                if (isHovered) {
                                    hideJob?.cancel()
                                } else {
                                    hideFlyoutWithDelay()
                                }
                            },
                            onRequestDelete = { subtitle ->
                                onRequestDelete?.invoke(subtitle)
                                isExpanded = false
                                if (!isButtonHovered) {
                                    onHoverStateChanged?.invoke(false)
                                }
                            },
                            isExpanded = isExpanded
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun FlyoutWithAnimation(
    isExpanded: Boolean,
    onAnimationFinished: () -> Unit,
    content: @Composable () -> Unit
) {
    val alpha = remember { Animatable(0f) }
    val scale = remember { Animatable(0.4f) }
    val offsetY = remember { Animatable(0f) }

    LaunchedEffect(isExpanded) {
        if (isExpanded) {
            launch { alpha.animateTo(1f, tween(ANIMATION_DURATION_MS)) }
            launch { scale.animateTo(1f, tween(ANIMATION_DURATION_MS)) }
            launch { offsetY.animateTo(0f, tween(ANIMATION_DURATION_MS)) }
        } else {
            launch { alpha.animateTo(0f, tween(ANIMATION_DURATION_MS)) }
            launch { scale.animateTo(0.4f, tween(ANIMATION_DURATION_MS)) }
            launch { offsetY.animateTo(10f, tween(ANIMATION_DURATION_MS)) }
            delay(ANIMATION_DURATION_MS.toLong())
            onAnimationFinished()
        }
    }

    Box(
        modifier = Modifier
            .alpha(alpha.value)
            .graphicsLayer {
                scaleX = scale.value
                scaleY = scale.value
                transformOrigin = TransformOrigin(0.5f, 1f)
            }
            .padding(bottom = offsetY.value.dp)
    ) {
        content()
    }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun SubtitleFlyoutContent(
    playingInfoCache: PlayingInfoCache?,
    isoTagData: IsoTagData?,
    isAddMenuExpanded: Boolean,
    onAddMenuExpandedChanged: (Boolean) -> Unit,
    onSubtitleSelected: (SubtitleStream?) -> Unit,
    onOpenSubtitleSearch: () -> Unit,
    onOpenAddNasSubtitle: () -> Unit,
    onOpenAddLocalSubtitle: () -> Unit,
    onAddMenuHoverChanged: (Boolean) -> Unit,
    onRequestDelete: (SubtitleStream) -> Unit,
    isExpanded: Boolean = false
) {
    val currentSubtitle = playingInfoCache?.currentSubtitleStream
    val subtitleList = playingInfoCache?.currentSubtitleStreamList ?: emptyList()

    Surface(
        shape = FlyoutShape,
        color = FlyoutBackgroundColor,
        border = BorderStroke(1.dp, FlyoutBorderColor),
        modifier = Modifier.width(MenuWidth)
    ) {
        var addSubtitleButtonHovered by remember { mutableStateOf(false) }
        Column(modifier = Modifier.padding(start = 8.dp, top = 16.dp, bottom = 16.dp, end = 8.dp)) {
            // Header
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 4.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "字幕",
                    color = Color.White,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold
                )

                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    // Adjustment Button (Placeholder)
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(16.dp))
                            .background(Color.Transparent)
                            .border(1.dp, Color.White.copy(alpha = 0.5f), RoundedCornerShape(16.dp))
                            .clickable { /* TODO */ }
                            .padding(horizontal = 12.dp, vertical = 6.dp)
                    ) {
                        Text("调整", color = DefaultTextColor, fontSize = 12.sp)
                    }

                    // Add Button with Dropdown
                    Box {
                        Row(
                            modifier = Modifier
                                .clip(RoundedCornerShape(16.dp))
                                .background(if (addSubtitleButtonHovered) HoverBackgroundColor else Color.Transparent)
                                .border(1.dp, Color.White.copy(alpha = 0.5f), RoundedCornerShape(16.dp))
                                .clickable { onAddMenuExpandedChanged(true) }
                                .padding(horizontal = 12.dp, vertical = 6.dp)
                                .onPointerEvent(PointerEventType.Enter) {
                                    addSubtitleButtonHovered = true
                                }
                                .onPointerEvent(PointerEventType.Exit) {
                                    addSubtitleButtonHovered = false
                                },
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            Text("添加", color = DefaultTextColor, fontSize = 12.sp)
                            Icon(
                                imageVector = Icons.Default.KeyboardArrowDown,
                                contentDescription = null,
                                tint = DefaultTextColor,
                                modifier = Modifier.size(14.dp)
                            )
                        }

                        if (isAddMenuExpanded) {
                            AddSubtitleDropdown(
                                onDismissRequest = { onAddMenuExpandedChanged(false) },
                                onOpenSubtitleSearch = onOpenSubtitleSearch,
                                onOpenAddNasSubtitle = onOpenAddNasSubtitle,
                                onOpenAddLocalSubtitle = onOpenAddLocalSubtitle,
                                onAddMenuHoverChanged = onAddMenuHoverChanged
                            )
                        }
                    }
                }
            }

            HorizontalDivider(
                modifier = Modifier.padding(vertical = 12.dp),
                color = Color.White.copy(alpha = 0.1f)
            )
            val lazyListState = rememberLazyListState()
            LaunchedEffect(isExpanded) {
                if (isExpanded) {
                    val index = subtitleList.indexOfFirst { it.guid == currentSubtitle?.guid }
                    if (index != -1) {
                        // 加1是因为有一个"关闭"选项在列表头部
                        lazyListState.scrollToItem(index + 1)
                    } else if (currentSubtitle == null) {
                        lazyListState.scrollToItem(0)
                    }
                }
            }
            AnimatedScrollbarLazyColumn(
                listState = lazyListState,
                modifier = Modifier.height(300.dp),
                scrollbarWidth = 6.dp,
                scrollbarOffsetX = 3.dp
            ) {
                // Off option
                item {
                    SubtitleOptionItem(
                        language = "关闭",
                        details = "",
                        title = "",
                        isDefault = false,
                        isSelected = currentSubtitle == null,
                        onClick = { onSubtitleSelected(null) }
                    )
                }

                items(subtitleList) { subtitle ->
                    val isSelected = subtitle.guid == currentSubtitle?.guid
                    val languageTitle: String = FnDataConvertor.getLanguageName(
                        subtitle.language,
                        isoTagData
                    )
                    val title =
                        if (subtitle.isExternal == 1) "$languageTitle - 外挂" else languageTitle
                    val details = "${subtitle.format.uppercase()}  ${subtitle.title}"

                    SubtitleOptionItem(
                        language = title,
                        details = details,
                        title = "",
                        isDefault = subtitle.isDefault == 1,
                        isSelected = isSelected,
                        onClick = { onSubtitleSelected(subtitle) },
                        isExternal = subtitle.isExternal == 1,
                        onDelete = { onRequestDelete(subtitle) }
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun AddSubtitleDropdown(
    onDismissRequest: () -> Unit,
    onOpenSubtitleSearch: () -> Unit,
    onOpenAddNasSubtitle: () -> Unit,
    onOpenAddLocalSubtitle: () -> Unit,
    onAddMenuHoverChanged: (Boolean) -> Unit
) {
    Popup(
        onDismissRequest = onDismissRequest,
        offset = IntOffset(0, 40), // Adjust offset to appear below the button
        properties = PopupProperties(focusable = false)
    ) {
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = FlyoutBackgroundColor, // Semi-transparent black
            border = BorderStroke(1.dp, FlyoutBorderColor),
            modifier = Modifier
                .width(200.dp)
                .onPointerEvent(PointerEventType.Enter) {
                    onAddMenuHoverChanged(true)
                }
                .onPointerEvent(PointerEventType.Exit) {
                    onAddMenuHoverChanged(false)
                }
        ) {
            Column(modifier = Modifier.padding(vertical = 8.dp)) {
                AddSubtitleDropdownItem(
                    text = "搜索字幕",
                    icon = Icons.Default.Search,
                    onClick = {
                        onDismissRequest()
                        onOpenSubtitleSearch()
                    }
                )
                AddSubtitleDropdownItem(
                    text = "添加 NAS 字幕文件",
                    icon = Icons.Default.Storage,
                    onClick = {
                        onDismissRequest()
                        onOpenAddNasSubtitle()
                    }
                )
                AddSubtitleDropdownItem(
                    text = "添加电脑字幕文件",
                    icon = Icons.Default.Computer,
                    onClick = {
                        onDismissRequest()
                        onOpenAddLocalSubtitle()
                    }
                )
            }
        }
    }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun AddSubtitleDropdownItem(
    text: String,
    icon: ImageVector,
    onClick: () -> Unit
) {
    var isHovered by remember { mutableStateOf(false) }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .background(if (isHovered) HoverBackgroundColor else Color.Transparent)
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .onPointerEvent(PointerEventType.Enter) { isHovered = true }
            .onPointerEvent(PointerEventType.Exit) { isHovered = false },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size(18.dp)
        )
        Text(
            text = text,
            color = Color.White,
            fontSize = 14.sp
        )
    }
}


@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun SubtitleOptionItem(
    language: String,
    details: String,
    title: String,
    isDefault: Boolean,
    isSelected: Boolean,
    onClick: () -> Unit,
    isExternal: Boolean = false,
    onDelete: (() -> Unit)? = null
) {
    val textColor = if (isSelected) SelectedTextColor else DefaultTextColor
    var isHovered by remember { mutableStateOf(false) }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 4.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(if (isHovered || isSelected) HoverBackgroundColor else Color.Transparent)
            .clickable(onClick = onClick)
            .onPointerEvent(PointerEventType.Enter) { isHovered = true }
            .onPointerEvent(PointerEventType.Exit) { isHovered = false }
            .padding(horizontal = 12.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = language,
                    color = textColor,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold
                )
                if (isDefault) {
                    Text(
                        text = " - 默认",
                        color = textColor,
                        fontSize = 14.sp
                    )
                }
            }
            if (details.isNotBlank()) {
                Text(
                    text = details,
                    color = if (isSelected) SelectedTextColor.copy(alpha = 0.8f) else DefaultTextColor.copy(
                        alpha = 0.6f
                    ),
                    fontSize = 12.sp,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }
        }

        if (isExternal && isHovered) {
            var isIconHovered by remember { mutableStateOf(false) }
            Box(
                modifier = Modifier
                    .size(28.dp)
                    .clip(RoundedCornerShape(50))
                    .background(if (isIconHovered) HoverBackgroundColor else Color.Transparent)
                    .clickable { onDelete?.invoke() }
                    .onPointerEvent(PointerEventType.Enter) { isIconHovered = true }
                    .onPointerEvent(PointerEventType.Exit) { isIconHovered = false },
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = Delete,
                    contentDescription = "删除字幕",
                    tint = DefaultTextColor,
                    modifier = Modifier.size(14.dp)
                )
            }
        }
    }
}
