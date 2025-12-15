package com.jankinwu.fntv.client.ui.component.player

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
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
import com.jankinwu.fntv.client.manager.PlayerResourceManager
import io.github.alexzhirkevich.compottie.animateLottieCompositionAsState
import io.github.alexzhirkevich.compottie.rememberLottieComposition
import io.github.alexzhirkevich.compottie.rememberLottiePainter
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.roundToInt

private val FlyoutBackgroundColor = Color.Black.copy(alpha = 0.9f)
private val FlyoutBorderColor = Color.Gray.copy(alpha = 0.5f)
private const val HIDE_DELAY_MS = 200L
private const val ANIMATION_DURATION_MS = 200

/**
 * 音量调节组件
 *
 * @param modifier Modifier
 * @param volume 当前音量，范围 0.0 - 1.0
 * @param onVolumeChange 音量改变回调
 */
@Stable
@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun VolumeControl(
    modifier: Modifier = Modifier,
    volume: Float,
    onVolumeChange: (Float) -> Unit,
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
                popupHovered = false
                hideFlyoutWithDelay()
            },
        contentAlignment = Alignment.Center
    ) {
        if (showPopup) {
            Popup(
                offset = IntOffset(0, -30), // 向上偏移，根据需要调整
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
                    VolumeSliderFlyout(
                        isExpanded = isExpanded,
                        volume = volume,
                        onVolumeChange = onVolumeChange,
                        onAnimationFinished = {
                            if (!isExpanded) {
                                showPopup = false
                            }
                        }
                    )
                }
            }
        }
        var isPlaying by remember { mutableStateOf(false) }

        val volumeLevel = remember(volume) {
            when {
                volume > 0.5f -> 2
                volume > 0f -> 1
                else -> 0
            }
        }

        val highSpec = PlayerResourceManager.volumeHighSpec
        val lowSpec = PlayerResourceManager.volumeLowSpec
        val offSpec = PlayerResourceManager.volumeOffSpec

        val highComposition = if (highSpec != null) {
            val c by rememberLottieComposition { highSpec }
            c
        } else null

        val lowComposition = if (lowSpec != null) {
            val c by rememberLottieComposition { lowSpec }
            c
        } else null

        val offComposition = if (offSpec != null) {
            val c by rememberLottieComposition { offSpec }
            c
        } else null

        val composition = when (volumeLevel) {
            2 -> highComposition
            1 -> lowComposition
            else -> offComposition
        }

        LaunchedEffect(volumeLevel) {
            isPlaying = true
        }

//        var isPlaying by remember { mutableStateOf(false) }

        if (composition != null) {
            val progress by animateLottieCompositionAsState(
                composition = composition,
                isPlaying = isPlaying,
                iterations = 1,
                restartOnPlay = true
            )
            LaunchedEffect(progress) {
                if (progress == 1f && isPlaying) {
                    isPlaying = false
                }
            }

            Image(
                painter = rememberLottiePainter(composition, progress = { progress }),
                contentDescription = "音量",
//                    tint = Color.White,
                modifier = Modifier
//                    .padding(start = 12.dp)
                    .size(40.dp)
                    .onPointerEvent(PointerEventType.Enter) {
                        isPlaying = true
                    }
                    .onPointerEvent(PointerEventType.Exit) {
                        // isPlaying = false
                    },
                colorFilter = ColorFilter.tint(Color.White)
            )
        }
//        Icon(
//            imageVector = Volume,
//            contentDescription = "音量",
//            tint = Color.White,
//            modifier = Modifier.size(40.dp)
//        )
    }
}

@Composable
private fun VolumeSliderFlyout(
    isExpanded: Boolean,
    volume: Float,
    onVolumeChange: (Float) -> Unit,
    onAnimationFinished: () -> Unit
) {
    val alpha = remember { Animatable(0f) }
    val scale = remember { Animatable(0.4f) }
    val offsetY = remember { Animatable(0f) }

    LaunchedEffect(isExpanded) {
        if (isExpanded) {
            launch {
                alpha.animateTo(1f, tween(ANIMATION_DURATION_MS))
            }
            launch {
                scale.animateTo(1f, tween(ANIMATION_DURATION_MS))
            }
            launch {
                offsetY.animateTo(0f, tween(ANIMATION_DURATION_MS))
            }
        } else {
            launch {
                alpha.animateTo(0f, tween(ANIMATION_DURATION_MS))
            }
            launch {
                scale.animateTo(0.4f, tween(ANIMATION_DURATION_MS))
            }
            launch {
                offsetY.animateTo(10f, tween(ANIMATION_DURATION_MS))
            }
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
            modifier = Modifier.padding(bottom = 8.dp)
        ) {
            Column(
                modifier = Modifier
                    .width(40.dp)
                    .height(140.dp) // 调整高度
                    .padding(vertical = 12.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                // 显示当前音量百分比
                Text(
                    text = "${(volume * 100).roundToInt()}",
                    color = Color.White,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Bold
                )
                
                // 音量滑块
                Box(
                    modifier = Modifier
                        .width(30.dp)
                        .weight(1f)
                        .padding(vertical = 4.dp),
                    contentAlignment = Alignment.Center
                ) {
                    VerticalVolumeSlider(
                        volume = volume,
                        onVolumeChange = onVolumeChange
                    )
                }
                
                // 底部小喇叭图标 (可选)
//                Icon(
//                    imageVector = Volume,
//                    contentDescription = null,
//                    tint = Color.White.copy(alpha = 0.7f),
//                    modifier = Modifier.size(16.dp)
//                )
            }
        }
    }
}

@Composable
private fun VerticalVolumeSlider(
    volume: Float,
    onVolumeChange: (Float) -> Unit
) {
    val barWidth = 4.dp
    val thumbRadius = 6.dp
    
    // 交互逻辑
    Box(
        modifier = Modifier
            .fillMaxHeight()
            .width(20.dp) // 增加触摸区域宽度
            .pointerInput(Unit) {
                detectTapGestures { offset ->
                    val newVolume = (1f - offset.y / size.height).coerceIn(0f, 1f)
                    onVolumeChange(newVolume)
                }
            }
            .pointerInput(Unit) {
                detectDragGestures { change, _ ->
                    val newVolume = (1f - change.position.y / size.height).coerceIn(0f, 1f)
                    onVolumeChange(newVolume)
                    change.consume()
                }
            }
    ) {
        Canvas(
            modifier = Modifier.fillMaxSize()
        ) {
            val trackXCenter = size.width / 2
            val trackWidth = barWidth.toPx()
            
            // 1. 灰色背景 (未激活部分)
            drawLine(
                color = Color.White.copy(alpha = 0.3f),
                start = Offset(trackXCenter, 0f),
                end = Offset(trackXCenter, size.height),
                strokeWidth = trackWidth,
                cap = StrokeCap.Round
            )
            
            // 2. 蓝色激活进度
            val activeHeight = volume.coerceIn(0f, 1f) * size.height
            val activeStartY = size.height - activeHeight
            
            if (activeHeight > 0) {
                drawLine(
                    color = Color(0xFF3B82F6),
                    start = Offset(trackXCenter, size.height),
                    end = Offset(trackXCenter, activeStartY),
                    strokeWidth = trackWidth,
                    cap = StrokeCap.Round
                )
            }
            
            // 3. 白色圆形滑块
            drawCircle(
                color = Color.White,
                radius = thumbRadius.toPx(),
                center = Offset(trackXCenter, activeStartY)
            )
        }
    }
}
