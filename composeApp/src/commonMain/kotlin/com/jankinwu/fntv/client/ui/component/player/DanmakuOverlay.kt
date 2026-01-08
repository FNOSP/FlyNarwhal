package com.jankinwu.fntv.client.ui.component.player

import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.data.model.response.Danmaku
import kotlin.math.max
import kotlin.math.roundToLong

@Composable
fun DanmakuOverlay(
    danmakuList: List<Danmaku>,
    currentTime: Long, // in millis
    isVisible: Boolean
) {
    if (!isVisible) return

    BoxWithConstraints(modifier = Modifier.fillMaxSize().clipToBounds()) {
        val density = LocalDensity.current
        val widthPx = with(density) { maxWidth.toPx() }
        val heightPx = with(density) { maxHeight.toPx() }

        val durationMillis = 10_000L
        val trackHeightPx = with(density) { 30.dp.toPx() }
        val paddingTopPx = with(density) { 10.dp.toPx() }
        val gapPx = with(density) { 16.dp.toPx() }
        val trackCount = max(1, ((heightPx - paddingTopPx) / trackHeightPx).toInt())

        val baseTextStyle = remember {
            TextStyle(
                fontSize = 20.sp,
                shadow = Shadow(
                    color = Color.Black,
                    offset = Offset(2f, 2f),
                    blurRadius = 4f
                )
            )
        }
        val measureTextStyle = remember(baseTextStyle) { baseTextStyle.copy(color = Color.White) }
        val textMeasurer = rememberTextMeasurer()

        val extraTravelPx = max(48f, widthPx * 0.15f)
        val startX = widthPx + extraTravelPx
        val travelX = (2f * widthPx) + (2f * extraTravelPx)
        val speedPxPerMs = if (durationMillis > 0) travelX / durationMillis.toFloat() else 0f

        val allocator = remember(danmakuList, trackCount, maxWidth, maxHeight, density.density) {
            DanmakuTrackAllocator(
                items = danmakuList.map { danmaku ->
                    val startTimeMillis = (danmaku.time * 1000.0).toLong()
                    DanmakuAllocItem(
                        danmaku = danmaku,
                        startTimeMillis = startTimeMillis,
                        color = parseColor(danmaku.color)
                    )
                }.sortedBy { it.startTimeMillis },
                trackCount = trackCount,
                speedPxPerMs = speedPxPerMs,
                gapPx = gapPx,
                warmupWindowMillis = durationMillis + 2_000L
            )
        }

        allocator.ensureAllocatedUpTo(
            currentTimeMillis = currentTime,
            textMeasurer = textMeasurer,
            textStyle = measureTextStyle
        )

        val visibleIndices = remember(allocator.startTimesMillis, currentTime) {
            computeVisibleRange(
                startTimesMillis = allocator.startTimesMillis,
                currentTimeMillis = currentTime,
                durationMillis = durationMillis
            )
        }

        for (i in visibleIndices.first until visibleIndices.last) {
            val preparedDanmaku = allocator.items[i]
            val elapsed = currentTime - preparedDanmaku.startTimeMillis
            if (elapsed < 0L || elapsed >= durationMillis) continue
            val progress = (elapsed.toFloat() / durationMillis.toFloat()).coerceIn(0f, 1f)
            val x = startX - (travelX * progress)
            val trackIndex = preparedDanmaku.trackIndex.coerceIn(0, trackCount - 1)
            val y = paddingTopPx + (trackHeightPx * trackIndex.toFloat())

            Text(
                text = preparedDanmaku.danmaku.text,
                style = baseTextStyle.copy(color = preparedDanmaku.color),
                maxLines = 1,
                overflow = TextOverflow.Visible,
                modifier = Modifier
                    .layout { measurable, constraints ->
                        val placeable = measurable.measure(constraints)
                        layout(placeable.width, placeable.height) {
                            placeable.place(0, 0)
                        }
                    }
                    .graphicsLayer {
                        translationX = x
                        translationY = y
                    }
            )
        }
    }
}

private class DanmakuTrackAllocator(
    val items: List<DanmakuAllocItem>,
    trackCount: Int,
    private val speedPxPerMs: Float,
    private val gapPx: Float,
    private val warmupWindowMillis: Long
) {
    val startTimesMillis: LongArray = LongArray(items.size) { idx -> items[idx].startTimeMillis }
    private val trackAvailableAtMillis: LongArray = LongArray(trackCount) { Long.MIN_VALUE }
    private var allocatedUntilIndex: Int = 0
    private var lastAllocatedTimeMillis: Long = Long.MIN_VALUE

    fun ensureAllocatedUpTo(
        currentTimeMillis: Long,
        textMeasurer: androidx.compose.ui.text.TextMeasurer,
        textStyle: TextStyle
    ) {
        if (lastAllocatedTimeMillis != Long.MIN_VALUE && currentTimeMillis + 500 < lastAllocatedTimeMillis) {
            reset()
        }
        if (allocatedUntilIndex == 0 && currentTimeMillis > warmupWindowMillis) {
            val startIndex = startTimesMillis.lowerBound(currentTimeMillis - warmupWindowMillis)
            allocatedUntilIndex = startIndex
        }
        lastAllocatedTimeMillis = currentTimeMillis

        while (allocatedUntilIndex < items.size) {
            val item = items[allocatedUntilIndex]
            if (item.startTimeMillis > currentTimeMillis) break

            val textWidthPx = item.textWidthPx ?: run {
                val layout = textMeasurer.measure(
                    text = AnnotatedString(item.danmaku.text),
                    style = textStyle,
                    maxLines = 1
                )
                layout.size.width.toFloat().also { item.textWidthPx = it }
            }

            val chosenTrack = chooseTrack(item.startTimeMillis)
            item.trackIndex = chosenTrack
            trackAvailableAtMillis[chosenTrack] = computeAvailableAtMillis(item.startTimeMillis, textWidthPx)
            allocatedUntilIndex++
        }
    }

    private fun chooseTrack(startTimeMillis: Long): Int {
        var bestTrack = 0
        var bestAvailableAt = trackAvailableAtMillis[0]
        if (startTimeMillis >= bestAvailableAt) return 0

        for (t in 1 until trackAvailableAtMillis.size) {
            val availableAt = trackAvailableAtMillis[t]
            if (startTimeMillis >= availableAt) return t
            if (availableAt < bestAvailableAt) {
                bestAvailableAt = availableAt
                bestTrack = t
            }
        }
        return bestTrack
    }

    private fun computeAvailableAtMillis(startTimeMillis: Long, textWidthPx: Float): Long {
        if (speedPxPerMs <= 0f) return startTimeMillis
        val requiredDeltaMs = ((textWidthPx + gapPx) / speedPxPerMs).roundToLong().coerceAtLeast(0L)
        return startTimeMillis + requiredDeltaMs
    }

    private fun reset() {
        allocatedUntilIndex = 0
        for (i in trackAvailableAtMillis.indices) {
            trackAvailableAtMillis[i] = Long.MIN_VALUE
        }
    }
}

private data class DanmakuAllocItem(
    val danmaku: Danmaku,
    val startTimeMillis: Long,
    val color: Color,
    var trackIndex: Int = 0,
    var textWidthPx: Float? = null
)

private data class IntRangeHalfOpen(
    val first: Int,
    val last: Int
)

private fun computeVisibleRange(
    startTimesMillis: LongArray,
    currentTimeMillis: Long,
    durationMillis: Long
): IntRangeHalfOpen {
    if (startTimesMillis.isEmpty()) return IntRangeHalfOpen(0, 0)

    val windowStart = currentTimeMillis - durationMillis
    val start = startTimesMillis.lowerBound(windowStart)
    val endExclusive = startTimesMillis.upperBound(currentTimeMillis)
    return IntRangeHalfOpen(first = start, last = max(start, endExclusive))
}

private fun LongArray.lowerBound(value: Long): Int {
    var low = 0
    var high = size
    while (low < high) {
        val mid = (low + high) ushr 1
        if (this[mid] < value) low = mid + 1 else high = mid
    }
    return low
}

private fun LongArray.upperBound(value: Long): Int {
    var low = 0
    var high = size
    while (low < high) {
        val mid = (low + high) ushr 1
        if (this[mid] <= value) low = mid + 1 else high = mid
    }
    return low
}

fun parseColor(colorString: String): Color {
    return try {
        if (colorString.startsWith("#")) {
            val hex = colorString.substring(1)
            when (hex.length) {
                3 -> {
                    val r = hex[0].toString().repeat(2)
                    val g = hex[1].toString().repeat(2)
                    val b = hex[2].toString().repeat(2)
                    Color("FF$r$g$b".toLong(16))
                }
                6 -> Color("FF$hex".toLong(16))
                8 -> Color(hex.toLong(16))
                else -> Color.White
            }
        } else {
            Color.White
        }
    } catch (e: Exception) {
        Color.White
    }
}
