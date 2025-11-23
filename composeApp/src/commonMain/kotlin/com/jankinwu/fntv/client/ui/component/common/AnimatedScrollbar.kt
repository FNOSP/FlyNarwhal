package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.ScrollState
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.scrollBy
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListScope
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import io.github.composefluent.FluentTheme
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Suppress("FrequentlyChangingValue")
@Composable
fun AnimatedScrollbarLazyColumn(
    listState: LazyListState,
    modifier: Modifier = Modifier,
    content: LazyListScope.() -> Unit
) {
    var isHovered by remember { mutableStateOf(false) }
    var isDragging by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()
    val density = LocalDensity.current
    var hideScrollbarJob by remember { mutableStateOf<Job?>(null) }
    var isScrollbarHovered by remember { mutableStateOf(false) }


    Box(
        modifier = modifier.pointerInput(Unit) {
            awaitPointerEventScope {
                while (true) {
                    val event = awaitPointerEvent()
                    when (event.type) {
                        PointerEventType.Enter, PointerEventType.Move -> {
                            isHovered = true
                            hideScrollbarJob?.cancel()
                            hideScrollbarJob = coroutineScope.launch {
                                delay(1000)
                                isHovered = false
                            }
                        }
                        PointerEventType.Exit -> {
                            hideScrollbarJob?.cancel()
                            isHovered = false
                        }
                    }
                }
            }
        }
    ) {
        LazyColumn(
            state = listState,
            modifier = Modifier.fillMaxSize().padding(end = 12.dp)
        ) {
            content()
        }

        AnimatedVisibility(
            visible = listState.isScrollInProgress || isHovered || isDragging || isScrollbarHovered,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier.align(Alignment.CenterEnd)
        ) {
            val layoutInfo = remember(listState) {
                derivedStateOf { listState.layoutInfo }
            }.value
            val visibleItemsInfo = layoutInfo.visibleItemsInfo
            if (visibleItemsInfo.isNotEmpty() && layoutInfo.totalItemsCount > 0) {
                val viewportHeight = layoutInfo.viewportSize.height.toFloat()

                val averageItemHeight = visibleItemsInfo.sumOf { it.size } / visibleItemsInfo.size.toFloat()
                val totalContentHeight = averageItemHeight * layoutInfo.totalItemsCount

                if (totalContentHeight <= viewportHeight) return@AnimatedVisibility

                val scrollbarHeightRatio = viewportHeight / totalContentHeight
                val scrollbarHeightPx = scrollbarHeightRatio * viewportHeight
                val scrollbarHeight = with(density) { scrollbarHeightPx.toDp() }

                val scrollableDistance = totalContentHeight - viewportHeight
                val scrollbarMaxOffset = viewportHeight - scrollbarHeightPx

                val currentScrollPosition = listState.firstVisibleItemIndex * averageItemHeight + listState.firstVisibleItemScrollOffset
                val scrollbarOffsetPx = if (scrollableDistance > 0) (currentScrollPosition / scrollableDistance * scrollbarMaxOffset) else 0f
                val scrollbarOffset = with(density) { scrollbarOffsetPx.toDp() }
                // 修改这里的颜色逻辑，根据是否悬浮显示不同颜色
                val scrollbarColor = if (isScrollbarHovered || isDragging) {
                    FluentTheme.colors.text.text.secondary // 高亮颜色
                } else {
                    FluentTheme.colors.text.text.tertiary // 默认颜色
                }
                Box(
                    modifier = Modifier
                        .fillMaxHeight()
                        .width(6.dp)
                        .background(Color.Transparent)
                        .pointerInput(Unit) {
                            awaitPointerEventScope {
                                while (true) {
                                    val event = awaitPointerEvent()
                                    when (event.type) {
                                        PointerEventType.Enter -> {
                                            isScrollbarHovered = true
                                            hideScrollbarJob?.cancel()
                                        }
                                        PointerEventType.Exit -> {
                                            isScrollbarHovered = false
                                        }
                                    }
                                }
                            }
                        }
                ) {
                    Box(
                        modifier = Modifier
                            .height(scrollbarHeight)
                            .fillMaxWidth()
                            .align(Alignment.TopCenter)
                            .offset(y = scrollbarOffset)
                            .background(scrollbarColor, CircleShape)
                            .pointerInput(Unit) {
                                detectDragGestures(
                                    onDragStart = {
                                        hideScrollbarJob?.cancel()
                                        isDragging = true
                                    },
                                    onDragEnd = { isDragging = false },
                                    onDragCancel = { isDragging = false }
                                ) { change, dragAmount ->
                                    change.consume()
                                    coroutineScope.launch {
                                        if (scrollbarMaxOffset > 0) {
                                            val scrollDelta = (dragAmount.y / scrollbarMaxOffset) * scrollableDistance
                                            listState.scrollBy(scrollDelta)
                                        }
                                    }
                                }
                            }
                    )
                }
            }
        }
    }
}

@Composable
fun AnimatedScrollbarColumn(
    scrollState: ScrollState,
    modifier: Modifier = Modifier,
    content: @Composable () -> Unit
) {
    var isHovered by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()
    var viewportHeight by remember { mutableStateOf(0f) }
    val density = LocalDensity.current

    Box(
        modifier = modifier
            .onSizeChanged { viewportHeight = it.height.toFloat() }
            .pointerInput(Unit) {
                awaitPointerEventScope {
                    while (true) {
                        val event = awaitPointerEvent()
                        when (event.type) {
                            PointerEventType.Enter -> isHovered = true
                            PointerEventType.Exit -> isHovered = false
                        }
                    }
                }
            }
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(scrollState)
                .padding(end = 12.dp)
        ) {
            content()
        }

        AnimatedVisibility(
            visible = scrollState.isScrollInProgress || isHovered,
            enter = fadeIn(),
            exit = fadeOut(),
            modifier = Modifier.align(Alignment.CenterEnd)
        ) {
            if (scrollState.maxValue > 0 && viewportHeight > 0) {
                val contentHeight = scrollState.maxValue + viewportHeight

                val scrollbarHeightRatio = viewportHeight / contentHeight
                val scrollbarHeightPx = scrollbarHeightRatio * viewportHeight
                val scrollbarHeight = with(density) { scrollbarHeightPx.toDp() }

                val scrollableDistance = contentHeight - viewportHeight
                val scrollbarMaxOffset = viewportHeight - scrollbarHeightPx

                val scrollbarOffsetPx = (scrollState.value.toFloat() / scrollableDistance * scrollbarMaxOffset)
                val scrollbarOffset = with(density) { scrollbarOffsetPx.toDp() }

                Box(
                    modifier = Modifier
                        .fillMaxHeight()
                        .width(8.dp)
                        .background(Color.Transparent)
                ) {
                    Box(
                        modifier = Modifier
                            .height(scrollbarHeight)
                            .fillMaxWidth()
                            .align(Alignment.TopCenter)
                            .offset(y = scrollbarOffset)
                            .background(Color.Gray, CircleShape)
                            .pointerInput(Unit) {
                                detectDragGestures { change, dragAmount ->
                                    change.consume()
                                    coroutineScope.launch {
                                        if (scrollbarMaxOffset > 0) {
                                            val scrollDelta = (dragAmount.y / scrollbarMaxOffset) * scrollableDistance
                                            scrollState.scrollBy(scrollDelta)
                                        }
                                    }
                                }
                            }
                    )
                }
            }
        }
    }
}
