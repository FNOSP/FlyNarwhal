package com.jankinwu.fntv.client.ui.component.player

import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.jankinwu.fntv.client.data.model.response.Danmaku
import kotlinx.coroutines.isActive
import kotlin.math.max

private const val BASE_DURATION_AT_1X_MILLIS = 16_000L
private const val FIXED_DURATION_MILLIS = 5_000L
private const val MIN_PLAYBACK_SPEED_FOR_OVERLAP = 0.5f
private const val NEGATIVE_MEDIA_JITTER_TOLERANCE_MILLIS = 200L
private const val DEBUG_MAX_LINES = 10

@Composable
fun DanmakuOverlay(
    danmakuList: List<Danmaku>,
    currentTime: Long, // in millis
    isPlaying: Boolean,
    playbackSpeed: Float,
    isVisible: Boolean,
    area: Float = 1.0f,
    opacity: Float = 1.0f,
    fontSize: Float = 1.0f,
    speed: Float = 1.0f,
    syncPlaybackSpeed: Boolean = false,
    resetNonce: Int = 0,
    debugEnabled: Boolean = false
) {
    if (!isVisible) return

    BoxWithConstraints(modifier = Modifier.fillMaxSize().clipToBounds()) {
        val density = LocalDensity.current
        val widthPx = with(density) { maxWidth.toPx() }
        val heightPx = with(density) { maxHeight.toPx() }

        val effectiveFontSize = fontSize.coerceIn(0.5f, 1.7f)
        val trackHeightPx = with(density) { (30.dp * effectiveFontSize).toPx() }
        val paddingTopPx = with(density) { 10.dp.toPx() }
        val paddingBottomPx = with(density) { 10.dp.toPx() }
        val gapPx = with(density) { 16.dp.toPx() }

        val scrollRegionHeightPx = heightPx * area.coerceIn(0.1f, 1.0f)
        val scrollTrackCount = max(1, ((scrollRegionHeightPx - paddingTopPx) / trackHeightPx).toInt())

        val fixedRegionHeightPx = heightPx / 2f
        val topTrackCount = max(1, ((fixedRegionHeightPx - paddingTopPx) / trackHeightPx).toInt())
        val bottomTrackCount = max(1, ((fixedRegionHeightPx - paddingBottomPx) / trackHeightPx).toInt())

        fun textStyleFor(scale: Float, color: Color): TextStyle {
            return TextStyle(
                fontSize = (20 * scale).sp,
                color = color
            )
        }
        val measureTextStyle = remember(effectiveFontSize) { textStyleFor(effectiveFontSize, Color.White) }
        val textMeasurer = rememberTextMeasurer()

        val extraTravelPx = max(48f, widthPx * 0.15f)
        val startX = widthPx + extraTravelPx
        val startXReverse = -widthPx - extraTravelPx
        val travelX = (2f * widthPx) + (2f * extraTravelPx)

        val danmakuListSignature = run {
            val first = danmakuList.firstOrNull()
            val last = danmakuList.lastOrNull()
            "${danmakuList.size}|${first?.time}|${first?.text}|${last?.time}|${last?.text}"
        }

        val preparedItems = remember(danmakuListSignature) {
            val sorted = danmakuList
                .asSequence()
                .map { danmaku ->
                    PreparedDanmaku(
                        danmaku = danmaku,
                        startTimeMillis = (danmaku.time * 1000.0).toLong(),
                        color = parseColor(danmaku.color)
                    )
                }
                .sortedWith(compareBy<PreparedDanmaku> { it.startTimeMillis }.thenBy { it.danmaku.text })
                .toList()

            val dupCounter = HashMap<String, Int>(sorted.size)
            sorted.map { item ->
                val baseKey = "${item.startTimeMillis}|${item.danmaku.text}|${item.danmaku.color}|${item.danmaku.mode}|${item.danmaku.border}"
                val idx = (dupCounter[baseKey] ?: 0).also { dupCounter[baseKey] = it + 1 }
                item.copy(key = "$baseKey|$idx")
            }
        }

        val preparedStartTimesMillis = remember(preparedItems) {
            LongArray(preparedItems.size) { idx -> preparedItems[idx].startTimeMillis }
        }

        val preparedItemsState = rememberUpdatedState(preparedItems)
        val preparedStartTimesMillisState = rememberUpdatedState(preparedStartTimesMillis)

        val debugEnabledState = rememberUpdatedState(debugEnabled)
        val activeItems = remember { mutableStateListOf<ActiveDanmaku>() }
        val debugLines = remember { mutableStateListOf<String>() }
        fun pushDebug(line: String) {
            if (!debugEnabledState.value) return
            debugLines.add(line)
            while (debugLines.size > DEBUG_MAX_LINES) {
                debugLines.removeAt(0)
            }
        }

        var nextSpawnIndex by remember { mutableStateOf(0) }
        var lastMediaTimeMillis by remember { mutableStateOf<Long?>(null) }
        var lastFrameTimeNanos by remember { mutableStateOf<Long?>(null) }
        var realPlayheadNanos by remember { mutableStateOf(0L) }
        var scrollTrackAvailableAtNanos by remember { mutableStateOf(LongArray(scrollTrackCount) { Long.MIN_VALUE }) }
        var reverseTrackAvailableAtNanos by remember { mutableStateOf(LongArray(scrollTrackCount) { Long.MIN_VALUE }) }
        var topTrackAvailableAtNanos by remember { mutableStateOf(LongArray(topTrackCount) { Long.MIN_VALUE }) }
        var bottomTrackAvailableAtNanos by remember { mutableStateOf(LongArray(bottomTrackCount) { Long.MIN_VALUE }) }

        var debugMessage by remember { mutableStateOf<String?>(null) }
        var debugMessageAtFrameNanos by remember { mutableStateOf(0L) }
        var latestFrameNanos by remember { mutableStateOf(0L) }
        var lastAppliedResetNonce by remember { mutableStateOf(resetNonce) }
        var lastPlayingNow by remember { mutableStateOf<Boolean?>(null) }

        val currentTimeState = rememberUpdatedState(currentTime)
        val speedState = rememberUpdatedState(speed)
        val gapPxState = rememberUpdatedState(gapPx)
        val travelXState = rememberUpdatedState(travelX)
        val opacityState = rememberUpdatedState(opacity.coerceIn(0f, 1f))
        val trackHeightPxState = rememberUpdatedState(trackHeightPx)
        val fontSizeState = rememberUpdatedState(effectiveFontSize)
        val measureTextStyleState = rememberUpdatedState(measureTextStyle)
        val syncPlaybackSpeedState = rememberUpdatedState(syncPlaybackSpeed)
        val isPlayingState = rememberUpdatedState(isPlaying)
        val playbackSpeedState = rememberUpdatedState(playbackSpeed)
        val resetNonceState = rememberUpdatedState(resetNonce)
        val scrollTrackCountState = rememberUpdatedState(scrollTrackCount)
        val topTrackCountState = rememberUpdatedState(topTrackCount)
        val bottomTrackCountState = rememberUpdatedState(bottomTrackCount)

        LaunchedEffect(danmakuListSignature) {
            val mediaTimeMillis = currentTimeState.value
            activeItems.clear()
            nextSpawnIndex = preparedStartTimesMillis.lowerBound(mediaTimeMillis)
            scrollTrackAvailableAtNanos = LongArray(scrollTrackCountState.value) { Long.MIN_VALUE }
            reverseTrackAvailableAtNanos = LongArray(scrollTrackCountState.value) { Long.MIN_VALUE }
            topTrackAvailableAtNanos = LongArray(topTrackCountState.value) { Long.MIN_VALUE }
            bottomTrackAvailableAtNanos = LongArray(bottomTrackCountState.value) { Long.MIN_VALUE }
            realPlayheadNanos = 0L
            lastMediaTimeMillis = null
            lastFrameTimeNanos = null
            if(debugEnabledState.value) {
                debugMessage = "LIST_UPDATED size=${preparedItems.size} next=$nextSpawnIndex"
                debugMessageAtFrameNanos = latestFrameNanos
                pushDebug("LIST_UPDATED media=$mediaTimeMillis size=${preparedItems.size}")
            }
        }

        LaunchedEffect(scrollTrackCount, topTrackCount, bottomTrackCount) {
            val nowNanos = realPlayheadNanos
            val rebuiltScroll = LongArray(scrollTrackCount) { Long.MIN_VALUE }
            val rebuiltReverse = LongArray(scrollTrackCount) { Long.MIN_VALUE }
            val rebuiltTop = LongArray(topTrackCount) { Long.MIN_VALUE }
            val rebuiltBottom = LongArray(bottomTrackCount) { Long.MIN_VALUE }

            for (item in activeItems) {
                val availableAt = max(item.availableAtRealNanos, nowNanos)
                when (item.kind) {
                    DanmakuKind.Scroll -> {
                        val t = item.trackIndex
                        if (t in 0 until scrollTrackCount) {
                            rebuiltScroll[t] = max(rebuiltScroll[t], availableAt)
                        }
                    }
                    DanmakuKind.Reverse -> {
                        val t = item.trackIndex
                        if (t in 0 until scrollTrackCount) {
                            rebuiltReverse[t] = max(rebuiltReverse[t], availableAt)
                        }
                    }
                    DanmakuKind.Top -> {
                        val t = item.trackIndex
                        if (t in 0 until topTrackCount) {
                            rebuiltTop[t] = max(rebuiltTop[t], availableAt)
                        }
                    }
                    DanmakuKind.Bottom -> {
                        val t = item.trackIndex
                        if (t in 0 until bottomTrackCount) {
                            rebuiltBottom[t] = max(rebuiltBottom[t], availableAt)
                        }
                    }
                }
            }

            scrollTrackAvailableAtNanos = rebuiltScroll
            reverseTrackAvailableAtNanos = rebuiltReverse
            topTrackAvailableAtNanos = rebuiltTop
            bottomTrackAvailableAtNanos = rebuiltBottom
        }

        LaunchedEffect(Unit) {
            while (isActive) {
                var frameTimeNanos = 0L
                withFrameNanos { now -> frameTimeNanos = now }
                latestFrameNanos = frameTimeNanos

                val preparedItemsSnapshot = preparedItemsState.value
                val preparedStartTimesSnapshot = preparedStartTimesMillisState.value
                val mediaTimeMillis = currentTimeState.value
                val resetValue = resetNonceState.value
                if (resetValue != lastAppliedResetNonce) {
                    if (debugEnabledState.value) {
                        debugMessage = "RESET_SIGNAL value=$resetValue active=${activeItems.size}"
                        debugMessageAtFrameNanos = frameTimeNanos
                    }
                    activeItems.clear()
                    nextSpawnIndex = preparedStartTimesSnapshot.lowerBound(mediaTimeMillis)
                    scrollTrackAvailableAtNanos = LongArray(scrollTrackCountState.value) { Long.MIN_VALUE }
                    reverseTrackAvailableAtNanos = LongArray(scrollTrackCountState.value) { Long.MIN_VALUE }
                    topTrackAvailableAtNanos = LongArray(topTrackCountState.value) { Long.MIN_VALUE }
                    bottomTrackAvailableAtNanos = LongArray(bottomTrackCountState.value) { Long.MIN_VALUE }
                    realPlayheadNanos = 0L
                    lastMediaTimeMillis = null
                    lastFrameTimeNanos = null
                    lastAppliedResetNonce = resetValue
                    if (debugEnabledState.value) {
                        pushDebug("CLEAR resetNonce=$resetValue media=$mediaTimeMillis")
                    }
                    continue
                }

                val lastMediaTime = lastMediaTimeMillis
                val lastFrameTime = lastFrameTimeNanos
                if (lastMediaTime == null) {
                    lastMediaTimeMillis = mediaTimeMillis
                    continue
                }
                if (lastFrameTime == null) {
                    lastFrameTimeNanos = frameTimeNanos
                    lastMediaTimeMillis = mediaTimeMillis
                    continue
                }

                val deltaMediaMillis = mediaTimeMillis - lastMediaTime
                val deltaRealNanos = frameTimeNanos - lastFrameTime
                lastFrameTimeNanos = frameTimeNanos
                lastMediaTimeMillis = mediaTimeMillis

                if (deltaRealNanos <= 0L) {
                    continue
                }

                val playingNow = isPlayingState.value
                if ((lastPlayingNow == null || lastPlayingNow != playingNow) && debugEnabledState.value) {
                    lastPlayingNow = playingNow
                    pushDebug("PLAY_STATE playing=$playingNow media=$mediaTimeMillis")
                }

                val absDeltaMediaMillis = kotlin.math.abs(deltaMediaMillis)
                val deltaRealMillisF = deltaRealNanos.toFloat() / 1_000_000f

                val shouldClearForJump = if (playingNow) {
                    deltaMediaMillis < -NEGATIVE_MEDIA_JITTER_TOLERANCE_MILLIS || absDeltaMediaMillis > 3_000L
                } else {
                    absDeltaMediaMillis > 3_000L
                }
                if (shouldClearForJump) {
                    activeItems.clear()
                    nextSpawnIndex = preparedStartTimesSnapshot.lowerBound(mediaTimeMillis)
                    scrollTrackAvailableAtNanos = LongArray(scrollTrackCountState.value) { Long.MIN_VALUE }
                    reverseTrackAvailableAtNanos = LongArray(scrollTrackCountState.value) { Long.MIN_VALUE }
                    topTrackAvailableAtNanos = LongArray(topTrackCountState.value) { Long.MIN_VALUE }
                    bottomTrackAvailableAtNanos = LongArray(bottomTrackCountState.value) { Long.MIN_VALUE }
                    realPlayheadNanos = 0L
                    lastMediaTimeMillis = mediaTimeMillis
                    lastFrameTimeNanos = frameTimeNanos
                    if (debugEnabledState.value) {
                        pushDebug("CLEAR jump dMedia=$deltaMediaMillis abs=$absDeltaMediaMillis playing=$playingNow media=$mediaTimeMillis")
                    }
                    continue
                }

                val nowRealNanos = if (playingNow) {
                    val next = realPlayheadNanos + deltaRealNanos
                    realPlayheadNanos = next
                    next
                } else {
                    realPlayheadNanos
                }
                val currentPlaybackSpeed = playbackSpeedState.value.coerceIn(0.1f, 16.0f)

                val speedValue = speedState.value.coerceIn(0.1f, 10f)
                val durationMillis = (BASE_DURATION_AT_1X_MILLIS / speedValue).toLong().coerceAtLeast(1L)
                val speedPxPerMs = travelXState.value / durationMillis.toFloat()

                var localNextIndex = nextSpawnIndex
                var localScrollTrackAvailableAtNanos = scrollTrackAvailableAtNanos
                var localReverseTrackAvailableAtNanos = reverseTrackAvailableAtNanos
                var localTopTrackAvailableAtNanos = topTrackAvailableAtNanos
                var localBottomTrackAvailableAtNanos = bottomTrackAvailableAtNanos

                while (localNextIndex < preparedItemsSnapshot.size && preparedItemsSnapshot[localNextIndex].startTimeMillis <= mediaTimeMillis) {
                    val prepared = preparedItemsSnapshot[localNextIndex]
                    val layout = textMeasurer.measure(
                        text = androidx.compose.ui.text.AnnotatedString(prepared.danmaku.text),
                        style = measureTextStyleState.value,
                        maxLines = 1
                    )
                    val textWidthPx = layout.size.width.toFloat()

                    val kind = resolveDanmakuKind(prepared.danmaku.mode)
                    val trackAvailable = when (kind) {
                        DanmakuKind.Scroll -> localScrollTrackAvailableAtNanos
                        DanmakuKind.Reverse -> localReverseTrackAvailableAtNanos
                        DanmakuKind.Top -> localTopTrackAvailableAtNanos
                        DanmakuKind.Bottom -> localBottomTrackAvailableAtNanos
                    }
                    val trackCount = trackAvailable.size

                    if (trackCount <= 0) break

                    var chosenTrack = 0
                    var chosenStartRealNanos = max(nowRealNanos, trackAvailable[0])
                    for (t in 1 until trackCount) {
                        val startNanos = max(nowRealNanos, trackAvailable[t])
                        if (startNanos < chosenStartRealNanos) {
                            chosenStartRealNanos = startNanos
                            chosenTrack = t
                        }
                    }

                    val itemSyncPlaybackSpeed = syncPlaybackSpeedState.value

                    val requiredDeltaPlayheadNanos = when (kind) {
                        DanmakuKind.Top, DanmakuKind.Bottom -> FIXED_DURATION_MILLIS * 1_000_000L
                        DanmakuKind.Scroll, DanmakuKind.Reverse -> computeRequiredDeltaNanos(
                            textWidthPx = textWidthPx,
                            gapPx = gapPxState.value,
                            speedPxPerMs = speedPxPerMs
                        )
                    }
                    val requiredDeltaRealNanos = if (itemSyncPlaybackSpeed) {
                        val denom = max(currentPlaybackSpeed, MIN_PLAYBACK_SPEED_FOR_OVERLAP)
                        (requiredDeltaPlayheadNanos.toDouble() / denom.toDouble()).toLong()
                    } else {
                        requiredDeltaPlayheadNanos
                    }

                    val availableAtRealNanos = chosenStartRealNanos + requiredDeltaRealNanos
                    when (kind) {
                        DanmakuKind.Scroll -> {
                            localScrollTrackAvailableAtNanos =
                                localScrollTrackAvailableAtNanos.copyOf().also { it[chosenTrack] = availableAtRealNanos }
                        }
                        DanmakuKind.Reverse -> {
                            localReverseTrackAvailableAtNanos =
                                localReverseTrackAvailableAtNanos.copyOf().also { it[chosenTrack] = availableAtRealNanos }
                        }
                        DanmakuKind.Top -> {
                            localTopTrackAvailableAtNanos =
                                localTopTrackAvailableAtNanos.copyOf().also { it[chosenTrack] = availableAtRealNanos }
                        }
                        DanmakuKind.Bottom -> {
                            localBottomTrackAvailableAtNanos =
                                localBottomTrackAvailableAtNanos.copyOf().also { it[chosenTrack] = availableAtRealNanos }
                        }
                    }

                    val itemOpacity = opacityState.value
                    val itemFontSizeScale = fontSizeState.value
                    val itemTrackHeightPx = trackHeightPxState.value
                    val initialX = when (kind) {
                        DanmakuKind.Scroll -> startX
                        DanmakuKind.Reverse -> startXReverse
                        DanmakuKind.Top, DanmakuKind.Bottom -> (widthPx - textWidthPx) / 2f
                    }
                    val fixedRemainingMillis = when (kind) {
                        DanmakuKind.Top, DanmakuKind.Bottom -> FIXED_DURATION_MILLIS.toFloat()
                        DanmakuKind.Scroll, DanmakuKind.Reverse -> -1f
                    }

                    activeItems.add(
                        ActiveDanmaku(
                            key = prepared.key,
                            danmaku = prepared.danmaku,
                            color = prepared.color,
                            kind = kind,
                            trackIndex = chosenTrack,
                            startRealNanos = chosenStartRealNanos,
                            xPx = initialX,
                            baseSpeedPxPerMs = speedPxPerMs,
                            textWidthPx = textWidthPx,
                            availableAtRealNanos = availableAtRealNanos,
                            opacity = itemOpacity,
                            fontSizeScale = itemFontSizeScale,
                            trackHeightPx = itemTrackHeightPx,
                            syncPlaybackSpeed = itemSyncPlaybackSpeed,
                            remainingMillis = fixedRemainingMillis
                        )
                    )
                    localNextIndex++
                }

                if (localNextIndex != nextSpawnIndex) nextSpawnIndex = localNextIndex
                if (localScrollTrackAvailableAtNanos !== scrollTrackAvailableAtNanos) {
                    scrollTrackAvailableAtNanos = localScrollTrackAvailableAtNanos
                }
                if (localReverseTrackAvailableAtNanos !== reverseTrackAvailableAtNanos) {
                    reverseTrackAvailableAtNanos = localReverseTrackAvailableAtNanos
                }
                if (localTopTrackAvailableAtNanos !== topTrackAvailableAtNanos) {
                    topTrackAvailableAtNanos = localTopTrackAvailableAtNanos
                }
                if (localBottomTrackAvailableAtNanos !== bottomTrackAvailableAtNanos) {
                    bottomTrackAvailableAtNanos = localBottomTrackAvailableAtNanos
                }

                if (!playingNow) {
                    continue
                }

                var idx = 0
                while (idx < activeItems.size) {
                    val item = activeItems[idx]
                    if (nowRealNanos < item.startRealNanos) {
                        idx++
                        continue
                    }

                    val speedFactor = if (item.syncPlaybackSpeed) currentPlaybackSpeed else 1f
                    when (item.kind) {
                        DanmakuKind.Scroll -> {
                            val nextX = item.xPx - (item.baseSpeedPxPerMs * speedFactor * deltaRealMillisF)
                            if (nextX + item.textWidthPx < -extraTravelPx) {
                                activeItems.removeAt(idx)
                            } else {
                                activeItems[idx] = item.copy(xPx = nextX)
                                idx++
                            }
                        }
                        DanmakuKind.Reverse -> {
                            val nextX = item.xPx + (item.baseSpeedPxPerMs * speedFactor * deltaRealMillisF)
                            if (nextX > widthPx + extraTravelPx) {
                                activeItems.removeAt(idx)
                            } else {
                                activeItems[idx] = item.copy(xPx = nextX)
                                idx++
                            }
                        }
                        DanmakuKind.Top, DanmakuKind.Bottom -> {
                            val nextRemaining = item.remainingMillis - (deltaRealMillisF * speedFactor)
                            if (nextRemaining <= 0f) {
                                activeItems.removeAt(idx)
                            } else {
                                activeItems[idx] = item.copy(remainingMillis = nextRemaining)
                                idx++
                            }
                        }
                    }
                }
            }
        }

        for (item in activeItems) {
            if (realPlayheadNanos < item.startRealNanos) continue
            val x = item.xPx
            val y = when (item.kind) {
                DanmakuKind.Scroll -> paddingTopPx + (item.trackHeightPx * item.trackIndex.toFloat())
                DanmakuKind.Reverse -> paddingTopPx + (item.trackHeightPx * item.trackIndex.toFloat())
                DanmakuKind.Top -> paddingTopPx + (item.trackHeightPx * item.trackIndex.toFloat())
                DanmakuKind.Bottom -> heightPx - paddingBottomPx - (item.trackHeightPx * (item.trackIndex + 1).toFloat())
            }

            Text(
                text = item.danmaku.text,
                style = textStyleFor(item.fontSizeScale, item.color),
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
                        alpha = item.opacity
                    }
            )
        }

        val msg = debugMessage
        if (msg != null && latestFrameNanos - debugMessageAtFrameNanos < 6_000_000_000L) {
            Text(
                text = msg,
                style = TextStyle(fontSize = 12.sp, color = Color.Yellow),
                maxLines = 4,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.graphicsLayer {
                    translationX = with(density) { 8.dp.toPx() }
                    translationY = with(density) { 8.dp.toPx() }
                    alpha = 0.85f
                }
            )
        }

        if (debugEnabled) {
            val text = buildString {
                append("DanmakuDebug active=").append(activeItems.size)
                append(" next=").append(nextSpawnIndex)
                append(" media=").append(currentTimeState.value)
                append(" playing=").append(isPlayingState.value)
                append('\n')
                for (line in debugLines) {
                    append(line).append('\n')
                }
            }.trimEnd()
            if (text.isNotBlank()) {
                Text(
                    text = text,
                    style = TextStyle(fontSize = 12.sp, color = Color.White),
                    maxLines = 20,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.graphicsLayer {
                        translationX = with(density) { 8.dp.toPx() }
                        translationY = with(density) { 44.dp.toPx() }
                        alpha = 0.95f
                    }
                )
            }
        }
    }
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

private fun computeRequiredDeltaNanos(textWidthPx: Float, gapPx: Float, speedPxPerMs: Float): Long {
    if (speedPxPerMs <= 0f) return 0L
    val requiredDeltaMs = (textWidthPx + gapPx) / speedPxPerMs
    return (requiredDeltaMs * 1_000_000f).toLong().coerceAtLeast(0L)
}

private data class PreparedDanmaku(
    val key: String = "",
    val danmaku: Danmaku,
    val startTimeMillis: Long,
    val color: Color
)

private data class ActiveDanmaku(
    val key: String,
    val danmaku: Danmaku,
    val color: Color,
    val kind: DanmakuKind,
    val trackIndex: Int,
    val startRealNanos: Long,
    val xPx: Float,
    val baseSpeedPxPerMs: Float,
    val textWidthPx: Float,
    val availableAtRealNanos: Long,
    val opacity: Float,
    val fontSizeScale: Float,
    val trackHeightPx: Float,
    val syncPlaybackSpeed: Boolean,
    val remainingMillis: Float
)

private enum class DanmakuKind {
    Scroll,
    Top,
    Bottom,
    Reverse
}

private fun resolveDanmakuKind(mode: Int): DanmakuKind {
    return when (mode) {
        4 -> DanmakuKind.Bottom
        5 -> DanmakuKind.Top
        6 -> DanmakuKind.Reverse
        else -> DanmakuKind.Scroll
    }
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
