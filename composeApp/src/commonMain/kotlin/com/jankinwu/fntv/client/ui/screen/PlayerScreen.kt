@file:OptIn(ExperimentalResourceApi::class)

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
import androidx.compose.runtime.CompositionLocalProvider
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
import androidx.compose.ui.window.WindowPlacement
import co.touchlab.kermit.Logger
import com.fasterxml.jackson.databind.DeserializationFeature
import com.fasterxml.jackson.databind.SerializationFeature
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.model.PlayingInfoCache
import com.jankinwu.fntv.client.data.model.request.MediaPRequest
import com.jankinwu.fntv.client.data.model.request.PlayPlayRequest
import com.jankinwu.fntv.client.data.model.request.PlayRecordRequest
import com.jankinwu.fntv.client.data.model.request.StreamRequest
import com.jankinwu.fntv.client.data.model.response.AudioStream
import com.jankinwu.fntv.client.data.model.response.FileInfo
import com.jankinwu.fntv.client.data.model.response.MediaResetQualityResponse
import com.jankinwu.fntv.client.data.model.response.PlayInfoResponse
import com.jankinwu.fntv.client.data.model.response.QualityResponse
import com.jankinwu.fntv.client.data.model.response.QueryTagResponse
import com.jankinwu.fntv.client.data.model.response.StreamResponse
import com.jankinwu.fntv.client.data.model.response.SubtitleStream
import com.jankinwu.fntv.client.data.model.response.UserInfoResponse
import com.jankinwu.fntv.client.data.model.response.VideoStream
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.data.store.PlayingSettingsStore
import com.jankinwu.fntv.client.enums.FnTvMediaType
import com.jankinwu.fntv.client.icons.ArrowLeft
import com.jankinwu.fntv.client.icons.Back10S
import com.jankinwu.fntv.client.icons.Forward10S
import com.jankinwu.fntv.client.icons.Pause
import com.jankinwu.fntv.client.icons.Play
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingProgressRing
import com.jankinwu.fntv.client.ui.component.common.ToastHost
import com.jankinwu.fntv.client.ui.component.common.dialog.AddNasSubtitleDialog
import com.jankinwu.fntv.client.ui.component.common.dialog.CustomContentDialog
import com.jankinwu.fntv.client.ui.component.common.dialog.SubtitleSearchDialog
import com.jankinwu.fntv.client.ui.component.common.rememberToastManager
import com.jankinwu.fntv.client.ui.component.player.FullScreenControl
import com.jankinwu.fntv.client.ui.component.player.PlayerSettingsMenu
import com.jankinwu.fntv.client.ui.component.player.QualityControlFlyout
import com.jankinwu.fntv.client.ui.component.player.SpeedControlFlyout
import com.jankinwu.fntv.client.ui.component.player.SubtitleControlFlyout
import com.jankinwu.fntv.client.ui.component.player.VideoPlayerProgressBar
import com.jankinwu.fntv.client.ui.component.player.VolumeControl
import com.jankinwu.fntv.client.ui.component.player.formatDuration
import com.jankinwu.fntv.client.ui.providable.IsoTagData
import com.jankinwu.fntv.client.ui.providable.LocalFileInfo
import com.jankinwu.fntv.client.ui.providable.LocalFrameWindowScope
import com.jankinwu.fntv.client.ui.providable.LocalIsoTagData
import com.jankinwu.fntv.client.ui.providable.LocalPlayerManager
import com.jankinwu.fntv.client.ui.providable.LocalStore
import com.jankinwu.fntv.client.ui.providable.LocalToastManager
import com.jankinwu.fntv.client.ui.providable.LocalTypography
import com.jankinwu.fntv.client.ui.providable.LocalWindowState
import com.jankinwu.fntv.client.ui.providable.defaultVariableFamily
import com.jankinwu.fntv.client.utils.HiddenPointerIcon
import com.jankinwu.fntv.client.utils.chooseFile
import com.jankinwu.fntv.client.viewmodel.MediaPViewModel
import com.jankinwu.fntv.client.viewmodel.PlayInfoViewModel
import com.jankinwu.fntv.client.viewmodel.PlayPlayViewModel
import com.jankinwu.fntv.client.viewmodel.PlayRecordViewModel
import com.jankinwu.fntv.client.viewmodel.PlayerViewModel
import com.jankinwu.fntv.client.viewmodel.StreamViewModel
import com.jankinwu.fntv.client.viewmodel.SubtitleDeleteViewModel
import com.jankinwu.fntv.client.viewmodel.SubtitleMarkViewModel
import com.jankinwu.fntv.client.viewmodel.SubtitleUploadViewModel
import com.jankinwu.fntv.client.viewmodel.TagViewModel
import com.jankinwu.fntv.client.viewmodel.UiState
import com.jankinwu.fntv.client.viewmodel.UserInfoViewModel
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.ContentDialogButton
import io.github.composefluent.component.DialogSize
import korlibs.crypto.MD5
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import org.jetbrains.compose.resources.ExperimentalResourceApi
import org.koin.compose.viewmodel.koinViewModel
import org.openani.mediamp.MediampPlayer
import org.openani.mediamp.PlaybackState
import org.openani.mediamp.compose.MediampPlayerSurface
import org.openani.mediamp.features.AudioLevelController
import org.openani.mediamp.features.PlaybackSpeed
import org.openani.mediamp.source.MediaExtraFiles
import org.openani.mediamp.source.Subtitle
import org.openani.mediamp.source.UriMediaData
import org.openani.mediamp.togglePause

private val logger = Logger.withTag("PlayerScreen")

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

object PlayerScreen {

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
    var isSpeedControlHovered by remember { mutableStateOf(false) }
    var isVolumeControlHovered by remember { mutableStateOf(false) }
    var isQualityControlHovered by remember { mutableStateOf(false) }
    var isSettingsMenuHovered by remember { mutableStateOf(false) }
    var isSubtitleControlHovered by remember { mutableStateOf(false) }
    val isPlayControlHovered =
        isSpeedControlHovered || isVolumeControlHovered || isQualityControlHovered || isSettingsMenuHovered || isSubtitleControlHovered
    val currentPosition by mediaPlayer.currentPositionMillis.collectAsState()
    val playerManager = LocalPlayerManager.current
    val frameWindowScope = LocalFrameWindowScope.current
    val mediaPViewModel: MediaPViewModel = koinViewModel()
    val tagViewModel: TagViewModel = koinViewModel()
    val playerViewModel: PlayerViewModel = koinViewModel()
    val playingInfoCache by playerViewModel.playingInfoCache.collectAsState()
    val resetQualityState by mediaPViewModel.resetQualityState.collectAsState()
    val iso6391State by tagViewModel.iso6391State.collectAsState()
    val iso6392State by tagViewModel.iso6392State.collectAsState()
    val iso3166State by tagViewModel.iso3166State.collectAsState()
    val toastManager = rememberToastManager()
    var isoTagData by remember {
        mutableStateOf(
            IsoTagData(
                iso6391Map = emptyMap(),
                iso6392Map = emptyMap(),
                iso3166Map = emptyMap()
            )
        )
    }

    LaunchedEffect(Unit) {
        if (iso6392State !is UiState.Success) {
            tagViewModel.loadIso6392Tags()
        }
        if (iso6391State !is UiState.Success) {
            tagViewModel.loadIso6391Tags()
        }
        if (iso3166State !is UiState.Success) {
            tagViewModel.loadIso3166Tags()
        }
    }

    LaunchedEffect(iso6391State, iso6392State, iso3166State) {
        val newIso6391Map = if (iso6391State is UiState.Success) {
            (iso6391State as UiState.Success<List<QueryTagResponse>>).data.associateBy { it.key }
        } else {
            emptyMap()
        }

        val newIso6392Map = if (iso6392State is UiState.Success) {
            (iso6392State as UiState.Success<List<QueryTagResponse>>).data.associateBy { it.key }
        } else {
            emptyMap()
        }

        val newIso3166Map = if (iso3166State is UiState.Success) {
            (iso3166State as UiState.Success<List<QueryTagResponse>>).data.associateBy { it.key }
        } else {
            emptyMap()
        }

        isoTagData = IsoTagData(
            iso6391Map = newIso6391Map,
            iso6392Map = newIso6392Map,
            iso3166Map = newIso3166Map
        )
    }

    val audioLevelController = remember(mediaPlayer) { mediaPlayer.features[AudioLevelController] }
    LaunchedEffect(audioLevelController) {
        val savedVolume = PlayingSettingsStore.getVolume()
        audioLevelController?.setVolume(savedVolume)
    }

    var showSubtitleSearchDialog by remember { mutableStateOf(false) }
    var showAddNasSubtitleDialog by remember { mutableStateOf(false) }
    var showDeleteSubtitleDialog by remember { mutableStateOf(false) }
    var subtitleToDelete by remember { mutableStateOf<SubtitleStream?>(null) }
    val subtitleDeleteViewModel: SubtitleDeleteViewModel = koinViewModel()
    val subtitleDeleteState by subtitleDeleteViewModel.uiState.collectAsState()

    val subtitleUploadViewModel: SubtitleUploadViewModel = koinViewModel()
    val subtitleUploadState by subtitleUploadViewModel.uiState.collectAsState()

    val streamViewModel: StreamViewModel = koinViewModel()
    val userInfoViewModel: UserInfoViewModel = koinViewModel()

    val refreshSubtitleList = remember(playerViewModel, userInfoViewModel, streamViewModel, subtitleDeleteState) {
        {
            val cache = playerViewModel.playingInfoCache.value
            if (cache != null) {
                kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Main).launch {
                    try {
                        val userInfoState = userInfoViewModel.uiState.value
                        val userInfo =
                            if (userInfoState is UiState.Success) userInfoState.data else null

                        if (userInfo != null) {
                            val sourceName = userInfo.userSources.firstOrNull()?.sourceName ?: ""
                            val ip = MD5.digest(sourceName.toByteArray()).hex
                            val mediaGuid = cache.currentVideoStream.mediaGuid

                            val streamResponse = streamViewModel.loadDataAndWait(
                                StreamRequest(
                                    mediaGuid,
                                    ip = ip,
                                    level = 1,
                                    header = StreamRequest.Header(
                                        listOf("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/141.0.0.0 Safari/537.36")
                                    )
                                )
                            )
                            playerViewModel.updateSubtitleList(streamResponse.subtitleStreams ?: emptyList(), streamResponse)
                        }
                    } catch (e: Exception) {
                        logger.e("Failed to refresh subtitle list", e)
                    }
                }
            }
        }
    }

    LaunchedEffect(subtitleDeleteState) {
        if (subtitleDeleteState is UiState.Success) {
            refreshSubtitleList()
            subtitleDeleteViewModel.clearError()
        }
    }

    LaunchedEffect(subtitleUploadState) {
        if (subtitleUploadState is UiState.Success) {
            refreshSubtitleList()
            subtitleUploadViewModel.clearError()
        }
    }

    var currentResolution by remember { mutableStateOf("") }
    var currentBitrate by remember { mutableStateOf<Int?>(null) }

    // Initialize quality
    if (currentResolution.isEmpty() && playingInfoCache?.currentQualities != null) {
        val qualities = playingInfoCache!!.currentQualities!!
        val saved = PlayingSettingsStore.getQuality()
        var found = false
        if (saved != null) {
            val matched =
                qualities.find { it.resolution == saved.resolution && (saved.bitrate == null || it.bitrate == saved.bitrate) }
            if (matched != null) {
                currentResolution = matched.resolution
                currentBitrate = matched.bitrate
                found = true
            } else {
                // Try match resolution only, pick highest bitrate
                val matchedRes = qualities.filter { it.resolution == saved.resolution }
                    .maxByOrNull { it.bitrate }
                if (matchedRes != null) {
                    currentResolution = matchedRes.resolution
                    currentBitrate = matchedRes.bitrate
                    found = true
                }
            }
        }

        if (!found) {
            val default = qualities.firstOrNull()
            if (default != null) {
                currentResolution = default.resolution
                currentBitrate = default.bitrate
            }
        }
    }

    LaunchedEffect(resetQualityState) {
        if (resetQualityState is UiState.Success) {
            val response =
                (resetQualityState as UiState.Success<*>).data as? MediaResetQualityResponse
            if (response != null && (response.result == "Success" || response.result == "success")) {
                val cache = playingInfoCache
                if (cache != null) {
                    val startPos = mediaPlayer.getCurrentPositionMillis()
                    val extraFiles = cache.currentSubtitleStream?.let { getMediaExtraFiles(it) }
                        ?: MediaExtraFiles()
//                    mediaPlayer.stopPlayback()
                    startPlayback(mediaPlayer, cache.playLink, startPos, extraFiles)
                }
                mediaPViewModel.clearError()
            }
        }
    }

    val totalDuration = playerManager.playerState.duration
    val playState by mediaPlayer.playbackState.collectAsState()
    val videoProgress = if (totalDuration > 0) {
        (currentPosition.toFloat() / totalDuration.toFloat()).coerceIn(0f, 1f)
    } else {
        0f
    }

    val videoBuffered by remember { mutableFloatStateOf(0f) }

    // 获取播放记录 ViewModel
    val playRecordViewModel: PlayRecordViewModel = koinViewModel()

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
                playingInfoCache = playingInfoCache,
                playRecordViewModel = playRecordViewModel,
                onSuccess = {
                    logger.i("暂停时调用playRecord成功")
                },
                onError = {
                    logger.i("暂停时调用playRecord失败：缓存为空")
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
                    playingInfoCache = playingInfoCache,
                    playRecordViewModel = playRecordViewModel,
                    onSuccess = {
                        logger.i("每隔15s调用playRecord成功")
                    },
                    onError = {
                        logger.i("每隔15s调用playRecord失败：缓存为空")
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
        isPlayControlHovered,
        isQualityControlHovered
    ) {
        if (uiVisible && !isProgressBarHovered && !isPlayControlHovered && !isQualityControlHovered && !isSettingsMenuHovered && !isSubtitleControlHovered && playState == PlaybackState.PLAYING) {
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
    CompositionLocalProvider(
        LocalIsoTagData provides isoTagData,
        LocalToastManager provides toastManager,
        LocalFileInfo provides playingInfoCache?.currentFileStream
    ) {
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
                    if (isCursorVisible) PointerIcon.Hand else HiddenPointerIcon,
                    true
                )
        ) {
            val windowState = LocalWindowState.current
            if (windowState.placement != WindowPlacement.Fullscreen) {
                // 添加标题栏占位区域，允许窗口拖动
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp) // 与标题栏高度一致
                )
            }

            // 视频层 - 从标题栏下方开始显示
            MediampPlayerSurface(
                mediaPlayer, Modifier
                    .fillMaxSize()
                    .padding(top = if (windowState.placement != WindowPlacement.Fullscreen) 48.dp else 0.dp)
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
                        .padding(top = if (windowState.placement != WindowPlacement.Fullscreen) 48.dp else 12.dp)
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
                                playerViewModel.updatePlayingInfo(null)
                                onBack()
                                if (windowState.placement == WindowPlacement.Fullscreen) {
                                    windowState.placement = WindowPlacement.Floating
                                }
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
                                logger.i("Seek to: ${newProgress * 100}%")

                                // 调用playRecord接口
                                callPlayRecord(
//                                itemGuid = itemGuid,
                                    ts = (seekPosition / 1000).toInt(),
                                    playingInfoCache = playingInfoCache,
                                    playRecordViewModel = playRecordViewModel,
                                    onSuccess = {
                                        logger.i("Seek时调用playRecord成功")
                                    },
                                    onError = {
                                        logger.i("Seek时调用playRecord失败：缓存为空")
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
                            playingInfoCache = playingInfoCache,
                            qualities = playingInfoCache?.currentQualities,
                            currentResolution = currentResolution,
                            currentBitrate = currentBitrate,
                            onSpeedControlHoverChanged = { isHovered ->
                                isSpeedControlHovered = isHovered
                            },
                            onVolumeControlHoverChanged = { isHovered ->
                                isVolumeControlHovered = isHovered
                            },
                            onQualityControlHoverChanged = { isHovered ->
                                isQualityControlHovered = isHovered
                            },
                            onQualitySelected = { quality ->
                                currentResolution = quality.resolution
                                currentBitrate = quality.bitrate
                                PlayingSettingsStore.saveQuality(
                                    quality.resolution,
                                    quality.bitrate
                                )

                                val cache = playingInfoCache
                                if (cache != null) {
                                    val request = MediaPRequest(
                                        req = "media.resetQuality",
                                        reqId = "${System.currentTimeMillis()}",
                                        playLink = cache.playLink,
                                        quality = MediaPRequest.Quality(
                                            quality.resolution,
                                            quality.bitrate
                                        ),
                                        startTimestamp = (mediaPlayer.getCurrentPositionMillis() / 1000).toInt(),
                                        clearCache = true
                                    )
                                    mediaPViewModel.resetQuality(request)
                                }
                            },
                            isoTagData = isoTagData,
                            onAudioSelected = { audio ->
                                val cache = playingInfoCache
                                if (cache != null) {
                                    val request = MediaPRequest(
                                        req = "media.resetAudio",
                                        reqId = "1234567890ABCDEF2s",
                                        playLink = cache.playLink,
                                        quality = null,
                                        startTimestamp = (mediaPlayer.getCurrentPositionMillis() / 1000).toInt(),
                                        clearCache = true,
                                        audioEncoder = "aac",
                                        channels = 2,
                                        audioIndex = audio.index
                                    )
                                    mediaPViewModel.resetAudio(request)
                                }
                            },
                            onSubtitleSelected = { subtitle ->
                                val cache = playerViewModel.playingInfoCache.value
                                if (cache != null) {
                                    playerViewModel.updatePlayingInfo(cache.copy(currentSubtitleStream = subtitle))
//                                playingInfoCache = cache.copy(currentSubtitleStream = subtitle)
                                    if (subtitle != null) {
                                        val request = MediaPRequest(
                                            req = "media.resetSubtitle",
                                            reqId = "1234567890ABCDEF",
                                            playLink = cache.playLink,
                                            subtitleIndex = subtitle.index,
                                            startTimestamp = (mediaPlayer.getCurrentPositionMillis() / 1000).toInt(),
                                        )
                                        mediaPViewModel.resetSubtitle(request)
                                    } else {
                                        val request = MediaPRequest(
                                            req = "media.resetSubtitle",
                                            reqId = "1234567890ABCDEF",
                                            playLink = cache.playLink,
                                            startTimestamp = (mediaPlayer.getCurrentPositionMillis() / 1000).toInt(),
                                        )
                                        mediaPViewModel.resetSubtitle(request)
//                                    val scope = kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Main)
//                                    scope.launch {
//                                        val startPos = mediaPlayer.getCurrentPositionMillis()
//                                        startPlayback(mediaPlayer, cache.playLink, startPos, MediaExtraFiles())
//                                    }
                                    }
                                }
                            },
                            onOpenSubtitleSearch = {
                                showSubtitleSearchDialog = true
                            },
                            onOpenAddNasSubtitle = {
                                showAddNasSubtitleDialog = true
                            },
                            onOpenAddLocalSubtitle = {
                                val mediaGuid = playingInfoCache?.currentFileStream?.guid
                                if (mediaGuid != null) {
                                    val file = chooseFile(
                                        frameWindowScope,
                                        arrayOf("ass", "srt", "vtt", "sub", "ssa"),
                                        "选择字幕文件"
                                    )
                                    file?.let { selectedFile ->
                                        val byteArray = selectedFile.readBytes()
                                        subtitleUploadViewModel.uploadSubtitle(
                                            mediaGuid,
                                            byteArray,
                                            selectedFile.name
                                        )
                                    }
                                }
                            },
                            onSubtitleControlHoverChanged = { isHovered ->
                                isSubtitleControlHovered = isHovered
                            },
                            onSettingsMenuHoverChanged = { isHovered ->
                                isSettingsMenuHovered = isHovered
                            },
                            onRequestDeleteSubtitle = { subtitle ->
                                subtitleToDelete = subtitle
                                showDeleteSubtitleDialog = true
                            }
                        )
                    }
                }
            }

            if (showSubtitleSearchDialog) {
                val mediaGuid = playingInfoCache?.currentFileStream?.guid ?: ""
                val trimIdList = playingInfoCache?.currentSubtitleStreamList?.map { it.trimId }
                    ?.filter { it.isNotBlank() } ?: emptyList()
                val mediaFileName = playingInfoCache?.currentFileStream?.fileName ?: ""

                SubtitleSearchDialog(
                    title = "搜索字幕",
                    visible = showSubtitleSearchDialog,
                    mediaGuid = mediaGuid,
                    trimIdList = trimIdList,
                    mediaFileName = mediaFileName,
                    onDismissRequest = { showSubtitleSearchDialog = false },
                    onSubtitleDownloadSuccess = {
                        refreshSubtitleList()
                    }
                )
            }

            if (showAddNasSubtitleDialog) {
                val subtitleMarkViewModel: SubtitleMarkViewModel = koinViewModel()
                val mediaGuid = playingInfoCache?.currentFileStream?.guid ?: ""

                AddNasSubtitleDialog(
                    title = "添加 NAS 字幕文件",
                    visible = showAddNasSubtitleDialog,
                    primaryButtonText = "添加",
                    closeButtonText = "关闭",
                    onButtonClick = { button, paths ->
                        if (button == ContentDialogButton.Primary && !paths.isNullOrEmpty()) {
                            subtitleMarkViewModel.markSubtitles(mediaGuid, paths.toList())
                            refreshSubtitleList()
                            showAddNasSubtitleDialog = false
                        } else if (button == ContentDialogButton.Close) {
                            showAddNasSubtitleDialog = false
                        }
                    }
                )
            }

            CustomContentDialog(
                title = "删除外挂字幕",
                visible = showDeleteSubtitleDialog,
                size = DialogSize.Standard,
                primaryButtonText = "删除",
                secondaryButtonText = "取消",
                onButtonClick = { contentDialogButton ->
                    when (contentDialogButton) {
                        ContentDialogButton.Primary -> {
                            subtitleToDelete?.let {
                                subtitleDeleteViewModel.deleteSubtitle(it.guid)
                            }
                        }
                        else -> {}
                    }
                    showDeleteSubtitleDialog = false
                    subtitleToDelete = null
                },
                isWarning = true,
                content = {
                    Text(
                        "确定要删除 ${subtitleToDelete?.title} 外挂字幕吗？",
                        style = LocalTypography.current.body,
                        color = FluentTheme.colors.text.text.primary
                    )
                }
            )

            ToastHost(
                toastManager = toastManager,
                modifier = Modifier.fillMaxSize()
            )
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

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun PlayerControlRow(
    playState: PlaybackState,
    mediaPlayer: MediampPlayer,
    videoProgress: Float,
    totalDuration: Long,
    playingInfoCache: PlayingInfoCache? = null,
    qualities: List<QualityResponse>? = null,
    currentResolution: String = "",
    currentBitrate: Int? = null,
    onSpeedControlHoverChanged: ((Boolean) -> Unit)? = null,
    onVolumeControlHoverChanged: ((Boolean) -> Unit)? = null,
    onQualityControlHoverChanged: ((Boolean) -> Unit)? = null,
    onQualitySelected: ((QualityResponse) -> Unit)? = null,
    isoTagData: IsoTagData? = null,
    onAudioSelected: ((AudioStream) -> Unit)? = null,
    onSubtitleSelected: ((SubtitleStream?) -> Unit)? = null,
    onOpenSubtitleSearch: (() -> Unit)? = null,
    onOpenAddNasSubtitle: (() -> Unit)? = null,
    onOpenAddLocalSubtitle: (() -> Unit)? = null,
    onSubtitleControlHoverChanged: ((Boolean) -> Unit)? = null,
    onSettingsMenuHoverChanged: ((Boolean) -> Unit)? = null,
    onRequestDeleteSubtitle: ((SubtitleStream) -> Unit)? = null
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
            verticalAlignment = Alignment.CenterVertically
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
            verticalAlignment = Alignment.CenterVertically
        ) {
            // 倍速
            SpeedControlFlyout(
                yOffset = 65,
                onHoverStateChanged = onSpeedControlHoverChanged,
                onSpeedSelected = { item ->
                    mediaPlayer.features[PlaybackSpeed]?.set(item.value)
                }
            )
            if (qualities != null) {
                QualityControlFlyout(
                    modifier = Modifier,
                    qualities = qualities,
                    currentResolution = currentResolution,
                    currentBitrate = currentBitrate,
                    yOffset = 65,
                    onHoverStateChanged = onQualityControlHoverChanged,
                    onQualitySelected = {
                        onQualitySelected?.invoke(it)
                    }
                )
            } else {
                Text(
                    text = "原画质",
                    style = LocalTypography.current.title,
                    color = Color.White.copy(alpha = 0.7843f),
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Normal,
                    modifier = Modifier
                )
            }
            SubtitleControlFlyout(
                playingInfoCache = playingInfoCache,
                isoTagData = isoTagData,
                onSubtitleSelected = { onSubtitleSelected?.invoke(it) },
                onOpenSubtitleSearch = { onOpenSubtitleSearch?.invoke() },
                onOpenAddNasSubtitle = { onOpenAddNasSubtitle?.invoke() },
                onOpenAddLocalSubtitle = { onOpenAddLocalSubtitle?.invoke() },
                modifier = Modifier.padding(start = 8.dp),
                onHoverStateChanged = onSubtitleControlHoverChanged,
                onRequestDelete = onRequestDeleteSubtitle
            )
            PlayerSettingsMenu(
                playingInfoCache = playingInfoCache,
                isoTagData = isoTagData,
                onAudioSelected = { audio ->
                    onAudioSelected?.invoke(audio)
                },
                modifier = Modifier.padding(start = 8.dp),
                onHoverStateChanged = onSettingsMenuHoverChanged
            )
            val audioLevelController =
                remember(mediaPlayer) { mediaPlayer.features[AudioLevelController] }
            val volume by audioLevelController?.volume?.collectAsState()
                ?: remember { mutableFloatStateOf(1f) }
            // 音量控制
            VolumeControl(
                volume = volume,
                onVolumeChange = {
                    audioLevelController?.setVolume(it)
                    PlayingSettingsStore.saveVolume(it)
                },
                onHoverStateChanged = onVolumeControlHoverChanged,
                modifier = Modifier.size(40.dp)
            )
            // 全屏
            val windowState = LocalWindowState.current
            val store = LocalStore.current
            FullScreenControl(
                isFullScreen = windowState.placement == WindowPlacement.Fullscreen,
                onClick = {
                    if (windowState.placement == WindowPlacement.Fullscreen) {
                        windowState.placement = WindowPlacement.Floating
                    } else {
                        windowState.placement = WindowPlacement.Fullscreen
                    }
                }
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
    val streamViewModel: StreamViewModel = koinViewModel()
    val playPlayViewModel: PlayPlayViewModel = koinViewModel()
    val playInfoViewModel: PlayInfoViewModel = koinViewModel()
    val userInfoViewModel: UserInfoViewModel = koinViewModel()
    val playRecordViewModel: PlayRecordViewModel = koinViewModel()
    val playerViewModel: PlayerViewModel = koinViewModel()
    val scope = rememberCoroutineScope()
    val playerManager = LocalPlayerManager.current
    return remember(
        streamViewModel,
        playPlayViewModel,
        playerViewModel,
        guid,
        player,
        playerManager,
        mediaGuid,
        currentAudioGuid,
        currentSubtitleGuid,
    ) {
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
                    playerViewModel = playerViewModel,
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
    playerViewModel: PlayerViewModel,
    playerManager: PlayerManager,
    mediaGuid: String?,
    currentAudioGuid: String?,
    currentSubtitleGuid: String?
) {
    try {
        // 获取播放信息
        val playInfoResponse = playInfoViewModel.loadDataAndWait(guid, mediaGuid)
        val startPosition: Long = playInfoResponse.ts.toLong() * 1000

        // 获取用户信息
        userInfoViewModel.loadUserInfo()
        val userInfoState = userInfoViewModel.uiState
            .filter { it is UiState.Success || it is UiState.Error }
            .first()

        val userInfo = when (userInfoState) {
            is UiState.Success -> userInfoState.data
            is UiState.Error -> throw Exception(userInfoState.message)
            else -> throw Exception("Unknown Error")
        }

        // 获取流信息
        val streamInfo = fetchStreamInfo(playInfoResponse, userInfo, streamViewModel)
        val videoStream = streamInfo.videoStream
        val audioStream =
            streamInfo.audioStreams.first { audioStream -> audioStream.guid == playInfoResponse.audioGuid }
        val audioGuid = currentAudioGuid ?: audioStream.guid
//        val subtitleStream = streamInfo.subtitleStreams?.first{ it.guid == playInfoResponse.subtitleGuid}
        val subtitleStream = streamInfo.subtitleStreams?.find {
            it.guid == playInfoResponse.subtitleGuid
        }
        val subtitleGuid = currentSubtitleGuid ?: subtitleStream?.guid
        val fileStream = streamInfo.fileStream

        // 缓存播放信息 (提前初始化，确保LocalFileInfo可用)
        val cache = PlayingInfoCache(
            streamInfo,
            "",
            fileStream,
            videoStream,
            audioStream,
            subtitleStream,
            playInfoResponse.item.guid,
            streamInfo.qualities,
            currentAudioStreamList = streamInfo.audioStreams,
            currentSubtitleStreamList = streamInfo.subtitleStreams
        )
        playerViewModel.updatePlayingInfo(cache)

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

        // VLC 播放器对 HDR 颜色空间有兼容问题，强制使用 SDR
        val forcedSdr = if (videoStream.colorRangeType != "SDR") 1 else 0

        // 构造播放请求
        val playRequest =
            createPlayRequest(videoStream, fileStream, audioGuid, subtitleGuid, forcedSdr)

        var playLink = ""
        // 获取播放链接
        try {
            val playResponse = playPlayViewModel.loadDataAndWait(playRequest)
            playLink = playResponse.playLink
        } catch (e: Exception) {
            if (e.message?.contains("8192") ?: true) {
                logger.i("使用直链播放")
                playLink = "/v/api/v1/media/range/${playInfoResponse.mediaGuid}"
            }
        }

        // 缓存播放信息
        val finalCache = cache.copy(playLink = playLink)
        playerViewModel.updatePlayingInfo(finalCache)

        logger.i("startPosition: $startPosition")
        // 设置字幕
        val extraFiles = subtitleStream?.let {
            val mediaExtraFiles = getMediaExtraFiles(it)
            mediaExtraFiles
        } ?: MediaExtraFiles()
        // 启动播放器
        startPlayback(player, playLink, startPosition, extraFiles)
        // 调用playRecord接口
            callPlayRecord(
//            itemGuid = guid,
                ts = if ((startPosition / 1000).toInt() == 0) 1 else (startPosition / 1000).toInt(),
                playingInfoCache = finalCache,
                playRecordViewModel = playRecordViewModel,
            onSuccess = {
                logger.i("起播时调用playRecord成功")
            },
            onError = {
                logger.e("起播时调用playRecord失败：缓存为空")
            },
        )
    } catch (e: Exception) {
        logger.e("播放失败: ${e.message}", e)
    }
}

private fun getMediaExtraFiles(
    subtitleStream: SubtitleStream
): MediaExtraFiles {
    if (subtitleStream.isExternal == 1 && subtitleStream.format in listOf("srt", "ass")) {
        val subtitleLink =
            "${AccountDataCache.getProxyBaseUrl()}/v/api/v1/subtitle/dl/${subtitleStream.guid}"
        val subtitle = Subtitle(subtitleLink)
        return MediaExtraFiles(listOf(subtitle))
    }
    return MediaExtraFiles()
}

private suspend fun fetchStreamInfo(
    playInfoResponse: PlayInfoResponse,
    userInfo: UserInfoResponse,
    streamViewModel: StreamViewModel
): StreamResponse {
    // 获取用户信息以获取source_name
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
    subtitleGuid: String?,
    forcedSdr: Int
): PlayPlayRequest {
    return PlayPlayRequest(
        videoGuid = videoStream.guid,
        mediaGuid = fileStream.guid,
        audioEncoder = "aac",
        audioGuid = audioGuid,
        bitrate = videoStream.bps,
        channels = 2,
        forcedSdr = forcedSdr,
        resolution = videoStream.resolutionType,
        startTimestamp = 0,
        subtitleGuid = subtitleGuid ?: "",
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
        logger.i("play param: headers: $headers, playUri: ${AccountDataCache.getFnOfficialBaseUrl()}$playLink, extraFiles: $extraFilesStr")
        player.playUri("${AccountDataCache.getFnOfficialBaseUrl()}$playLink", headers, extraFiles)
    } else {
        player.playUri(
            "${AccountDataCache.getFnOfficialBaseUrl()}$playLink",
            extraFiles = extraFiles
        )
    }
    delay(1500) // 等待播放器初始化
    player.features[PlaybackSpeed]?.set(1.0f)
    // 恢复音量
    val savedVolume = PlayingSettingsStore.getVolume()
    player.features[AudioLevelController]?.setVolume(savedVolume)

    logger.i("startPlayback startPosition: $startPosition")
    player.seekTo(startPosition)
}