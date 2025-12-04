package com.jankinwu.fntv.client.ui.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.hoverable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import co.touchlab.kermit.Logger
import com.fasterxml.jackson.databind.DeserializationFeature
import com.fasterxml.jackson.databind.SerializationFeature
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.model.PlayingInfoCache
import com.jankinwu.fntv.client.data.model.request.PlayPlayRequest
import com.jankinwu.fntv.client.data.model.request.PlayRecordRequest
import com.jankinwu.fntv.client.data.model.request.StreamRequest
import com.jankinwu.fntv.client.data.model.response.FileInfo
import com.jankinwu.fntv.client.data.model.response.PlayInfoResponse
import com.jankinwu.fntv.client.data.model.response.StreamResponse
import com.jankinwu.fntv.client.data.model.response.SubtitleStream
import com.jankinwu.fntv.client.data.model.response.VideoStream
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.enums.FnTvMediaType
import com.jankinwu.fntv.client.icons.ArrowLeft
import com.jankinwu.fntv.client.icons.Back10S
import com.jankinwu.fntv.client.icons.Forward10S
import com.jankinwu.fntv.client.icons.Pause
import com.jankinwu.fntv.client.icons.Play
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingProgressRing
import com.jankinwu.fntv.client.ui.component.player.SpeedControlFlyout
import com.jankinwu.fntv.client.ui.component.player.VideoPlayerProgressBar
import com.jankinwu.fntv.client.ui.component.player.formatDuration
import com.jankinwu.fntv.client.ui.providable.LocalPlayerManager
import com.jankinwu.fntv.client.ui.providable.LocalTypography
import com.jankinwu.fntv.client.ui.providable.defaultVariableFamily
import com.jankinwu.fntv.client.viewmodel.PlayInfoViewModel
import com.jankinwu.fntv.client.viewmodel.PlayPlayViewModel
import com.jankinwu.fntv.client.viewmodel.PlayRecordViewModel
import com.jankinwu.fntv.client.viewmodel.StreamViewModel
import com.jankinwu.fntv.client.viewmodel.UserInfoViewModel
import korlibs.crypto.MD5
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import org.koin.compose.koinInject
import org.openani.mediamp.MediampPlayer
import org.openani.mediamp.PlaybackState
import org.openani.mediamp.compose.MediampPlayerSurface
import org.openani.mediamp.features.PlaybackSpeed
import org.openani.mediamp.source.MediaExtraFiles
import org.openani.mediamp.source.Subtitle
import org.openani.mediamp.source.UriMediaData
import org.openani.mediamp.togglePause


data class PlayerState(
    val isVisible: Boolean = false,
    val itemGuid: String = "",
    val mediaTitle: String = "",
    val subhead: String = "",
    val duration: Long = 0L,
    val isEpisode: Boolean = false
)

class PlayerManager {
    var playerState: PlayerState by mutableStateOf(PlayerState())

    fun showPlayer(
        itemGuid: String,
        mediaTitle: String,
        subhead: String = "",
        duration: Long = 0L,
        isEpisode: Boolean = false
    ) {
        playerState = PlayerState(
            isVisible = true,
            itemGuid = itemGuid,
            mediaTitle = mediaTitle,
            subhead = subhead,
            duration = duration,
            isEpisode = isEpisode
        )
    }

    fun hidePlayer() {
        playerState = playerState.copy(isVisible = false)
    }
}

object PlayerScreen{

    val mapper = jacksonObjectMapper().apply {
        // 禁止格式化输出
        disable(SerializationFeature.INDENT_OUTPUT)
        // 忽略未知字段
        disable(DeserializationFeature.FAIL_ON_UNKNOWN_PROPERTIES)
        // 不序列化null值
        disable(SerializationFeature.WRITE_NULL_MAP_VALUES)
//            setSerializationInclusion(JsonInclude.Include.NON_NULL)
    }
}

// 全局播放信息缓存，生命周期跟随播放器
var playingInfoCache: PlayingInfoCache? = null

private fun createPlayRecordRequest(
    ts: Int,
    cache: PlayingInfoCache
): PlayRecordRequest {
    return PlayRecordRequest(
        itemGuid = cache.itemGuid,
        mediaGuid = cache.currentFileStream.guid,
        videoGuid = cache.currentVideoStream.guid,
        audioGuid = cache.currentAudioStream?.guid ?: "",
        subtitleGuid = cache.currentSubtitleStream?.guid,
        resolution = cache.currentVideoStream.resolutionType,
        bitrate = cache.currentVideoStream.bps,
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
private fun callPlayRecord(
    ts: Int,
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

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun PlayerOverlay(
    mediaTitle: String,
    subhead: String,
    isEpisode: Boolean,
    onBack: () -> Unit,
    mediaPlayer: MediampPlayer
) {
    // 控制UI可见性的状态
    var uiVisible by remember { mutableStateOf(true) }
    var isCursorVisible by remember { mutableStateOf(true) }
    var lastMouseMoveTime by remember { mutableLongStateOf(System.currentTimeMillis()) }
    val interactionSource = remember { MutableInteractionSource() }
    var isProgressBarHovered by remember { mutableStateOf(false) }
    var isPlayControlHovered by remember { mutableStateOf(false) }
    val currentPosition by mediaPlayer.currentPositionMillis.collectAsState()
    val playerManager = LocalPlayerManager.current
    val totalDuration = playerManager.playerState.duration
    val playState by mediaPlayer.playbackState.collectAsState()
    val videoProgress = if (totalDuration > 0) {
        (currentPosition.toFloat() / totalDuration.toFloat()).coerceIn(0f, 1f)
    } else {
        0f
    }

    val videoBuffered by remember { mutableFloatStateOf(0f) }

    // 获取播放记录 ViewModel
    val playRecordViewModel: PlayRecordViewModel = koinInject()

    // 上一次播放状态
    var lastPlayState by remember { mutableStateOf<PlaybackState?>(null) }

    // 当播放状态变为暂停时，确保UI可见并调用playRecord接口
    LaunchedEffect(playState) {
        if (playState == PlaybackState.PAUSED && lastPlayState == PlaybackState.PLAYING) {
            uiVisible = true
            isCursorVisible = true

            // 调用playRecord接口
            callPlayRecord(
//                itemGuid = itemGuid,
                ts = (mediaPlayer.currentPositionMillis.value / 1000).toInt(),
                playRecordViewModel = playRecordViewModel,
                onSuccess = {
                    Logger.i("暂停时调用playRecord成功")
                },
                onError = {
                    Logger.i("暂停时调用playRecord失败：缓存为空")
                },
            )
        }
        lastPlayState = playState
    }

    // 每隔15秒调用一次playRecord接口
    LaunchedEffect(Unit) {
        launch {
            while (true) {
                delay(15000) // 每15秒

                // 检查播放器界面是否可见
                if (!playerManager.playerState.isVisible) break
                // 调用playRecord接口
                callPlayRecord(
//                    itemGuid = itemGuid,
                    ts = (mediaPlayer.currentPositionMillis.value / 1000).toInt(),
                    playRecordViewModel = playRecordViewModel,
                    onSuccess = {
                        Logger.i("每隔15s调用playRecord成功")
                    },
                    onError = {
                        Logger.i("每隔15s调用playRecord失败：缓存为空")
                    }
                )
            }
        }
    }

    // 鼠标静止检测协程
    LaunchedEffect(
        uiVisible,
        lastMouseMoveTime,
        isProgressBarHovered,
        playState,
        isPlayControlHovered
    ) {
        if (uiVisible && !isProgressBarHovered && !isPlayControlHovered && playState == PlaybackState.PLAYING) {
            launch {
                while (true) {
                    delay(100) // 每100ms检查一次
                    val currentTime = System.currentTimeMillis()
                    if (currentTime - lastMouseMoveTime >= 2000) {
                        uiVisible = false
                        isCursorVisible = false
                        break
                    }
                }
            }
        }
    }
    Box(
        modifier = Modifier
            .fillMaxSize()
            .hoverable(interactionSource)
            .background(Color.Black)
//            .onPointerEvent(PointerEventType.Move) {
//                // 鼠标移动时更新时间并显示UI
//                lastMouseMoveTime = System.currentTimeMillis()
//                uiVisible = true
//                isCursorVisible = true
//            }
            .pointerHoverIcon(
                if (isCursorVisible) PointerIcon.Hand else PointerIcon.Default,
                true
            )
    ) {
        // 添加标题栏占位区域，允许窗口拖动
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp) // 与标题栏高度一致
        )

        // 视频层 - 从标题栏下方开始显示
        MediampPlayerSurface(
            mediaPlayer, Modifier
                .fillMaxSize()
                .padding(top = 48.dp)
                .clickable(
                    interactionSource = interactionSource,
                    indication = null,
                    onClick = {
                        mediaPlayer.togglePause()
//                        if (mediaPlayer.getCurrentPlaybackState() == PlaybackState.PLAYING) {
//                            mediaPlayer.pause()
//                        } else if (mediaPlayer.getCurrentPlaybackState() == PlaybackState.PAUSED) {
//                            mediaPlayer.resume()
//                        }
                    }

                )
                .onPointerEvent(PointerEventType.Move) {
                    // 鼠标移动时更新时间并显示UI
                    lastMouseMoveTime = System.currentTimeMillis()
                    uiVisible = true
                    isCursorVisible = true
                })
        // 加载进度条
        if (playState == PlaybackState.READY || playState == PlaybackState.PAUSED_BUFFERING) {
            Box(
                modifier = Modifier
                    .fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                ImgLoadingProgressRing(modifier = Modifier.size(32.dp))
            }
        }
        // 播放器 UI
        if (uiVisible) {
            Row(
                modifier = Modifier
                    .padding(top = 48.dp)
                    .align(Alignment.TopStart)
                    .padding(start = 20.dp, top = 8.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp, Alignment.Start),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = ArrowLeft,
                    contentDescription = "返回",
                    tint = Color.White,
                    modifier = Modifier
                        .size(20.dp)
                        .clickable(onClick = {
                            mediaPlayer.stopPlayback()
                            // 清除缓存
                            playingInfoCache = null
                            onBack()
                        })
                )
                if (isEpisode) {
                    Text(
                        text = buildEpisodeTitle(mediaTitle, subhead),
                        style = LocalTypography.current.title,
                        color = Color.White,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Medium
                    )
                } else {
                    Text(
                        text = mediaTitle,
                        style = LocalTypography.current.title,
                        color = Color.White,
                        fontSize = 20.sp,
                        fontWeight = FontWeight.Medium
                    )
                }

            }
        }
        if (uiVisible) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(top = 48.dp), // 为标题栏留出空间
                verticalArrangement = Arrangement.Bottom,
                horizontalAlignment = Alignment.Start
            ) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .onPointerEvent(PointerEventType.Enter) {
                            isProgressBarHovered = true
                        }
                        .onPointerEvent(PointerEventType.Exit) {
                            isProgressBarHovered = false
                            // 重新开始鼠标静止检测
                            lastMouseMoveTime = System.currentTimeMillis()
                        }
                ) {
                    VideoPlayerProgressBar(
                        player = mediaPlayer,
                        totalDuration = playerManager.playerState.duration,
                        onSeek = { newProgress ->
                            val seekPosition = (newProgress * totalDuration).toLong()
                            mediaPlayer.seekTo(seekPosition)
                            Logger.i("Seek to: ${newProgress * 100}%")

                            // 调用playRecord接口
                            callPlayRecord(
//                                itemGuid = itemGuid,
                                ts = (seekPosition / 1000).toInt(),
                                playRecordViewModel = playRecordViewModel,
                                onSuccess = {
                                    Logger.i("Seek时调用playRecord成功")
                                },
                                onError = {
                                    Logger.i("Seek时调用playRecord失败：缓存为空")
                                },
                            )
                        },
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 8.dp)
                    )
                    // 播放器控制行
                    PlayerControlRow(
                        playState,
                        mediaPlayer,
                        videoProgress,
                        totalDuration,
                        onSpeedControlHoverChanged = { isHovered ->
                            isPlayControlHovered = isHovered
                        })
                }
            }
        }
    }
}

fun buildEpisodeTitle(mediaTitle: String, subhead: String): AnnotatedString {
    val annotatedString = buildAnnotatedString {
        withStyle(
            style = SpanStyle(
                color = Color.White,
                fontSize = 20.sp,
                fontWeight = FontWeight.Medium,
                fontFamily = defaultVariableFamily
            )
        ) {
            append(mediaTitle)
        }
        withStyle(
            style = SpanStyle(
                color = Color.White,
                fontSize = 20.sp,
                fontWeight = FontWeight.ExtraLight,
                fontFamily = defaultVariableFamily
            )
        ) {
            append(" | ")
        }
        withStyle(
            style = SpanStyle(
                color = Colors.TextSecondaryColor,
                fontSize = 14.sp,
                fontFamily = defaultVariableFamily,
                fontWeight = FontWeight.Normal
            )
        ) {
            append(subhead)
        }
    }
    return annotatedString
}

@Composable
fun PlayerControlRow(
    playState: PlaybackState,
    mediaPlayer: MediampPlayer,
    videoProgress: Float,
    totalDuration: Long,
    onSpeedControlHoverChanged: ((Boolean) -> Unit)? = null
) {
    val interactionSource = remember { MutableInteractionSource() }
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Row(
            modifier = Modifier
                .padding(horizontal = 16.dp, vertical = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(
                16.dp,
                Alignment.Start
            ),
        ) {
            // 播放/暂停按钮
            Icon(
                imageVector = if (playState == PlaybackState.PLAYING) Pause else Play,
                contentDescription = "播放/暂停",
                tint = Color.White,
                modifier = Modifier
                    .size(24.dp)
                    .clickable(
                        interactionSource = interactionSource,
                        indication = null,
                        onClick = {
                            if (mediaPlayer.getCurrentPlaybackState() == PlaybackState.PLAYING) {
                                mediaPlayer.pause()
                            } else if (mediaPlayer.getCurrentPlaybackState() == PlaybackState.PAUSED) {
                                mediaPlayer.resume()
                            }
                        })
            )
            Icon(
                imageVector = Back10S,
                contentDescription = "快退10s",
                tint = Color.White,
                modifier = Modifier
                    .size(20.dp)
                    .clickable(
                        interactionSource = interactionSource,
                        indication = null,
                        onClick = {
                            mediaPlayer.skip(-10_000)
                        })
            )
            Icon(
                imageVector = Forward10S,
                contentDescription = "快进10s",
                tint = Color.White,
                modifier = Modifier
                    .size(20.dp)
                    .clickable(
                        interactionSource = interactionSource,
                        indication = null,
                        onClick = {
                            mediaPlayer.skip(10_000)
                        })
            )
            // 当前播放时间 / 总时间
            Text(
                text = "${formatDuration((videoProgress * totalDuration).toLong())} / ${
                    formatDuration(totalDuration)
                }",
                color = Color.White,
                fontSize = 14.sp,
                modifier = Modifier
            )
        }
        Row(
            modifier = Modifier
                .padding(horizontal = 16.dp, vertical = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp, Alignment.End),
        ) {
            // 倍速
            SpeedControlFlyout(
                yOffset = 50,
                onHoverStateChanged = onSpeedControlHoverChanged,
                onSpeedSelected = { item ->
                    mediaPlayer.features[PlaybackSpeed]?.set(item.value)
                }
            )
            Text(
                text = "原画质",
                style = LocalTypography.current.title,
                color = Color.White.copy(alpha = 0.7843f),
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                modifier = Modifier
            )
        }
    }
}

suspend fun MediampPlayer.playUri(
    uri: String,
    headers: Map<String, String> = emptyMap(),
    extraFiles: MediaExtraFiles
): Unit =
    setMediaData(UriMediaData(uri, headers, extraFiles))

@Composable
fun rememberPlayMediaFunction(
    guid: String,
    player: MediampPlayer,
    mediaGuid: String? = null,
    currentAudioGuid: String? = null,
    currentSubtitleGuid: String? = null
): () -> Unit {
    val streamViewModel: StreamViewModel = koinInject()
    val playPlayViewModel: PlayPlayViewModel = koinInject()
    val playInfoViewModel: PlayInfoViewModel = koinInject()
    val userInfoViewModel: UserInfoViewModel = koinInject()
    val playRecordViewModel: PlayRecordViewModel = koinInject()
    val scope = rememberCoroutineScope()
    val playerManager = LocalPlayerManager.current
    return remember(streamViewModel, playPlayViewModel, guid, player, playerManager, mediaGuid, currentAudioGuid, currentSubtitleGuid) {
        {
            scope.launch {
                playMedia(
                    guid = guid,
                    player = player,
                    playInfoViewModel = playInfoViewModel,
                    userInfoViewModel = userInfoViewModel,
                    streamViewModel = streamViewModel,
                    playPlayViewModel = playPlayViewModel,
                    playRecordViewModel = playRecordViewModel,
                    playerManager = playerManager,
                    mediaGuid = mediaGuid,
                    currentAudioGuid = currentAudioGuid,
                    currentSubtitleGuid = currentSubtitleGuid
                )
            }
        }
    }
}

private suspend fun playMedia(
    guid: String,
    player: MediampPlayer,
    playInfoViewModel: PlayInfoViewModel,
    userInfoViewModel: UserInfoViewModel,
    streamViewModel: StreamViewModel,
    playPlayViewModel: PlayPlayViewModel,
    playRecordViewModel: PlayRecordViewModel,
    playerManager: PlayerManager,
    mediaGuid: String?,
    currentAudioGuid: String?,
    currentSubtitleGuid: String?
) {
    try {
        // 获取播放信息
        val playInfoResponse = playInfoViewModel.loadDataAndWait(guid, mediaGuid)
        val startPosition: Long = playInfoResponse.ts.toLong() * 1000

        // 获取流信息
        val streamInfo = fetchStreamInfo(playInfoResponse, userInfoViewModel, streamViewModel)
        val videoStream = streamInfo.videoStream
        val audioStream = streamInfo.audioStreams.first { audioStream -> audioStream.guid == playInfoResponse.audioGuid }
        val audioGuid = currentAudioGuid ?: audioStream.guid
//        val subtitleStream = streamInfo.subtitleStreams?.first{ it.guid == playInfoResponse.subtitleGuid}
        val subtitleStream = streamInfo.subtitleStreams?.find {
            it.guid == playInfoResponse.subtitleGuid
        }
        val subtitleGuid = currentSubtitleGuid?: subtitleStream?.guid
        val fileStream = streamInfo.fileStream
        // 显示播放器
        val videoDuration = videoStream.duration * 1000L
        if (playInfoResponse.type == FnTvMediaType.EPISODE.value) {
            val season = playInfoResponse.item.parentTitle
            val episode = "第${playInfoResponse.item.episodeNumber}集"
            val episodeTitle = playInfoResponse.item.title
            val subhead =
                if (episodeTitle.isNullOrEmpty()) "$season · $episode" else "$season · $episode $episodeTitle"
            playerManager.showPlayer(
                guid,
                playInfoResponse.item.tvTitle,
                subhead,
                videoDuration,
                isEpisode = true
            )
        } else {
            playerManager.showPlayer(
                guid,
                playInfoResponse.item.title ?: "",
                duration = videoDuration
            )
        }

        // 构造播放请求
        val playRequest = createPlayRequest(videoStream, fileStream, audioGuid, subtitleGuid)

        var playLink = ""
        // 获取播放链接
        try {
            val playResponse = playPlayViewModel.loadDataAndWait(playRequest)
            playLink = playResponse.playLink
        } catch (e: Exception) {
            if (e.message?.contains("8192") ?: true) {
                Logger.i("使用直链播放")
                playLink = "/v/api/v1/media/range/${playInfoResponse.mediaGuid}"
            }
        }

        // 缓存播放信息
        playingInfoCache = PlayingInfoCache(
            streamInfo, playLink, fileStream,
            videoStream, audioStream, subtitleStream, playInfoResponse.item.guid
        )
        Logger.i("startPosition: $startPosition")
        // 设置字幕
        val extraFiles = subtitleStream?.let {
            val mediaExtraFiles = getMediaExtraFiles(it)
            mediaExtraFiles
        }?: MediaExtraFiles()
        // 启动播放器
        startPlayback(player, playLink, startPosition, extraFiles)
        // 记录播放数据
        callPlayRecord(
//            itemGuid = guid,
            ts = if ((startPosition / 1000).toInt() == 0) 1 else (startPosition / 1000).toInt(),
            playRecordViewModel = playRecordViewModel,
            onSuccess = {
                Logger.i("起播时调用playRecord成功")
            },
            onError = {
                Logger.e("起播时调用playRecord失败：缓存为空")
            },
        )
    } catch (e: Exception) {
        Logger.e("播放失败: ${e.message}",  e)
    }
}

private fun getMediaExtraFiles(
    subtitleStream: SubtitleStream
) : MediaExtraFiles {
    if (subtitleStream.isExternal == 1 && subtitleStream.format in listOf("srt", "ass")) {
        val subtitleLink = "${AccountDataCache.getProxyBaseUrl()}/v/api/v1/subtitle/dl/${subtitleStream.guid}"
        val subtitle = Subtitle(subtitleLink)
        return MediaExtraFiles(listOf(subtitle))
    }
    return MediaExtraFiles()
}

private suspend fun fetchStreamInfo(
    playInfoResponse: PlayInfoResponse,
    userInfoViewModel: UserInfoViewModel,
    streamViewModel: StreamViewModel
): StreamResponse {
    // 获取用户信息以获取source_name
    val userInfo = userInfoViewModel.loadUserInfoAndWait()
    val sourceName = userInfo.userSources.firstOrNull()?.sourceName ?: ""
    val ip = MD5.digest(sourceName.toByteArray()).hex

    // 调用 getStreamList 接口
    return streamViewModel.loadDataAndWait(
        StreamRequest(
            playInfoResponse.mediaGuid,
            ip = ip,
            level = 1,
            header = StreamRequest.Header(
                listOf("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36")
            )
        )
    )
}

private fun createPlayRequest(
    videoStream: VideoStream,
    fileStream: FileInfo,
    audioGuid: String,
    subtitleGuid: String?
): PlayPlayRequest {
    return PlayPlayRequest(
        videoGuid = videoStream.guid,
        mediaGuid = fileStream.guid,
        audioEncoder = "aac",
        audioGuid = audioGuid,
        bitrate = videoStream.bps,
        channels = 2,
        forcedSdr = 0,
        resolution = videoStream.resolutionType,
        startTimestamp = 0,
        subtitleGuid = subtitleGuid?: "",
        videoEncoder = videoStream.codecName,
    )
}

private suspend fun startPlayback(
    player: MediampPlayer,
    playLink: String,
    startPosition: Long,
    extraFiles: MediaExtraFiles
) {
    if (AccountDataCache.cookieState.isNotBlank()) {
        val headers = mapOf(
            "cookie" to AccountDataCache.cookieState,
            "Authorization" to AccountDataCache.authorization
        )
//        headers["Authorization"] = AccountDataCache.authorization
        val extraFilesStr = PlayerScreen.mapper.writeValueAsString(extraFiles)
        Logger.i("play param: headers: $headers, playUri: ${AccountDataCache.getFnOfficialBaseUrl()}$playLink, extraFiles: $extraFilesStr")
        player.playUri("${AccountDataCache.getFnOfficialBaseUrl()}$playLink", headers, extraFiles)
    } else {
        player.playUri(
            "${AccountDataCache.getFnOfficialBaseUrl()}$playLink",
            extraFiles = extraFiles
        )
    }
    delay(1500) // 等待播放器初始化
    player.features[PlaybackSpeed]?.set(1.0f)
    Logger.i("startPlayback startPosition: $startPosition")
    player.seekTo(startPosition)
}