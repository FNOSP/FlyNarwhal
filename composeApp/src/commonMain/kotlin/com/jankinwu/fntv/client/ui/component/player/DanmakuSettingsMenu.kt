package com.jankinwu.fntv.client.ui.component.player

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
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
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Popup
import androidx.compose.ui.window.PopupProperties
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.icons.DanmuSetting
import com.jankinwu.fntv.client.icons.Setting
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

private val FlyoutBackgroundColor = Color.Black.copy(alpha = 0.9f)
private val FlyoutBorderColor = Color.Gray.copy(alpha = 0.5f)
private const val HIDE_DELAY_MS = 200L
private const val ANIMATION_DURATION_MS = 200
private val MenuWidth = 300.dp
private val MenuHeight = 240.dp

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun DanmakuSettingsMenu(
    area: Float,
    opacity: Float,
    fontSize: Float,
    speed: Float,
    syncPlaybackSpeed: Boolean,
    debugEnabled: Boolean,
    onAreaChange: (Float) -> Unit,
    onOpacityChange: (Float) -> Unit,
    onFontSizeChange: (Float) -> Unit,
    onSpeedChange: (Float) -> Unit,
    onSyncPlaybackSpeedChanged: (Boolean) -> Unit,
    onDebugEnabledChanged: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    onHoverStateChanged: ((Boolean) -> Unit)? = null
) {
    var isExpanded by remember { mutableStateOf(false) }
    val coroutineScope = rememberCoroutineScope()
    var hideJob by remember { mutableStateOf<Job?>(null) }
    var isButtonHovered by remember { mutableStateOf(false) }
    var popupHovered by remember { mutableStateOf(false) }
    var showPopup by remember { mutableStateOf(false) }
    var currentScreen by remember { mutableStateOf("Main") }

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
                currentScreen = "Main"
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
        Icon(
            imageVector = DanmuSetting,
            contentDescription = "弹幕设置",
            tint = Color.White,
            modifier = Modifier.size(26.dp)
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
                    if (!isButtonHovered && !popupHovered) {
                        isExpanded = false
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
                    DanmakuSettingsFlyout(
                        isExpanded = isExpanded,
                        area = area,
                        opacity = opacity,
                        fontSize = fontSize,
                        speed = speed,
                        syncPlaybackSpeed = syncPlaybackSpeed,
                        debugEnabled = debugEnabled,
                        currentScreen = currentScreen,
                        onNavigate = { currentScreen = it },
                        onAreaChange = onAreaChange,
                        onOpacityChange = onOpacityChange,
                        onFontSizeChange = onFontSizeChange,
                        onSpeedChange = onSpeedChange,
                        onSyncPlaybackSpeedChanged = onSyncPlaybackSpeedChanged,
                        onDebugEnabledChanged = onDebugEnabledChanged,
                        onAnimationFinished = {
                            if (!isExpanded) {
                                showPopup = false
                                currentScreen = "Main"
                            }
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun DanmakuSettingsFlyout(
    isExpanded: Boolean,
    area: Float,
    opacity: Float,
    fontSize: Float,
    speed: Float,
    syncPlaybackSpeed: Boolean,
    debugEnabled: Boolean,
    currentScreen: String,
    onNavigate: (String) -> Unit,
    onAreaChange: (Float) -> Unit,
    onOpacityChange: (Float) -> Unit,
    onFontSizeChange: (Float) -> Unit,
    onSpeedChange: (Float) -> Unit,
    onSyncPlaybackSpeedChanged: (Boolean) -> Unit,
    onDebugEnabledChanged: (Boolean) -> Unit,
    onAnimationFinished: () -> Unit
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
        Surface(
            shape = RoundedCornerShape(8.dp),
            color = FlyoutBackgroundColor,
            border = BorderStroke(1.dp, FlyoutBorderColor),
            modifier = Modifier.width(MenuWidth).height(MenuHeight)
        ) {
            Column(
                modifier = Modifier.fillMaxSize().padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
                horizontalAlignment = Alignment.Start
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(
                        text = if (currentScreen == "Advanced") "高级设置" else "弹幕设置",
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = if (currentScreen == "Advanced") "返回" else "高级",
                        color = Color(0xFF2073DF),
                        fontSize = 14.sp,
                        modifier = Modifier.pointerHoverIcon(PointerIcon.Hand).clickable {
                            if (currentScreen == "Advanced") {
                                onNavigate("Main")
                            } else {
                                onNavigate("Advanced")
                            }
                        }
                    )
                }

                HorizontalDivider(color = FlyoutBorderColor)

                Box(modifier = Modifier.fillMaxSize()) {
                    if (currentScreen == "Advanced") {
                        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "弹幕速度同步播放倍速",
                                    color = Color.White,
                                    fontSize = 14.sp
                                )
                                Switch(
                                    checked = syncPlaybackSpeed,
                                    onCheckedChange = onSyncPlaybackSpeedChanged,
                                    modifier = Modifier.scale(0.7f).height(30.dp),
                                    colors = SwitchDefaults.colors(
                                        checkedThumbColor = Color.White,
                                        checkedTrackColor = Colors.AccentColorDefault,
                                        uncheckedThumbColor = Color.White,
                                        uncheckedTrackColor = Color.Gray.copy(alpha = 0.5f),
                                        uncheckedBorderColor = Color.Transparent
                                    )
                                )
                            }

                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Text(
                                    text = "弹幕调试日志",
                                    color = Color.White,
                                    fontSize = 14.sp
                                )
                                Switch(
                                    checked = debugEnabled,
                                    onCheckedChange = onDebugEnabledChanged,
                                    modifier = Modifier.scale(0.7f).height(30.dp),
                                    colors = SwitchDefaults.colors(
                                        checkedThumbColor = Color.White,
                                        checkedTrackColor = Colors.AccentColorDefault,
                                        uncheckedThumbColor = Color.White,
                                        uncheckedTrackColor = Color.Gray.copy(alpha = 0.5f),
                                        uncheckedBorderColor = Color.Transparent
                                    )
                                )
                            }
                        }
                    } else {
                        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                            // 显示区域：10%, 25%, 50%, 75%, 100%
                            val areaSteps = listOf(0.1f, 0.25f, 0.5f, 0.75f, 1.0f)
                            val areaIndex =
                                areaSteps.indexOfFirst { kotlin.math.abs(it - area) < 0.01f }.coerceAtLeast(0)
                            DanmakuSettingRow(
                                label = "显示区域",
                                valueText = "${(areaSteps[areaIndex] * 100).toInt()}%",
                                value = areaIndex.toFloat() / (areaSteps.size - 1),
                                onValueChange = {
                                    val index = (it * (areaSteps.size - 1)).roundToInt()
                                    onAreaChange(areaSteps[index])
                                },
                                steps = areaSteps.size
                            )

                            // 不透明度
                            DanmakuSettingRow(
                                label = "不透明度",
                                value = opacity,
                                onValueChange = onOpacityChange,
                                valueText = "${(opacity * 100).roundToInt()}%",
                                steps = 0 // 无级
                            )

                            // 弹幕字号
                            val fontSizeMin = 0.5f
                            val fontSizeMax = 1.7f
                            val fontSizeSpan = fontSizeMax - fontSizeMin
                            val clampedFontSize = fontSize.coerceIn(fontSizeMin, fontSizeMax)
                            DanmakuSettingRow(
                                label = "弹幕字号",
                                value = (clampedFontSize - fontSizeMin) / fontSizeSpan, // 0.5 - 1.7 -> 0.0 - 1.0
                                onValueChange = { onFontSizeChange(it * fontSizeSpan + fontSizeMin) },
                                valueText = "${(clampedFontSize * 100).roundToInt()}%",
                                steps = 0 // 无级
                            )

                            // 弹幕速度
                            val speedLabels = listOf("极慢", "较慢", "适中", "较快", "极快")
                            val speedIndex = ((speed - 0.5f) / 1.5f * 4).roundToInt().coerceIn(0, 4)
                            DanmakuSettingRow(
                                label = "弹幕速度",
                                value = (speed - 0.5f) / 1.5f, // 0.5 - 2.0 -> 0.0 - 1.0
                                onValueChange = { onSpeedChange(it * 1.5f + 0.5f) },
                                valueText = speedLabels[speedIndex],
                                steps = 5 // 5个点
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun DanmakuSettingRow(
    label: String,
    value: Float,
    onValueChange: (Float) -> Unit,
    valueText: String,
    steps: Int = 0
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = label,
            color = Color.White,
            fontSize = 14.sp,
            modifier = Modifier.width(70.dp)
        )

        Box(modifier = Modifier.weight(1f)) {
            DanmakuHorizontalSlider(
                value = value,
                onValueChange = onValueChange,
                steps = steps
            )
        }

        Text(
            text = valueText,
            color = Color.White,
            fontSize = 14.sp,
            modifier = Modifier.width(40.dp),
            fontWeight = FontWeight.Normal
        )
    }
}

@Composable
private fun DanmakuHorizontalSlider(
    value: Float,
    onValueChange: (Float) -> Unit,
    steps: Int = 0
) {
    val barHeight = 4.dp
    val thumbRadius = 8.dp
    val dotRadius = 2.dp

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(24.dp)
            .pointerInput(steps) {
                detectTapGestures { offset ->
                    var newValue = (offset.x / size.width).coerceIn(0f, 1f)
                    if (steps > 1) {
                        val stepSize = 1f / (steps - 1)
                        newValue = (newValue / stepSize).roundToInt() * stepSize
                    }
                    onValueChange(newValue)
                }
            }
            .pointerInput(steps) {
                detectDragGestures { change, _ ->
                    var newValue = (change.position.x / size.width).coerceIn(0f, 1f)
                    if (steps > 1) {
                        val stepSize = 1f / (steps - 1)
                        newValue = (newValue / stepSize).roundToInt() * stepSize
                    }
                    onValueChange(newValue)
                    change.consume()
                }
            }
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
            val yCenter = size.height / 2
            val trackHeight = barHeight.toPx()

            // 背景轨道
            drawLine(
                color = Color.White.copy(alpha = 0.2f),
                start = Offset(0f, yCenter),
                end = Offset(size.width, yCenter),
                strokeWidth = trackHeight,
                cap = StrokeCap.Round
            )

            // 激活部分
            drawLine(
                color = Color(0xFF3B82F6),
                start = Offset(0f, yCenter),
                end = Offset(value * size.width, yCenter),
                strokeWidth = trackHeight,
                cap = StrokeCap.Round
            )

            // 分段点
            if (steps > 1) {
                val stepSize = size.width / (steps - 1)
                for (i in 0 until steps) {
                    val x = i * stepSize
                    drawCircle(
                        color = if (x <= value * size.width + 1f) Color.White else Color.White.copy(alpha = 0.5f),
                        radius = dotRadius.toPx(),
                        center = Offset(x, yCenter)
                    )
                }
            }

            // 滑块
            drawCircle(
                color = Color.White,
                radius = thumbRadius.toPx(),
                center = Offset(value * size.width, yCenter)
            )
        }
    }
}
