package com.jankinwu.fntv.client.ui.component.common

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.animateScrollBy
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import com.jankinwu.fntv.client.data.model.ScrollRowItemData
import io.github.composefluent.FluentTheme
import io.github.composefluent.LocalContentColor
import io.github.composefluent.component.Icon
import io.github.composefluent.icons.Icons
import io.github.composefluent.icons.filled.IosArrowLtr
import io.github.composefluent.icons.filled.IosArrowRtl
import kotlinx.coroutines.launch

@Suppress("UnusedBoxWithConstraintsScope")
@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun ScrollRow(
    itemsData: List<ScrollRowItemData>,
    listState: LazyListState = rememberLazyListState(),
    item: @Composable (index: Int, movie: ScrollRowItemData, modifier: Modifier, onMarkAsWatched: (() -> Unit)?) -> Unit = { _, _, _, _ -> }
) {
    val scope = rememberCoroutineScope()
    var isHovered by remember { mutableStateOf(false) }
    var posterWidthPx by remember { mutableIntStateOf(0) }
    val posterWidthDp = with(LocalDensity.current) { posterWidthPx.toDp() }
    val canScrollForward by remember { derivedStateOf { listState.canScrollForward } }
    val canScrollBackward by remember { derivedStateOf { listState.canScrollBackward } }
    // 定义一个可重用的动画规格，使用 "先快后慢" 的缓动曲线
    val animationSpec = tween<Float>(
        durationMillis = 100,
        easing = FastOutSlowInEasing
    )

    BoxWithConstraints(
        modifier = Modifier
            .fillMaxSize()
            .onPointerEvent(PointerEventType.Enter) { isHovered = true }
            .onPointerEvent(PointerEventType.Exit) { isHovered = false }
    ) {
        val rowWidth = maxWidth
        val itemSpacing = 24.dp
        val horizontalPadding = 32.dp

        val totalContentWidth by remember(posterWidthDp) { mutableStateOf((posterWidthDp * itemsData.size) + (itemSpacing * (itemsData.size - 1))) }

        val isScrollable by remember(totalContentWidth, rowWidth) { mutableStateOf(totalContentWidth > (rowWidth - horizontalPadding * 2)) }

        // 横向滚动的电影海报列表
        LazyRow(
            state = listState,
            modifier = Modifier
                .fillMaxWidth(),
            contentPadding = PaddingValues(horizontal = horizontalPadding),
//            horizontalArrangement = Arrangement.spacedBy(0.dp), // 使用0间距，手动控制间距
            verticalAlignment = Alignment.Top
        ) {
            itemsIndexed(
                items = itemsData,
                key = { _, item -> item.guid + item.title + item.subtitle }// 使用 GUID 作为 key
            ) { index, movie ->
                val itemModifier = Modifier
                    .fillMaxHeight()
                    .onSizeChanged {
                        if (posterWidthPx != it.width) {
                            posterWidthPx = it.width
                        }
                    }
                    // 使用 visibleIndex 来决定间距，确保只有可见项目之间有间距
                    .padding(start = if (index > 0) itemSpacing else 0.dp)

                item(
                    index,
                    movie,
                    itemModifier,
                    null
                )
            }
        }

        val scrollAmount =
            with(LocalDensity.current) { (rowWidth - horizontalPadding).toPx() * 0.8f }
        // 定义滚动动画规格
        val scrollAnimationSpec = tween<Float>(
            durationMillis = 1000, // 1秒持续时间
            easing = FastOutSlowInEasing,
            delayMillis = 0
        )
        // 右侧滚动按钮
        AnimatedVisibility(
            visible = isHovered && canScrollForward && isScrollable,
            modifier = Modifier.align(Alignment.CenterEnd),
            enter = fadeIn(animationSpec = animationSpec),
            exit = fadeOut(animationSpec = animationSpec)
        ) {
            ScrollButton(
                onClick = {
                    scope.launch {
                        listState.animateScrollBy(scrollAmount, scrollAnimationSpec)
                    }
                },
                isLeft = false,
                modifier = Modifier.fillMaxHeight()
            )
        }

        // 左侧滚动按钮
        AnimatedVisibility(
            visible = isHovered && canScrollBackward && isScrollable,
            modifier = Modifier.align(Alignment.CenterStart),
            enter = fadeIn(animationSpec = animationSpec),
            exit = fadeOut(animationSpec = animationSpec)
        ) {
            ScrollButton(
                onClick = {
                    scope.launch {
                        listState.animateScrollBy(-scrollAmount, scrollAnimationSpec)
                    }
                },
                isLeft = true,
                modifier = Modifier.fillMaxHeight()
            )
        }
    }
}

/**
 * 用于媒体库左右滚动的导航按钮.
 *
 * @param onClick 按钮点击事件.
 * @param isLeft 是否是左侧按钮 (决定渐变方向和图标).
 */
@OptIn(ExperimentalComposeUiApi::class)
@Composable
internal fun ScrollButton(onClick: () -> Unit, isLeft: Boolean, modifier: Modifier = Modifier) {
    var isIconHovered by remember { mutableStateOf(false) }

    // icon 缩放动画
    val iconSize by animateDpAsState(
        targetValue = if (isIconHovered) 24.dp else 16.dp,
        animationSpec = tween(
            durationMillis = 200,
            easing = FastOutSlowInEasing
        ),
        label = "iconSize"
    )


    Box(
        modifier = modifier
            .width(30.dp)
            .fillMaxHeight()
            .background(
                FluentTheme.colors.controlOnImage.default.copy(alpha = 0.9f)
            ),
        contentAlignment = Alignment.Center
    ) {
        Icon(
            imageVector = if (isLeft) Icons.Filled.IosArrowLtr else Icons.Filled.IosArrowRtl,
            contentDescription = if (isLeft) "Scroll Left" else "Scroll Right",
            tint = LocalContentColor.current,
            modifier = Modifier
                .size(iconSize)
                .onPointerEvent(PointerEventType.Enter) { isIconHovered = true }
                .onPointerEvent(PointerEventType.Exit) { isIconHovered = false }
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null, // 移除点击时的涟漪效果
                    onClick = onClick
                )
                .pointerHoverIcon(PointerIcon.Hand)
        )
    }
}