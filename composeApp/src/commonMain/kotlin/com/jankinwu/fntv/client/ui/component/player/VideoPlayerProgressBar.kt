package com.jankinwu.fntv.client.ui.component.player

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.layout.layoutId
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.toSize
import com.jankinwu.fntv.client.data.convertor.FnDataConvertor
import org.openani.mediamp.MediampPlayer
import kotlin.math.roundToInt

private const val LAYOUT_ID_PROGRESS_BAR = "progressBar"
private const val LAYOUT_ID_TIMESTAMP = "timestamp"

@Composable
fun VideoPlayerProgressBar(
    player: MediampPlayer,
    totalDuration: Long,
    onSeek: (Float) -> Unit,
    modifier: Modifier = Modifier,
    introSegmentMillis: Pair<Long, Long>? = null,
    creditsSegmentMillis: Pair<Long, Long>? = null
) {
    // 获取当前播放位置
    val currentPosition by player.currentPositionMillis.collectAsState()

    // 计算显示的进度比例
    val displayPositionRatio by remember {
        derivedStateOf {
            val total = totalDuration
            if (total == 0L) {
                0f
            } else {
                currentPosition.toFloat() / total
            }
        }
    }
    
    val introRangeRatio = remember(introSegmentMillis, totalDuration) {
        if (totalDuration <= 0L) return@remember null
        val segment = introSegmentMillis ?: return@remember null
        val start = segment.first.coerceAtLeast(0L)
        val end = segment.second.coerceAtMost(totalDuration)
        if (end <= start) return@remember null
        (start.toFloat() / totalDuration) to (end.toFloat() / totalDuration)
    }

    val creditsRangeRatio = remember(creditsSegmentMillis, totalDuration) {
        if (totalDuration <= 0L) return@remember null
        val segment = creditsSegmentMillis ?: return@remember null
        val start = segment.first.coerceAtLeast(0L).coerceAtMost(totalDuration)
        val end = segment.second.coerceAtLeast(0L).coerceAtMost(totalDuration)
        if (end <= start) return@remember null
        (start.toFloat() / totalDuration) to (end.toFloat() / totalDuration)
    }

    // 其余部分保持不变，只是将 progress 参数替换为 displayPositionRatio
    VideoPlayerProgressBarImpl(
        progress = displayPositionRatio,
        buffered = 0f, // 如果需要缓冲进度，可以类似处理
        totalDuration = totalDuration,
        onSeek = onSeek,
        modifier = modifier,
        introRangeRatio = introRangeRatio,
        creditsRangeRatio = creditsRangeRatio
    )
}

/**
 * 视频播放器进度条组件
 *
 * @param progress 当前播放进度，范围从 0.0f 到 1.0f.
 * @param buffered 视频缓冲进度，范围从 0.0f 到 1.0f.
 * @param totalDuration 视频总时长，单位为毫秒.
 * @param onSeek 当用户通过点击或拖动来改变进度时调用的回调函数.
 * @param modifier Modifier 应用于此组件.
 */
@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun VideoPlayerProgressBarImpl(
    progress: Float,
    buffered: Float,
    totalDuration: Long,
    onSeek: (Float) -> Unit,
    modifier: Modifier = Modifier,
    introRangeRatio: Pair<Float, Float>? = null,
    creditsRangeRatio: Pair<Float, Float>? = null
) {
    var isHovered by remember { mutableStateOf(false) }
    var isDragging by remember { mutableStateOf(false) }
    // 使用 state 来存储鼠标悬停的X坐标位置
    var hoverPositionX by remember { mutableFloatStateOf(0f) }

    // 当鼠标悬停或用户正在拖动时，显示更丰富的UI（粗进度条、滑块、时间戳）
    val showDetails = isHovered || isDragging
    var layoutSize by remember { mutableStateOf(Size.Zero) }

    Box(
        modifier = modifier
            .fillMaxWidth()
            .onPointerEvent(PointerEventType.Enter) { isHovered = true }
            .onPointerEvent(PointerEventType.Exit) { isHovered = false }
            .onPointerEvent(PointerEventType.Move) { event ->
                hoverPositionX = event.changes.first().position.x
            }
            .pointerInput(Unit) {
                // 处理点击跳转
                detectTapGestures { offset ->
                    val newProgress = (offset.x / size.width).coerceIn(0f, 1f)
                    onSeek(newProgress)
                }
            }
            .pointerInput(Unit) {
                // 处理拖动
                detectDragGestures(
                    onDragStart = { isDragging = true },
                    onDragEnd = { isDragging = false },
                    onDragCancel = { isDragging = false }
                ) { change, _ ->
                    val newProgress = (change.position.x / size.width).coerceIn(0f, 1f)
                    onSeek(newProgress)
                    change.consume()
                }
            }
            .padding(vertical = 4.dp)
    ) {
        // 使用自定义Layout来精确控制时间戳和进度条的位置
        Layout(
            content = {
                // --- 进度条 ---
                val barHeight: Dp = if (showDetails) 6.dp else 3.dp
                val thumbRadius: Dp = if (showDetails) 8.dp else 0.dp

                Canvas(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(barHeight)
                        .layoutId(LAYOUT_ID_PROGRESS_BAR)
                        .onGloballyPositioned { coordinates ->
                            layoutSize = coordinates.size.toSize()
                        }
                ) {
                    val trackYCenter = center.y
                    val trackStrokeWidth = size.height

                    // 1. 灰色背景 (未播放部分)
                    drawLine(
                        color = Color.White.copy(alpha = 0.3f),
                        start = Offset(0f, trackYCenter),
                        end = Offset(size.width, trackYCenter),
                        strokeWidth = trackStrokeWidth,
                        cap = StrokeCap.Round
                    )

                    val introColor = Color(0xFF22C55E).copy(alpha = 0.45f)
                    val creditsColor = Color(0xFF22C55E).copy(alpha = 0.45f)

                    fun drawSegment(range: Pair<Float, Float>, color: Color) {
                        val startX = (range.first.coerceIn(0f, 1f) * size.width)
                        val endX = (range.second.coerceIn(0f, 1f) * size.width)
                        if (endX <= startX) return
                        drawLine(
                            color = color,
                            start = Offset(startX, trackYCenter),
                            end = Offset(endX, trackYCenter),
                            strokeWidth = trackStrokeWidth,
                            cap = StrokeCap.Butt
                        )
                    }

                    introRangeRatio?.let { drawSegment(it, introColor) }
                    creditsRangeRatio?.let { drawSegment(it, creditsColor) }

                    // 2. 浅灰色缓冲进度
                    val bufferedEndX = buffered.coerceIn(0f, 1f) * size.width
                    if (bufferedEndX > 0) {
                        drawLine(
                            color = Color.White.copy(alpha = 0.6f),
                            start = Offset(0f, trackYCenter),
                            end = Offset(bufferedEndX, trackYCenter),
                            strokeWidth = trackStrokeWidth,
                            cap = StrokeCap.Round
                        )
                    }

                    // 3. 蓝色播放进度
                    val activeEndX = progress.coerceIn(0f, 1f) * size.width
                    if (activeEndX > 0) {
                        drawLine(
                            color = Color(0xFF3B82F6), // 鲜艳的蓝色
                            start = Offset(0f, trackYCenter),
                            end = Offset(activeEndX, trackYCenter),
                            strokeWidth = trackStrokeWidth,
                            cap = StrokeCap.Round
                        )
                    }

                    val markerXList = mutableListOf<Float>()
                    introRangeRatio?.let { range ->
                        val startX = range.first.coerceIn(0f, 1f) * size.width
                        val endX = range.second.coerceIn(0f, 1f) * size.width
                        if (endX > startX) {
                            markerXList.add(startX)
                            markerXList.add(endX)
                        }
                    }
                    creditsRangeRatio?.let { range ->
                        val startX = range.first.coerceIn(0f, 1f) * size.width
                        val endX = range.second.coerceIn(0f, 1f) * size.width
                        if (endX > startX) {
                            markerXList.add(startX)
                            markerXList.add(endX)
                        }
                    }

                    markerXList.forEach { x ->
                        if (showDetails) {
                            // When expanded, draw a vertical line
                            drawLine(
                                color = Color.White,
                                start = Offset(x, 0f),
                                end = Offset(x, size.height),
                                strokeWidth = 2.dp.toPx()
                            )
                        } else {
                            // When collapsed, draw a small dot
                            drawCircle(
                                color = Color.White,
                                radius = 1.dp.toPx(),
                                center = Offset(x, trackYCenter)
                            )
                        }
                    }

                    // 4. 白色的圆形滑块 (仅在悬停或拖动时显示)
                    if (showDetails) {
                        drawCircle(
                            color = Color.White,
                            radius = thumbRadius.toPx() / 2,
                            center = Offset(activeEndX, trackYCenter)
                        )
                    }
                }

                // --- 悬停时的时间戳 ---
                if (showDetails) {
                    val hoverProgress = (hoverPositionX / layoutSize.width).coerceIn(0f, 1f)
                    val hoverTimeMillis = (hoverProgress * totalDuration).toLong()
                    Text(
                        text = FnDataConvertor.formatDurationToDateTime(hoverTimeMillis),
                        color = Color.White,
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Medium,
                        style = TextStyle.Default.copy(
                            shadow = Shadow(
                                color = Color.Black.copy(alpha = 0.5f),
                                offset = Offset(1f, 1f),
                                blurRadius = 2f
                            )
                        ),
                        modifier = Modifier.layoutId(LAYOUT_ID_TIMESTAMP)
                    )
                }
            }
        ) { measurables, constraints ->
            val progressBarPlaceable = measurables.firstOrNull { it.layoutId == LAYOUT_ID_PROGRESS_BAR }
                ?.measure(constraints)
            val timestampPlaceable = measurables.firstOrNull { it.layoutId == LAYOUT_ID_TIMESTAMP }
                ?.measure(constraints.copy(minWidth = 0, minHeight = 0))

            val progressBarHeight = progressBarPlaceable?.height ?: 0
            val timestampHeight = timestampPlaceable?.height ?: 0
            val timestampWidth = timestampPlaceable?.width ?: 0

            // 总高度为进度条高度 + 时间戳高度 + 间距
            val totalHeight = progressBarHeight + timestampHeight + if (showDetails) 8.dp.roundToPx() else 0

            layout(constraints.maxWidth, totalHeight) {
                // 将进度条放置在底部
                progressBarPlaceable?.placeRelative(0, totalHeight - progressBarHeight)

                // 将时间戳放置在进度条上方，并根据鼠标位置水平居中
                if (timestampPlaceable != null) {
                    // 计算时间戳的X坐标，使其中心与鼠标指针位置对齐
                    val timestampX = (hoverPositionX - timestampWidth / 2)
                        // 确保时间戳不会超出左右边界
                        .coerceIn(0f, (constraints.maxWidth - timestampWidth).toFloat())
                        .roundToInt()
                    timestampPlaceable.placeRelative(timestampX, 0)
                }
            }
        }
    }
}
