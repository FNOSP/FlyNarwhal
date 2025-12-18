package com.jankinwu.fntv.client.ui.component.player

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Surface
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
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
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupProperties
import coil3.PlatformContext
import coil3.compose.SubcomposeAsyncImage
import coil3.network.httpHeaders
import coil3.request.ImageRequest
import coil3.request.crossfade
import com.jankinwu.fntv.client.data.constants.Constants
import com.jankinwu.fntv.client.data.convertor.FnDataConvertor
import com.jankinwu.fntv.client.data.model.response.EpisodeListResponse
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.ui.component.common.AnimatedScrollbarLazyColumn
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingError
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingProgressRing
import com.jankinwu.fntv.client.ui.providable.LocalStore
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

private val FlyoutBackgroundColor = Color.Black.copy(alpha = 0.9f)
private val FlyoutBorderColor = Color.Gray.copy(alpha = 0.5f)
private val SelectedTextColor = Color(0xFF2073DF)
private val HoverBackgroundColor = Color.White.copy(alpha = 0.1f)
private val DefaultTextColor = Color.White.copy(alpha = 0.7843f)
private val MenuWidth = 360.dp
private val FlyoutShape = RoundedCornerShape(8.dp)
private const val HIDE_DELAY_MS = 200L
private const val ANIMATION_DURATION_MS = 200

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun EpisodeSelectionFlyout(
    episodes: List<EpisodeListResponse>,
    currentEpisodeGuid: String,
    parentTitle: String,
    onEpisodeSelected: (EpisodeListResponse) -> Unit,
    isAutoPlay: Boolean,
    onAutoPlayChanged: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    onHoverStateChanged: ((Boolean) -> Unit)? = null
) {
    var isExpanded by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()
    var hideJob by remember { mutableStateOf<Job?>(null) }
    var isButtonHovered by remember { mutableStateOf(false) }
    var popupHovered by remember { mutableStateOf(false) }
    var showPopup by remember { mutableStateOf(false) }

    fun showFlyout() {
        hideJob?.cancel()
        isExpanded = true
        showPopup = true
        onHoverStateChanged?.invoke(true)
    }

    fun hideFlyoutWithDelay() {
        hideJob = coroutineScope.launch {
            delay(HIDE_DELAY_MS)
            if (!isButtonHovered && !popupHovered) {
                isExpanded = false
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
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(4.dp)
        ) {
//            Icon(
//                imageVector = Icons.Regular.List,
//                contentDescription = "选集",
//                tint = Color.White,
//                modifier = Modifier.size(24.dp)
//            )
            Text(
                text = "选集",
                color = Color.White.copy(alpha = 0.7843f),
                fontSize = 17.sp
            )
        }

        if (showPopup) {
            Popup(
                offset = IntOffset(-0, -70),
                alignment = Alignment.BottomCenter,
                properties = PopupProperties(
                    clippingEnabled = false,
                    focusable = false
                ),
                onDismissRequest = {
                    if (!isButtonHovered && !popupHovered) {
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
                        EpisodeListContent(
                            episodes = episodes,
                            currentEpisodeGuid = currentEpisodeGuid,
                            parentTitle = parentTitle,
                            onEpisodeSelected = {
                                onEpisodeSelected(it)
                                isExpanded = false
                                if (!isButtonHovered) {
                                    onHoverStateChanged?.invoke(false)
                                }
                            },
                            isAutoPlay = isAutoPlay,
                            onAutoPlayChanged = onAutoPlayChanged
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

@Composable
fun EpisodeListContent(
    episodes: List<EpisodeListResponse>,
    currentEpisodeGuid: String,
    parentTitle: String,
    onEpisodeSelected: (EpisodeListResponse) -> Unit,
    isAutoPlay: Boolean,
    onAutoPlayChanged: (Boolean) -> Unit
) {
    Surface(
        shape = FlyoutShape,
        color = FlyoutBackgroundColor,
        border = BorderStroke(1.dp, FlyoutBorderColor),
        modifier = Modifier.width(MenuWidth)
    ) {
        Column(modifier = Modifier.padding(vertical = 16.dp)) {
            // Header
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 4.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = parentTitle,
                    color = Color.White,
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )

                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        text = "自动连播",
                        color = DefaultTextColor,
                        fontSize = 12.sp
                    )
                    Switch(
                        checked = isAutoPlay,
                        onCheckedChange = onAutoPlayChanged,
                        modifier = Modifier.scale(0.7f).height(30.dp),
                        colors = SwitchDefaults.colors(
                            checkedThumbColor = Color.White,
                            checkedTrackColor = SelectedTextColor,
                            uncheckedThumbColor = Color.White,
                            uncheckedTrackColor = Color.Gray.copy(alpha = 0.5f),
                            uncheckedBorderColor = Color.Transparent
                        )
                    )
                }
            }

            HorizontalDivider(
                modifier = Modifier.padding(vertical = 12.dp),
                color = Color.White.copy(alpha = 0.1f)
            )

            val lazyListState = rememberLazyListState()
            
            // Scroll to current episode
            LaunchedEffect(currentEpisodeGuid) {
                val index = episodes.indexOfFirst { it.guid == currentEpisodeGuid }
                if (index != -1) {
                    lazyListState.scrollToItem(index)
                }
            }

            AnimatedScrollbarLazyColumn(
                listState = lazyListState,
                modifier = Modifier.height(400.dp),
                scrollbarWidth = 2.dp,
                scrollbarOffsetX = (-2).dp
            ) {
                items(episodes) { episode ->
                    EpisodeItem(
                        episode = episode,
                        isSelected = episode.guid == currentEpisodeGuid,
                        onClick = { onEpisodeSelected(episode) }
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun EpisodeItem(
    episode: EpisodeListResponse,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    var isHovered by remember { mutableStateOf(false) }
    val store = LocalStore.current
    
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(bottom = 4.dp, start = 8.dp, end = 8.dp)
            .clip(RoundedCornerShape(8.dp))
            .background(if (isHovered || isSelected) HoverBackgroundColor else Color.Transparent)
            .clickable(onClick = onClick)
            .onPointerEvent(PointerEventType.Enter) { isHovered = true }
            .onPointerEvent(PointerEventType.Exit) { isHovered = false }
            .padding(8.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Thumbnail
        Box(
            modifier = Modifier
                .width(120.dp)
                .height(67.dp) // 16:9 approx
                .clip(RoundedCornerShape(4.dp))
        ) {
            SubcomposeAsyncImage(
                model = ImageRequest.Builder(PlatformContext.INSTANCE)
                    .data("${AccountDataCache.getFnOfficialBaseUrl()}/v/api/v1/sys/img${episode.poster}${Constants.FN_IMG_URL_PARAM}")
                    .httpHeaders(store.fnImgHeaders)
                    .crossfade(true)
                    .build(),
                contentDescription = episode.title,
                modifier = Modifier.matchParentSize(),
                contentScale = ContentScale.Crop,
                loading = { ImgLoadingProgressRing(modifier = Modifier.matchParentSize()) },
                error = { ImgLoadingError() }
            )
            
            // Progress Bar (if watched)
            if (episode.ts > 0 && episode.runtime > 0) {
                 val progress = (episode.ts.toFloat() / episode.runtime.toFloat()).coerceIn(0f, 1f)
                 Box(
                     modifier = Modifier
                         .align(Alignment.BottomStart)
                         .fillMaxWidth(progress)
                         .height(3.dp)
                         .background(SelectedTextColor)
                 )
            }
        }

        // Info
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.Center
        ) {
            val titleText = if (episode.title.isNotBlank()) {
                "${episode.episodeNumber.toString().padStart(2, '0')}. ${episode.title}"
            } else {
                "第 ${episode.episodeNumber} 集"
            }
            
            Text(
                text = titleText,
                color = if (isSelected) SelectedTextColor else Color.White,
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
            
            if (episode.runtime > 0) {
                Text(
                    text = FnDataConvertor.formatSecondsToCNDateTime(episode.runtime),
                    color = DefaultTextColor.copy(alpha = 0.6f),
                    fontSize = 12.sp,
                    modifier = Modifier.padding(top = 4.dp)
                )
            }
        }
    }
}
