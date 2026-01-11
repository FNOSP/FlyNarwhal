package com.jankinwu.fntv.client.utils

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.withFrameNanos
import com.jankinwu.fntv.client.data.model.PlayingInfoCache
import com.jankinwu.fntv.client.data.model.request.PlayRecordRequest
import com.jankinwu.fntv.client.viewmodel.PlayRecordViewModel
import kotlinx.coroutines.isActive
import org.openani.mediamp.MediampPlayer
import org.openani.mediamp.PlaybackState
import kotlin.math.abs

fun createPlayRecordRequest(
    ts: Int,
    cache: PlayingInfoCache
): PlayRecordRequest {
    return PlayRecordRequest(
        itemGuid = cache.itemGuid,
        mediaGuid = cache.currentFileStream.guid,
        videoGuid = cache.currentVideoStream.guid,
        audioGuid = cache.currentAudioStream?.guid ?: "",
        subtitleGuid = cache.currentSubtitleStream?.guid,
        resolution = cache.currentQuality?.resolution ?: cache.currentVideoStream.resolutionType,
        bitrate = cache.currentQuality?.bitrate ?: cache.currentVideoStream.bps,
        ts = ts,
        duration = cache.currentVideoStream.duration,
        playLink = cache.playLink
    )
}

/**
 * 保存播放进度
 *
 * @param ts 当前播放时间戳(秒)
 * @param playRecordViewModel PlayRecordViewModel实例
 * @param onSuccess 成功回调
 * @param onError 错误回调
 */
fun callPlayRecord(
    ts: Int,
    playingInfoCache: PlayingInfoCache?,
    playRecordViewModel: PlayRecordViewModel,
    onSuccess: (() -> Unit)? = null,
    onError: (() -> Unit)? = null
) {
    playingInfoCache?.let { cache ->
        val playRecordRequest = createPlayRecordRequest(ts, cache)
        playRecordViewModel.loadData(playRecordRequest)
        onSuccess?.invoke()
    } ?: run {
        onError?.invoke()
    }
}

@Composable
fun rememberSmoothVideoTime(mediaPlayer: MediampPlayer): State<Long> {
    val targetTime by mediaPlayer.currentPositionMillis.collectAsState()
    val isPlaying by mediaPlayer.playbackState.collectAsState()
    val smoothTime = remember { mutableLongStateOf(targetTime) }

    // Sync when paused or seeking (large diff)
    LaunchedEffect(targetTime, isPlaying) {
        if (isPlaying != PlaybackState.PLAYING || abs(smoothTime.longValue - targetTime) > 1000) {
            smoothTime.longValue = targetTime
        }
    }

    // Smooth update loop
    LaunchedEffect(isPlaying) {
        if (isPlaying == PlaybackState.PLAYING) {
            var lastFrameTime = withFrameNanos { it }
            while (isActive) {
                withFrameNanos { frameTime ->
                    val delta = (frameTime - lastFrameTime) / 1_000_000 // ns to ms
                    if (delta > 0) {
                        smoothTime.longValue += delta
                    }
                    lastFrameTime = frameTime
                }
            }
        }
    }
    return smoothTime
}
