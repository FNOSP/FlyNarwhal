package com.jankinwu.fntv.client.ui.component.player

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupProperties
import com.jankinwu.fntv.client.ui.providable.LocalTypography
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Stable
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.graphics.graphicsLayer

private val FlyoutBackgroundColor = Color.Black.copy(alpha = 0.9f)
private val FlyoutBorderColor = Color.Gray.copy(alpha = 0.5f)
private val SelectedTextColor = Color(0xFF2073DF)
private val DefaultTextColor = Color.White.copy(alpha = 0.7843f)
private val HoverBackgroundColor = Color.White.copy(alpha = 0.1f)
private val FlyoutShape = RoundedCornerShape(8.dp)
private const val HIDE_DELAY_MS = 200L // 增加延迟时间以减少闪烁
private const val ANIMATION_DURATION_MS = 200 // 动画持续时间

data class SpeedItem(
    val label: String,
    val value: Float
)

val speeds = listOf(
    SpeedItem("2.0x", 2.0f),
    SpeedItem("1.75x", 1.75f),
    SpeedItem("1.5x", 1.5f),
    SpeedItem("1.25x", 1.25f),
    SpeedItem("1.0x", 1.0f),
    SpeedItem("0.75x", 0.75f),
    SpeedItem("0.5x", 0.5f)
)



/**
 * 倍速调节 Flyout 组件
 *
 * @param modifier The modifier to be applied to the component.
 * @param speeds 可用的倍速选项列表.
 * @param defaultSpeed 默认选中的倍速.
 * @param onSpeedSelected 当选择新的倍速时触发的回调.
 */
@Stable
@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun SpeedControlFlyout(
    modifier: Modifier = Modifier,
    defaultSpeed: SpeedItem = speeds[4],
    yOffset: Int = 0,
    onHoverStateChanged: ((Boolean) -> Unit)? = null,
    onSpeedSelected: (SpeedItem) -> Unit = {}
) {
    var selectedSpeed by remember { mutableStateOf(defaultSpeed) }
    var isExpanded by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()
    var hideJob by remember { mutableStateOf<Job?>(null) }
    var isButtonHovered by remember { mutableStateOf(false) }
    var popupHovered by remember { mutableStateOf(false) }
    var showPopup by remember { mutableStateOf(false) } // 控制Popup的显示

    // 函数：取消隐藏任务并显示选择框
    fun showFlyout() {
        hideJob?.cancel()
        isExpanded = true
        showPopup = true
        onHoverStateChanged?.invoke(true)
    }

    // 函数：启动一个带延迟的隐藏任务
    fun hideFlyoutWithDelay() {
        hideJob = coroutineScope.launch {
            delay(HIDE_DELAY_MS)
            // 只有当按钮和弹出框都不处于悬停状态时才隐藏
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
                popupHovered = false
                hideFlyoutWithDelay()
            },
        contentAlignment = Alignment.Center
    ) {
        // 使用 AnimatedVisibility 控制 Popup 的显示
        // 使用 Popup 实现悬浮
        if (showPopup) {
            Popup(
                offset = IntOffset(0, -yOffset),
                alignment = Alignment.BottomCenter,
                properties = PopupProperties(
                    clippingEnabled = false,
                    focusable = false
                ),
                onDismissRequest = { 
                    // 只有当鼠标不在按钮或弹出框上时才关闭
                    if (!isButtonHovered && !popupHovered) {
                        isExpanded = false
                    }
                }
            ) {
                // 这个Box用于捕获鼠标事件，以防止在移动到选择框上时其消失
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
                        onSpeedClick = { speed ->
                            selectedSpeed = speed
                            isExpanded = false // 点击后立即隐藏
                            onSpeedSelected(speed)
                        },
                        speeds = speeds,
                        selectedSpeed = selectedSpeed,
                        onAnimationFinished = { 
                            // 动画完成后才真正隐藏Popup
                            if (!isExpanded) {
                                showPopup = false
                            }
                        }
                    )
                }
            }
        }
        Text(
            text = if (selectedSpeed.label == "1.0x") "倍速" else selectedSpeed.label,
            style = LocalTypography.current.title,
            color = if (isButtonHovered) Color.White else DefaultTextColor,
            fontSize = 17.sp,
            fontWeight = FontWeight.Normal
        )
    }
}

@Composable
private fun FlyoutWithAnimation(
    isExpanded: Boolean,
    speeds: List<SpeedItem>,
    selectedSpeed: SpeedItem,
    onSpeedClick: (SpeedItem) -> Unit,
    onAnimationFinished: () -> Unit // 动画完成回调
) {
    val alpha = remember { Animatable(0f) }
    val scale = remember { Animatable(0.4f) }
    val offsetY = remember { Animatable(0f) } // 用于底部对齐的偏移

    LaunchedEffect(isExpanded) {
        if (isExpanded) {
            // 显示动画：淡入、放大、向上移动以实现底部对齐
            launch {
                alpha.animateTo(
                    targetValue = 1f,
                    animationSpec = tween(ANIMATION_DURATION_MS)
                )
            }
            launch {
                scale.animateTo(
                    targetValue = 1f,
                    animationSpec = tween(ANIMATION_DURATION_MS)
                )
            }
            launch {
                // 向上移动以补偿缩放，实现底部对齐
                offsetY.animateTo(
                    targetValue = 0f,
                    animationSpec = tween(ANIMATION_DURATION_MS)
                )
            }
        } else {
            // 隐藏动画：淡出、缩小、向下移动
            launch {
                alpha.animateTo(
                    targetValue = 0f,
                    animationSpec = tween(ANIMATION_DURATION_MS)
                )
            }
            launch {
                scale.animateTo(
                    targetValue = 0.4f,
                    animationSpec = tween(ANIMATION_DURATION_MS)
                )
            }
            launch {
                // 向下移动以补偿缩放，实现底部对齐
                offsetY.animateTo(
                    targetValue = 10f,
                    animationSpec = tween(ANIMATION_DURATION_MS)
                )
            }
            // 等待动画完成后再通知
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
                // 设置变换原点为底部中心
                transformOrigin = androidx.compose.ui.graphics.TransformOrigin(0.5f, 1f)
            }
            // 应用偏移以实现底部对齐
            .padding(bottom = offsetY.value.dp)
    ) {
        FlyoutContent(
            speeds = speeds,
            selectedSpeed = selectedSpeed,
            onSpeedClick = onSpeedClick
        )
    }
}

@Composable
private fun FlyoutContent(
    speeds: List<SpeedItem>,
    selectedSpeed: SpeedItem,
    onSpeedClick: (SpeedItem) -> Unit
) {
    Surface(
        shape = FlyoutShape,
        color = FlyoutBackgroundColor,
        border = BorderStroke(1.dp, FlyoutBorderColor),
    ) {
        Column(
            modifier = Modifier
                .width(120.dp)
                .padding(vertical = 10.dp)
        ) {
            speeds.forEach { speed ->
                FlyoutItem(
                    speed = speed,
                    isSelected = speed == selectedSpeed,
                    onClick = { onSpeedClick(speed) }
                )
            }
        }
    }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
private fun FlyoutItem(
    speed: SpeedItem,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    var isHovered by remember { mutableStateOf(false) }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp)
            .clip(RoundedCornerShape(4.dp))
            .background(if (isHovered) HoverBackgroundColor else Color.Transparent)
            .clickable { onClick() }
            .padding(horizontal = 12.dp, vertical = 8.dp)
            .onPointerEvent(PointerEventType.Enter) { isHovered = true }
            .onPointerEvent(PointerEventType.Exit) { isHovered = false },
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(
            text = speed.label,
            color = if (isSelected) SelectedTextColor else DefaultTextColor,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium
        )
        if (isSelected) {
            Icon(
                imageVector = Icons.Default.Check,
                contentDescription = "Selected",
                tint = DefaultTextColor,
                modifier = Modifier.size(18.dp)
            )
        }
    }
}