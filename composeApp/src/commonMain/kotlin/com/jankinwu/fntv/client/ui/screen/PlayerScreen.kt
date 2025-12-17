@file:OptIn(ExperimentalResourceApi::class, kotlinx.coroutines.FlowPreview::class)

package com.jankinwu.fntv.client.ui.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.focusable
import androidx.compose.foundation.hoverable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
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
import androidx.compose.runtime.DisposableEffect
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
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEvent
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
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
import androidx.compose.ui.window.WindowState
import co.touchlab.kermit.Logger
import com.fasterxml.jackson.databind.DeserializationFeature
import com.fasterxml.jackson.databind.SerializationFeature
import com.fasterxml.jackson.module.kotlin.jacksonObjectMapper
import com.jankinwu.fntv.client.Platform
import com.jankinwu.fntv.client.currentPlatform
import com.jankinwu.fntv.client.data.constants.Colors
import com.jankinwu.fntv.client.data.convertor.FnDataConvertor
import com.jankinwu.fntv.client.data.model.PlayingInfoCache
import com.jankinwu.fntv.client.data.model.request.MediaPRequest
import com.jankinwu.fntv.client.data.model.request.PlayPlayRequest
import com.jankinwu.fntv.client.data.model.request.PlayRecordRequest
import com.jankinwu.fntv.client.data.model.request.StreamRequest
import com.jankinwu.fntv.client.data.model.response.AudioStream
import com.jankinwu.fntv.client.data.model.response.FileInfo
import com.jankinwu.fntv.client.data.model.response.MediaResetQualityResponse
import com.jankinwu.fntv.client.data.model.response.PlayInfoResponse
import com.jankinwu.fntv.client.data.model.response.PlayPlayResponse
import com.jankinwu.fntv.client.data.model.response.QualityResponse
import com.jankinwu.fntv.client.data.model.response.QueryTagResponse
import com.jankinwu.fntv.client.data.model.response.StreamResponse
import com.jankinwu.fntv.client.data.model.response.SubtitleStream
import com.jankinwu.fntv.client.data.model.response.UserInfoResponse
import com.jankinwu.fntv.client.data.model.response.VideoStream
import com.jankinwu.fntv.client.data.store.AccountDataCache
import com.jankinwu.fntv.client.data.store.AppSettingsStore
import com.jankinwu.fntv.client.data.store.PlayingSettingsStore
import com.jankinwu.fntv.client.enums.FnTvMediaType
import com.jankinwu.fntv.client.icons.ArrowLeft
import com.jankinwu.fntv.client.icons.Back10S
import com.jankinwu.fntv.client.icons.Forward10S
import com.jankinwu.fntv.client.icons.Pause
import com.jankinwu.fntv.client.icons.Play
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingProgressRing
import com.jankinwu.fntv.client.ui.component.common.ToastHost
import com.jankinwu.fntv.client.ui.component.common.ToastManager
import com.jankinwu.fntv.client.ui.component.common.ToastType
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
import com.jankinwu.fntv.client.utils.Mp4Parser
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
import io.github.composefluent.component.FontIconDefaults
import io.github.composefluent.component.FontIconSize
import io.github.composefluent.component.NavigationDefaults
import korlibs.crypto.MD5
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.unit.DpSize
import org.jetbrains.compose.resources.ExperimentalResourceApi
import org.koin.compose.koinInject
import org.koin.compose.viewmodel.koinViewModel
import org.openani.mediamp.MediampPlayer
import org.openani.mediamp.PlaybackState
import org.openani.mediamp.compose.MediampPlayerSurface
import org.openani.mediamp.features.AudioLevelController
import org.openani.mediamp.features.PlaybackSpeed
import org.openani.mediamp.features.VideoAspectRatio
import org.openani.mediamp.features.AspectRatioMode
import org.openani.mediamp.source.MediaExtraFiles
import org.openani.mediamp.source.Subtitle
import org.openani.mediamp.source.UriMediaData
import org.openani.mediamp.togglePause

private val logger = Logger.withTag("PlayerScreen")

data class PlayerState(
    val isVisible: Boolean = false,
    val isUiVisible: Boolean = true,
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
            isUiVisible = true,
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

    fun setUiVisible(visible: Boolean) {
        if (playerState.isVisible && playerState.isUiVisible != visible) {
            playerState = playerState.copy(isUiVisible = visible)
        }
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
    mediaPlayer: MediampPlayer,
    draggableArea: @Composable (content: @Composable () -> Unit) -> Unit = { it() }
) {
    // 控制UI可见性的状态
    var uiVisible by remember { mutableStateOf(true) }
    val playerManager = LocalPlayerManager.current
    LaunchedEffect(uiVisible) {
        playerManager.setUiVisible(uiVisible)
    }
    var isCursorVisible by remember { mutableStateOf(true) }
    var lastMouseMoveTime by remember { mutableLongStateOf(System.currentTimeMillis()) }
    val interactionSource = remember { MutableInteractionSource() }
    var isProgressBarHovered by remember { mutableStateOf(false) }
    var isSpeedControlHovered by remember { mutableStateOf(false) }
    var isVolumeControlHovered by remember { mutableStateOf(false) }
    var isQualityControlHovered by remember { mutableStateOf(false) }
    var isSettingsMenuHovered by remember { mutableStateOf(false) }
    var isSubtitleControlHovered by remember { mutableStateOf(false) }
    var lastVolume by remember { mutableFloatStateOf(0f) }
    val isPlayControlHovered =
        isSpeedControlHovered || isVolumeControlHovered || isQualityControlHovered || isSettingsMenuHovered || isSubtitleControlHovered
    val currentPosition by mediaPlayer.currentPositionMillis.collectAsState()
    val frameWindowScope = LocalFrameWindowScope.current
//    val scope = rememberCoroutineScope()
    val mediaPViewModel: MediaPViewModel = koinViewModel()
    val tagViewModel: TagViewModel = koinViewModel()
    val playerViewModel: PlayerViewModel = koinViewModel()
    val playPlayViewModel: PlayPlayViewModel = koinViewModel()
    val playPlayState by playPlayViewModel.uiState.collectAsState()
    val mp4Parser: Mp4Parser = koinInject()
    val playingInfoCache by playerViewModel.playingInfoCache.collectAsState()
    val resetQualityState by mediaPViewModel.resetQualityState.collectAsState()
    val quitMediaState by mediaPViewModel.quitState.collectAsState()
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

    val aspectRatioFeature = remember(mediaPlayer) { mediaPlayer.features[VideoAspectRatio] }
    LaunchedEffect(aspectRatioFeature) {
        aspectRatioFeature?.setMode(AspectRatioMode.FIT)
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

    val refreshSubtitleList =
        remember(playerViewModel, userInfoViewModel, streamViewModel, subtitleDeleteState) {
            {
                val cache = playerViewModel.playingInfoCache.value
                if (cache != null) {
                    kotlinx.coroutines.CoroutineScope(kotlinx.coroutines.Dispatchers.Main).launch {
                        try {
                            val userInfoState = userInfoViewModel.uiState.value
                            val userInfo =
                                if (userInfoState is UiState.Success) userInfoState.data else null

                            if (userInfo != null) {
                                val sourceName =
                                    userInfo.userSources.firstOrNull()?.sourceName ?: ""
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
                                playerViewModel.updateSubtitleList(
                                    streamResponse.subtitleStreams ?: emptyList(), streamResponse
                                )
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
    LaunchedEffect(playPlayState) {
        if (playPlayState is UiState.Success) {
            (playPlayState as UiState.Success<PlayPlayResponse>).data.let { playResponse ->
                val newPlayLink = playResponse.playLink
                playerViewModel.updatePlayingInfo(playingInfoCache?.copy(playLink = newPlayLink, isUseDirectLink = false))
                val extraFiles = playingInfoCache?.currentSubtitleStream?.let { getMediaExtraFiles(it) }
                    ?: MediaExtraFiles()
                startPlayback(mediaPlayer, newPlayLink, mediaPlayer.getCurrentPositionMillis(), extraFiles)
            }
        }
    }

    LaunchedEffect(quitMediaState) {
        if (quitMediaState is UiState.Success) {
            logger.i("Quality switch: Switching to Direct Link")
            val cache = playingInfoCache
            val startPos = mediaPlayer.getCurrentPositionMillis()
            if (cache != null) {
                val (link, start) = getDirectPlayLink(
                    cache.currentVideoStream.mediaGuid,
                    startPos,
                    mp4Parser
                )
                val extraFiles = cache.currentSubtitleStream?.let { getMediaExtraFiles(it) }
                    ?: MediaExtraFiles()
//                    mediaPlayer.stopPlayback()
                startPlayback(mediaPlayer, link, start, extraFiles)
            }
            mediaPViewModel.clearError()
        }
    }

    LaunchedEffect(resetQualityState) {
        if (resetQualityState is UiState.Success) {
            val response =
                (resetQualityState as UiState.Success<*>).data as? MediaResetQualityResponse
            if (response != null && response.result == "succ") {
//                val cache = playingInfoCache
//                if (cache != null) {
//                    val startPos = mediaPlayer.getCurrentPositionMillis()
//
//                    val newPlayLink = cache.playLink ?: ""
//                    val videoStream = cache.currentVideoStream
//
//                    val extraFiles = cache.currentSubtitleStream?.let { getMediaExtraFiles(it) }
//                        ?: MediaExtraFiles()
//                    mediaPlayer.stopPlayback()
//                    startPlayback(mediaPlayer, newPlayLink, startPos, extraFiles)
//                }
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
    val windowState = LocalWindowState.current

    // region Window Resize Logic
    var isProgrammaticResize by remember { mutableStateOf(true) }

    DisposableEffect(Unit) {
        val originalWidth = windowState.size.width
        val originalHeight = windowState.size.height
        val originalPlacement = windowState.placement

        // Save main window size on entry
        if (originalPlacement != WindowPlacement.Fullscreen && originalPlacement != WindowPlacement.Maximized) {
            AppSettingsStore.windowWidth = originalWidth.value
            AppSettingsStore.windowHeight = originalHeight.value
        }

        // Apply Player Fullscreen preference
        if (AppSettingsStore.playerIsFullscreen) {
            windowState.placement = WindowPlacement.Fullscreen
        }

        onDispose {
            // Save Player Preference on exit
            if (windowState.placement == WindowPlacement.Fullscreen) {
                AppSettingsStore.playerIsFullscreen = true
            } else {
                AppSettingsStore.playerIsFullscreen = false
                // Note: playerWindowWidth/Height are updated via LaunchedEffect below
            }

            // Restore Main Window State
            windowState.placement = originalPlacement
            if (originalPlacement != WindowPlacement.Fullscreen && originalPlacement != WindowPlacement.Maximized) {
                windowState.size = DpSize(originalWidth, originalHeight)
            }
        }
    }

    // Dynamic Resize based on Video
    LaunchedEffect(playingInfoCache?.currentVideoStream) {
        val videoStream = playingInfoCache?.currentVideoStream
        if (videoStream != null && !AppSettingsStore.playerIsFullscreen && windowState.placement != WindowPlacement.Fullscreen) {
            val baseWidth = AppSettingsStore.playerWindowWidth
            val baseHeight = AppSettingsStore.playerWindowHeight

            val optimalSize = calculateOptimalPlayerWindowSize(videoStream, baseWidth, baseHeight)
            if (optimalSize != null) {
                isProgrammaticResize = true
                windowState.size = optimalSize
            }
        }
    }

    // Monitor Manual Resize
    LaunchedEffect(windowState) {
        snapshotFlow { windowState.size }
            .debounce(500)
            .collect { size ->
                if (isProgrammaticResize) {
                    isProgrammaticResize = false
                } else {
                    if (windowState.placement != WindowPlacement.Fullscreen && windowState.placement != WindowPlacement.Maximized) {
                        AppSettingsStore.playerWindowWidth = size.width.value
                        AppSettingsStore.playerWindowHeight = size.height.value
                    }
                }
            }
    }
    // endregion

    val focusRequester = remember { FocusRequester() }
    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }

    CompositionLocalProvider(
        LocalIsoTagData provides isoTagData,
        LocalToastManager provides toastManager,
        LocalFileInfo provides playingInfoCache?.currentFileStream
    ) {
        BoxWithConstraints(
            modifier = Modifier
                .fillMaxSize()
                .hoverable(interactionSource)
                .background(Color.Black)
                .onKeyEvent { event ->
                    handlePlayerKeyEvent(
                        event,
                        mediaPlayer,
                        playingInfoCache,
                        playRecordViewModel,
                        playerManager,
                        audioLevelController,
                        windowState,
                        toastManager,
                        lastVolume,
                        { lastVolume = it }
                    )
                }
                .focusRequester(focusRequester)
                .focusable()
                .pointerHoverIcon(
                    if (isCursorVisible) PointerIcon.Hand else HiddenPointerIcon,
                    true
                )
        ) {
            // 视频层 - 从标题栏下方开始显示
            MediampPlayerSurface(
                mediaPlayer, Modifier
                    .size(maxWidth, maxHeight)
                    .clickable(
                        interactionSource = interactionSource,
                        indication = null,
                        onClick = {
                            mediaPlayer.togglePause()
                        }
                    )
                    .onPointerEvent(PointerEventType.Move) {
                        // 鼠标移动时更新时间并显示UI
                        lastMouseMoveTime = System.currentTimeMillis()
                        uiVisible = true
                        isCursorVisible = true
                    })

            if (windowState.placement != WindowPlacement.Fullscreen) {
                // 添加标题栏占位区域，允许窗口拖动
                draggableArea {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(48.dp) // 与标题栏高度一致
                    )
                }
            }
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
            val platform = currentPlatform()
            // 播放器 UI
            if (uiVisible) {
                PlayerTopBar(
                    mediaTitle = mediaTitle,
                    subhead = subhead,
                    isEpisode = isEpisode,
                    onBack = onBack,
                    mediaPlayer = mediaPlayer,
                    playerViewModel = playerViewModel,
                    windowState = windowState,
                    platform = platform
                )

                PlayerBottomBar(
                    mediaPlayer = mediaPlayer,
                    playerManager = playerManager,
                    playState = playState,
                    videoProgress = videoProgress,
                    totalDuration = totalDuration,
                    playingInfoCache = playingInfoCache,
                    isoTagData = isoTagData,
                    lastVolume = lastVolume,
                    onProgressBarHoverChanged = { isProgressBarHovered = it },
                    onResetMouseMoveTimer = { lastMouseMoveTime = System.currentTimeMillis() },
                    onSeek = { newProgress ->
                        val seekPosition = (newProgress * totalDuration).toLong()
                        mediaPlayer.seekTo(seekPosition)
                        logger.i("Seek to: ${newProgress * 100}%")

                        callPlayRecord(
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
                    onSpeedControlHoverChanged = { isSpeedControlHovered = it },
                    onVolumeControlHoverChanged = { isVolumeControlHovered = it },
                    onQualityControlHoverChanged = { isQualityControlHovered = it },
                    onQualitySelected = { quality ->
                        handleQualitySelection(
                            quality,
                            playingInfoCache,
                            mediaPlayer,
                            playerViewModel,
                            mediaPViewModel,
                            playPlayViewModel
                        )
                    },
                    onAudioSelected = { audio ->
                        val cache = playingInfoCache
                        if (cache != null) {
                            val request = MediaPRequest(
                                req = "media.resetAudio",
                                reqId = "1234567890ABCDEF2s",
                                playLink = cache.playLink ?: "",
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
                            playerViewModel.updatePlayingInfo(
                                cache.copy(
                                    currentSubtitleStream = subtitle
                                )
                            )
                            if (subtitle != null) {
                                val request = MediaPRequest(
                                    req = "media.resetSubtitle",
                                    reqId = "1234567890ABCDEF",
                                    playLink = cache.playLink ?: "",
                                    subtitleIndex = subtitle.index,
                                    startTimestamp = (mediaPlayer.getCurrentPositionMillis() / 1000).toInt(),
                                )
                                mediaPViewModel.resetSubtitle(request)
                            } else {
                                val request = MediaPRequest(
                                    req = "media.resetSubtitle",
                                    reqId = "1234567890ABCDEF",
                                    playLink = cache.playLink ?: "",
                                    startTimestamp = (mediaPlayer.getCurrentPositionMillis() / 1000).toInt(),
                                )
                                mediaPViewModel.resetSubtitle(request)
                            }
                        }
                    },
                    onOpenSubtitleSearch = { showSubtitleSearchDialog = true },
                    onOpenAddNasSubtitle = { showAddNasSubtitleDialog = true },
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
                    onSubtitleControlHoverChanged = { isSubtitleControlHovered = it },
                    onSettingsMenuHoverChanged = { isSettingsMenuHovered = it },
                    onRequestDeleteSubtitle = { subtitle ->
                        subtitleToDelete = subtitle
                        showDeleteSubtitleDialog = true
                    },
                    onLastVolumeChange = { lastVolume = it }
                )
            }

            PlayerDialogs(
                showSubtitleSearchDialog = showSubtitleSearchDialog,
                onSubtitleSearchDialogDismiss = { showSubtitleSearchDialog = false },
                showAddNasSubtitleDialog = showAddNasSubtitleDialog,
                onAddNasSubtitleDialogDismiss = { showAddNasSubtitleDialog = false },
                showDeleteSubtitleDialog = showDeleteSubtitleDialog,
                onDeleteSubtitleDialogDismiss = {
                    showDeleteSubtitleDialog = false
                    subtitleToDelete = null
                },
                playingInfoCache = playingInfoCache,
                subtitleToDelete = subtitleToDelete,
                onSubtitleDeleteConfirm = {
                    subtitleToDelete?.let {
                        subtitleDeleteViewModel.deleteSubtitle(it.guid)
                    }
                },
                refreshSubtitleList = refreshSubtitleList
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

fun buildMacOsEpisodeTitle(mediaTitle: String, subhead: String): AnnotatedString {
    val annotatedString = buildAnnotatedString {
        withStyle(
            style = SpanStyle(
                color = Color.White,
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                fontFamily = defaultVariableFamily
            )
        ) {
            append(mediaTitle)
        }
        withStyle(
            style = SpanStyle(
                color = Color.White,
                fontSize = 16.sp,
                fontWeight = FontWeight.ExtraLight,
                fontFamily = defaultVariableFamily
            )
        ) {
            append(" / ")
        }
        withStyle(
            style = SpanStyle(
                color = Colors.TextSecondaryColor,
                fontSize = 16.sp,
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
    onRequestDeleteSubtitle: ((SubtitleStream) -> Unit)? = null,
    lastVolume: Float = 0f,
    onLastVolumeChange: (Float) -> Unit = {}
) {
    val interactionSource = remember { MutableInteractionSource() }
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
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
                text = "${FnDataConvertor.formatDurationToDateTime((videoProgress * totalDuration).toLong())} / ${
                    FnDataConvertor.formatDurationToDateTime(totalDuration)
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
            val qualities = playingInfoCache?.currentQualities
            if (qualities != null) {
                QualityControlFlyout(
                    modifier = Modifier,
                    qualities = qualities,
                    currentResolution = playingInfoCache?.currentQuality?.resolution ?: "",
                    currentBitrate = playingInfoCache?.currentQuality?.bitrate,
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
                modifier = Modifier.padding(start = 12.dp),
                onHoverStateChanged = onSubtitleControlHoverChanged,
                onRequestDelete = onRequestDeleteSubtitle
            )
            PlayerSettingsMenu(
                playingInfoCache = playingInfoCache,
                isoTagData = isoTagData,
                onAudioSelected = { audio ->
                    onAudioSelected?.invoke(audio)
                },
                modifier = Modifier.padding(start = 12.dp),
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
                    onLastVolumeChange(0f)
                },
                onHoverStateChanged = onVolumeControlHoverChanged,
                modifier = Modifier.size(50.dp)
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
    val mp4Parser: Mp4Parser = koinInject()
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
        mp4Parser
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
                    currentSubtitleGuid = currentSubtitleGuid,
                    mp4Parser = mp4Parser
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
    currentSubtitleGuid: String?,
    mp4Parser: Mp4Parser
) {
    try {
        // 获取播放信息
        val playInfoResponse = playInfoViewModel.loadDataAndWait(guid, mediaGuid)
        val startPosition: Long = playInfoResponse.ts.toLong() * 1000

        // 获取用户信息
        val userInfo = getUserInfo(userInfoViewModel)

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
        val cache = createPlayingInfoCache(
            streamInfo,
            fileStream,
            videoStream,
            audioStream,
            subtitleStream,
            playInfoResponse
        )
        playerViewModel.updatePlayingInfo(cache)

        // 显示播放器
        showPlayerUI(playInfoResponse, videoStream, playerManager, guid)

        // VLC 播放器对 HDR 颜色空间有兼容问题，强制使用 SDR
        val forcedSdr = if (videoStream.colorRangeType != "SDR") 1 else 0

        // 构造播放请求
        val playRequest =
            createPlayRequest(videoStream, fileStream, audioGuid, subtitleGuid, forcedSdr)

        // 获取播放链接
        val playLinkResult = resolvePlayLink(
            playRequest,
            cache,
            streamInfo,
            startPosition,
            mp4Parser,
            playPlayViewModel,
            playInfoResponse
        )

        // 缓存播放信息
        val finalCache = cache.copy(
            playLink = playLinkResult.playLink,
            isUseDirectLink = playLinkResult.isDirectLink
        )
        playerViewModel.updatePlayingInfo(finalCache)

        logger.i("startPosition: $startPosition, effectiveStartPosition: ${playLinkResult.effectiveStartPosition}")
        // 设置字幕
        val extraFiles = subtitleStream?.let {
            val mediaExtraFiles = getMediaExtraFiles(it)
            mediaExtraFiles
        } ?: MediaExtraFiles()
        // 启动播放器
        startPlayback(
            player,
            playLinkResult.playLink,
            playLinkResult.effectiveStartPosition,
            extraFiles
        )
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

private suspend fun getDirectPlayLink(
    mediaGuid: String,
    startPosition: Long,
    mp4Parser: Mp4Parser
): Pair<String, Long> {
    val directLinkBase = "/v/api/v1/media/range/${mediaGuid}"
    val fullUrl = "${AccountDataCache.getProxyBaseUrl()}$directLinkBase"
    val ts = startPosition / 1000.0

    return try {
        val offset = mp4Parser.getOffset(fullUrl, ts)
        if (offset > 0) {
            val link = "$directLinkBase?range=bytes=$offset-"
            link to 0L
        } else {
            directLinkBase to startPosition
        }
    } catch (ex: Exception) {
        logger.e(ex) { "Failed to calculate offset" }
        directLinkBase to startPosition
    }
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
    val isDirectLink = playLink.contains("/v/api/v1/media/range/")
    val baseUrl = if (AccountDataCache.cookieState.isNotBlank() && isDirectLink) {
        AccountDataCache.getProxyBaseUrl()
    } else {
        AccountDataCache.getFnOfficialBaseUrl()
    }

    if (AccountDataCache.cookieState.isNotBlank()) {
        val headers = mapOf(
            "cookie" to AccountDataCache.cookieState,
            "Authorization" to AccountDataCache.authorization
        )
//        headers["Authorization"] = AccountDataCache.authorization
        val extraFilesStr = PlayerScreen.mapper.writeValueAsString(extraFiles)
        logger.i("play param: headers: $headers, playUri: $baseUrl$playLink, extraFiles: $extraFilesStr")
        player.playUri("$baseUrl$playLink", headers, extraFiles)
    } else {
        player.playUri(
            "$baseUrl$playLink",
            extraFiles = extraFiles
        )
    }
    if (!isDirectLink) {
        delay(1000) // 等待播放器初始化
    } else {
        delay(200)
    }
    player.features[PlaybackSpeed]?.set(1.0f)
    // 恢复音量
    val savedVolume = PlayingSettingsStore.getVolume()
    player.features[AudioLevelController]?.setVolume(savedVolume)

    logger.i("startPlayback startPosition: $startPosition")
    player.seekTo(startPosition)
}

private data class PlayLinkResult(
    val playLink: String,
    val effectiveStartPosition: Long,
    val isDirectLink: Boolean
)

private suspend fun getUserInfo(userInfoViewModel: UserInfoViewModel): UserInfoResponse {
    userInfoViewModel.loadUserInfo()
    val userInfoState = userInfoViewModel.uiState
        .filter { it is UiState.Success || it is UiState.Error }
        .first()

    return when (userInfoState) {
        is UiState.Success -> userInfoState.data
        is UiState.Error -> throw Exception(userInfoState.message)
        else -> throw Exception("Unknown Error")
    }
}

private fun initializeQuality(qualities: List<QualityResponse>?): QualityResponse? {
    if (qualities.isNullOrEmpty()) return null

    val saved = PlayingSettingsStore.getQuality()
    var result: QualityResponse? = null

    if (saved != null) {
        val matched = qualities.find { it.resolution == saved.resolution && (saved.bitrate == null || it.bitrate == saved.bitrate) }
        if (matched != null) {
            result = matched
        } else {
            // Try match resolution only, pick highest bitrate
            val matchedRes = qualities.filter { it.resolution == saved.resolution }
                .maxByOrNull { it.bitrate }
            if (matchedRes != null) {
                result = matchedRes
            }
        }
    }

    if (result == null) {
        result = qualities.firstOrNull()
    }

    logger.i("Initialize quality, Current resolution: ${result?.resolution}, bitrate: ${result?.bitrate}")
    return result
}

private fun createPlayingInfoCache(
    streamInfo: StreamResponse,
    fileStream: FileInfo,
    videoStream: VideoStream,
    audioStream: AudioStream,
    subtitleStream: SubtitleStream?,
    playInfoResponse: PlayInfoResponse
): PlayingInfoCache {
    val currentQuality = initializeQuality(streamInfo.qualities)
    return PlayingInfoCache(
        streamInfo,
        "",
        fileStream,
        videoStream,
        audioStream,
        subtitleStream,
        playInfoResponse.item.guid,
        streamInfo.qualities,
        currentQuality = currentQuality,
        currentAudioStreamList = streamInfo.audioStreams,
        currentSubtitleStreamList = streamInfo.subtitleStreams
    )
}

private fun showPlayerUI(
    playInfoResponse: PlayInfoResponse,
    videoStream: VideoStream,
    playerManager: PlayerManager,
    guid: String
) {
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
}

private suspend fun resolvePlayLink(
    playRequest: PlayPlayRequest,
    cache: PlayingInfoCache,
    streamInfo: StreamResponse,
    startPosition: Long,
    mp4Parser: Mp4Parser,
    playPlayViewModel: PlayPlayViewModel,
    playInfoResponse: PlayInfoResponse
): PlayLinkResult {
    val currentQuality = cache.currentQuality ?: streamInfo.qualities.firstOrNull()
    val originalQuality = streamInfo.qualities.firstOrNull()
    val isOriginalQuality = currentQuality != null && originalQuality != null &&
            currentQuality.resolution == originalQuality.resolution &&
            currentQuality.bitrate == originalQuality.bitrate

    val videoStream = cache.currentVideoStream
    val streamMatchesSelected = videoStream.resolutionType == currentQuality?.resolution &&
            videoStream.bps == currentQuality.bitrate

    val useDirectLink = videoStream.wrapper == "MP4" &&
            videoStream.colorRangeType == "SDR" &&
            isOriginalQuality && streamMatchesSelected

    if (useDirectLink) {
        logger.i("满足直链播放条件: wrapper=MP4, colorRangeType=SDR, isOriginalQuality=true")
        val (link, start) = getDirectPlayLink(
            videoStream.mediaGuid,
            startPosition,
            mp4Parser
        )
        return PlayLinkResult(link, start, isDirectLink = true)
    } else {
        try {
            val playResponse = playPlayViewModel.loadDataAndWait(playRequest)
            return PlayLinkResult(playResponse.playLink, startPosition, isDirectLink = false)
        } catch (e: Exception) {
            if (e.message?.contains("8192") == true) {
                logger.i("播放接口返回8192，降级使用直链播放")
                val (link, start) = getDirectPlayLink(
                    playInfoResponse.mediaGuid,
                    startPosition,
                    mp4Parser
                )
                return PlayLinkResult(link, start, isDirectLink = false)
            }
            throw e
        }
    }
}

private fun calculateOptimalPlayerWindowSize(
    videoStream: VideoStream,
    baseWidth: Float,
    baseHeight: Float
): DpSize? {
    val videoW = videoStream.width.toFloat()
    val videoH = videoStream.height.toFloat()

    if (videoW <= 0 || videoH <= 0) return null

    // 优先使用 displayAspectRatio 计算宽高比，解决非 1:1 像素比视频的黑边问题
    val videoAR = parseAspectRatio(videoStream.displayAspectRatio) ?: (videoW / videoH)

    var targetH = baseHeight
    var targetW = targetH * videoAR

    // Constraints: +/- 30% of Base (Adjusted to +/- 50% based on recent context)
    val minW = baseWidth * 0.5f
    val maxW = baseWidth * 1.5f

    // If width is out of bounds, try fixing width
    if (targetW < minW || targetW > maxW) {
        val targetW2 = baseWidth
        val targetH2 = targetW2 / videoAR

        val minH = baseHeight * 0.5f
        val maxH = baseHeight * 1.5f

        if (targetH2 >= minH && targetH2 <= maxH) {
            targetW = targetW2
            targetH = targetH2
        } else {
            // Both out of bounds?
            // Just clamp width to nearest bound and adjust height to match AR
            if (targetW < minW) targetW = minW
            if (targetW > maxW) targetW = maxW
            targetH = targetW / videoAR
        }
    }
    
    // Apply user defined width compensation
    targetW += AppSettingsStore.playerWindowWidthCompensation
    
    return DpSize(targetW.dp, targetH.dp)
}

private fun parseAspectRatio(dar: String?): Float? {
    if (dar.isNullOrBlank()) return null
    return try {
        val parts = dar.split(":")
        if (parts.size == 2) {
            val w = parts[0].toFloat()
            val h = parts[1].toFloat()
            if (h > 0) w / h else null
        } else {
            null
        }
    } catch (e: Exception) {
        null
    }
}

private fun handlePlayerKeyEvent(
    event: KeyEvent,
    mediaPlayer: MediampPlayer,
    playingInfoCache: PlayingInfoCache?,
    playRecordViewModel: PlayRecordViewModel,
    playerManager: PlayerManager,
    audioLevelController: AudioLevelController?,
    windowState: WindowState,
    toastManager: ToastManager,
    lastVolume: Float,
    onLastVolumeChange: (Float) -> Unit
): Boolean {
    if (event.type == KeyEventType.KeyDown) {
        var handled = true
        when (event.key) {
            Key.M, Key.VolumeMute -> {
                audioLevelController?.let {
                    val currentVolume = it.volume.value
                    if (currentVolume > 0) {
                        onLastVolumeChange(currentVolume)
                        it.setVolume(0f)
                        PlayingSettingsStore.saveVolume(0f)
                        toastManager.showToast("静音", ToastType.Info, category = "volume")
                    } else {
                        val restoreVolume = if (lastVolume > 0) lastVolume else 0.05f
                        it.setVolume(restoreVolume)
                        PlayingSettingsStore.saveVolume(restoreVolume)
                        toastManager.showToast(
                            "解除静音：${(restoreVolume * 100).toInt()}%",
                            ToastType.Info,
                            category = "volume"
                        )
                    }
                }
            }

            Key.DirectionLeft, Key.MediaStepBackward -> {
                val seekPosition =
                    (mediaPlayer.currentPositionMillis.value - 10000).coerceAtLeast(0)
                mediaPlayer.seekTo(seekPosition)
                val dateTime = FnDataConvertor.formatDurationToDateTime(seekPosition)
                toastManager.showToast("快退至：$dateTime", ToastType.Info, category = "seek")
                callPlayRecord(
                    ts = (seekPosition / 1000).toInt(),
                    playingInfoCache = playingInfoCache,
                    playRecordViewModel = playRecordViewModel,
                    onSuccess = { logger.i("Seek时调用playRecord成功") },
                    onError = { logger.i("Seek时调用playRecord失败：缓存为空") }
                )
            }

            Key.DirectionRight, Key.MediaStepForward -> {
                val seekPosition =
                    (mediaPlayer.currentPositionMillis.value + 10000).coerceAtMost(playerManager.playerState.duration)
                mediaPlayer.seekTo(seekPosition)
                val dateTime = FnDataConvertor.formatDurationToDateTime(seekPosition)
                toastManager.showToast("快进至：$dateTime", ToastType.Info, category = "seek")
                callPlayRecord(
                    ts = (seekPosition / 1000).toInt(),
                    playingInfoCache = playingInfoCache,
                    playRecordViewModel = playRecordViewModel,
                    onSuccess = { logger.i("Seek时调用playRecord成功") },
                    onError = { logger.i("Seek时调用playRecord失败：缓存为空") }
                )
            }

            Key.DirectionUp, Key.VolumeUp -> {
                audioLevelController?.let {
                    val newVolume = (it.volume.value + 0.1f).coerceIn(0f, 1f)
                    it.setVolume(newVolume)
                    toastManager.showToast(
                        "当前音量：${(newVolume * 100).toInt()}%",
                        ToastType.Info,
                        category = "volume"
                    )
                    PlayingSettingsStore.saveVolume(newVolume)
                    onLastVolumeChange(0f)
                }
            }

            Key.DirectionDown, Key.VolumeDown -> {
                audioLevelController?.let {
                    val newVolume = (it.volume.value - 0.1f).coerceIn(0f, 1f)
                    it.setVolume(newVolume)
                    toastManager.showToast(
                        "当前音量：${(newVolume * 100).toInt()}%",
                        ToastType.Info,
                        category = "volume"
                    )
                    PlayingSettingsStore.saveVolume(newVolume)
                    onLastVolumeChange(0f)
                }
            }

            Key.Spacebar, Key.MediaPlayPause -> {
                mediaPlayer.togglePause()
            }

            Key.MediaStop -> {
                mediaPlayer.pause()
            }

            Key.F, Key.Escape -> {
                if (windowState.placement == WindowPlacement.Fullscreen) {
                    windowState.placement = WindowPlacement.Floating
                } else {
                    windowState.placement = WindowPlacement.Fullscreen
                }
            }

            else -> handled = false
        }
        return handled
    } else {
        return false
    }
}

private fun handleQualitySelection(
    quality: QualityResponse,
    playingInfoCache: PlayingInfoCache?,
    mediaPlayer: MediampPlayer,
    playerViewModel: PlayerViewModel,
    mediaPViewModel: MediaPViewModel,
    playPlayViewModel: PlayPlayViewModel
) {
    PlayingSettingsStore.saveQuality(quality.resolution, quality.bitrate)
//    logger.i("1 change quality to: ${quality.resolution}")
    if (playingInfoCache != null) {
        val currentQuality = playingInfoCache.currentQuality
        val originalQuality = playingInfoCache.streamInfo.qualities.firstOrNull()
        val videoStream = playingInfoCache.currentVideoStream
        val currentResolution = quality.resolution
        val currentBitrate = quality.bitrate

        val isTargetOriginalQuality =
            currentQuality != null && originalQuality != null &&
                    currentResolution == originalQuality.resolution &&
                    currentBitrate == originalQuality.bitrate

        val canUseDirectLink = videoStream.wrapper == "MP4" &&
                videoStream.colorRangeType == "SDR"
        logger.i("change quality to: ${quality.resolution}, useDirectLink: ${playingInfoCache.isUseDirectLink}, " +
                "originalQuality: ${originalQuality}, canUseDirectLink: ${canUseDirectLink}, isTargetOriginalQuality: $isTargetOriginalQuality")
        // If currently not using direct link, and video can be direct linked, and target quality is original, call media.quit
        if (!playingInfoCache.isUseDirectLink && isTargetOriginalQuality && canUseDirectLink) {
            logger.i("switch to direct link")
            playerViewModel.updatePlayingInfo(
                playingInfoCache.copy(
                    currentQuality = quality,
                    isUseDirectLink = true,
                    playLink = null
                )
            )
            mediaPViewModel.quit(
                MediaPRequest(
                    playLink = playingInfoCache.playLink ?: ""
                )
            )
        }
        // If current video can be direct linked and target is not original, or cannot be direct linked and target is original, call media.resetQuality
        if (!playingInfoCache.isUseDirectLink) {
            if ((!isTargetOriginalQuality && canUseDirectLink) || !canUseDirectLink) {
                logger.i("call reset quality")
                playerViewModel.updatePlayingInfo(
                    playingInfoCache.copy(
                        currentQuality = quality,
                        isUseDirectLink = false
                    )
                )
                val request = MediaPRequest(
                    req = "media.resetQuality",
                    reqId = "${System.currentTimeMillis()}",
                    playLink = playingInfoCache.playLink ?: "",
                    quality = MediaPRequest.Quality(
                        quality.resolution,
                        quality.bitrate
                    ),
                    startTimestamp = (mediaPlayer.getCurrentPositionMillis() / 1000).toInt(),
                    clearCache = true
                )
                mediaPViewModel.resetQuality(request)
                playerViewModel.updatePlayingInfo(
                    playingInfoCache.copy(
                        currentQuality = quality,
                        isUseDirectLink = false
                    )
                )
            }
        }
        if (playingInfoCache.isUseDirectLink) {
            logger.i("switch to HLS")
            val forcedSdr = if (videoStream.colorRangeType != "SDR") 1 else 0
            val playRequest = createPlayRequest(
                videoStream,
                playingInfoCache.currentFileStream,
                playingInfoCache.currentAudioStream?.guid ?: "",
                playingInfoCache.currentSubtitleStream?.guid,
                forcedSdr
            )
            playerViewModel.updatePlayingInfo(
                playingInfoCache.copy(
                    currentQuality = quality,
                    isUseDirectLink = false
                )
            )
            try {
                playPlayViewModel.loadData(playRequest)
            } catch (e: Exception) {
                logger.e("Failed to fetch HLS link", e)
            }
        }
    }
}

@Composable
fun PlayerTopBar(
    mediaTitle: String,
    subhead: String,
    isEpisode: Boolean,
    onBack: () -> Unit,
    mediaPlayer: MediampPlayer,
    playerViewModel: PlayerViewModel,
    windowState: WindowState,
    platform: Platform
) {
    if (platform is Platform.MacOS) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
//                .padding(top = 10.dp)
        ) {
            Box(
                modifier = Modifier
                    .align(Alignment.CenterStart)
                    .padding(start = 80.dp),
                contentAlignment = Alignment.Center
            ) {
                val interaction = remember { MutableInteractionSource() }
                NavigationDefaults.BackButton(
                    onClick = {
                        mediaPlayer.stopPlayback()
                        playerViewModel.updatePlayingInfo(null)
                        onBack()
                        if (windowState.placement == WindowPlacement.Fullscreen) {
                            windowState.placement = WindowPlacement.Floating
                        }
                    },
                    interaction = interaction,
                    icon = {
                        FontIconDefaults.BackIcon(interaction, size = FontIconSize(16f))
                    }
                )
            }
            Box(
                modifier = Modifier.align(Alignment.Center),
                contentAlignment = Alignment.Center
            ) {
                if (isEpisode) {
                    Text(
                        text = buildMacOsEpisodeTitle(mediaTitle, subhead),
                        style = LocalTypography.current.title,
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium
                    )
                } else {
                    Text(
                        text = mediaTitle,
                        style = LocalTypography.current.title,
                        color = Color.White,
                        fontSize = 16.sp,
                        fontWeight = FontWeight.Medium
                    )
                }
            }
        }
    } else {
        Row(
            modifier = Modifier
                .padding(top = 12.dp)
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
}

@Composable
fun PlayerDialogs(
    showSubtitleSearchDialog: Boolean,
    onSubtitleSearchDialogDismiss: () -> Unit,
    showAddNasSubtitleDialog: Boolean,
    onAddNasSubtitleDialogDismiss: () -> Unit,
    showDeleteSubtitleDialog: Boolean,
    onDeleteSubtitleDialogDismiss: () -> Unit,
    playingInfoCache: PlayingInfoCache?,
    subtitleToDelete: SubtitleStream?,
    onSubtitleDeleteConfirm: () -> Unit,
    refreshSubtitleList: () -> Unit
) {
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
            onDismissRequest = onSubtitleSearchDialogDismiss,
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
                    onAddNasSubtitleDialogDismiss()
                } else if (button == ContentDialogButton.Close) {
                    onAddNasSubtitleDialogDismiss()
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
                    onSubtitleDeleteConfirm()
                }

                else -> {}
            }
            onDeleteSubtitleDialogDismiss()
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
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun PlayerBottomBar(
    mediaPlayer: MediampPlayer,
    playerManager: PlayerManager,
    playState: PlaybackState,
    videoProgress: Float,
    totalDuration: Long,
    playingInfoCache: PlayingInfoCache?,
    isoTagData: IsoTagData,
    lastVolume: Float,
    onProgressBarHoverChanged: (Boolean) -> Unit,
    onResetMouseMoveTimer: () -> Unit,
    onSeek: (Float) -> Unit,
    onSpeedControlHoverChanged: (Boolean) -> Unit,
    onVolumeControlHoverChanged: (Boolean) -> Unit,
    onQualityControlHoverChanged: (Boolean) -> Unit,
    onQualitySelected: (QualityResponse) -> Unit,
    onAudioSelected: (AudioStream) -> Unit,
    onSubtitleSelected: (SubtitleStream?) -> Unit,
    onOpenSubtitleSearch: () -> Unit,
    onOpenAddNasSubtitle: () -> Unit,
    onOpenAddLocalSubtitle: () -> Unit,
    onSubtitleControlHoverChanged: (Boolean) -> Unit,
    onSettingsMenuHoverChanged: (Boolean) -> Unit,
    onRequestDeleteSubtitle: (SubtitleStream) -> Unit,
    onLastVolumeChange: (Float) -> Unit
) {
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
                    onProgressBarHoverChanged(true)
                }
                .onPointerEvent(PointerEventType.Exit) {
                    onProgressBarHoverChanged(false)
                    onResetMouseMoveTimer()
                }
        ) {
            VideoPlayerProgressBar(
                player = mediaPlayer,
                totalDuration = playerManager.playerState.duration,
                onSeek = onSeek,
                modifier = Modifier.padding(horizontal = 8.dp, vertical = 8.dp)
            )
            // 播放器控制行
            PlayerControlRow(
                playState,
                mediaPlayer,
                videoProgress,
                totalDuration,
                playingInfoCache = playingInfoCache,
                onSpeedControlHoverChanged = onSpeedControlHoverChanged,
                onVolumeControlHoverChanged = onVolumeControlHoverChanged,
                onQualityControlHoverChanged = onQualityControlHoverChanged,
                onQualitySelected = onQualitySelected,
                isoTagData = isoTagData,
                onAudioSelected = onAudioSelected,
                onSubtitleSelected = onSubtitleSelected,
                onOpenSubtitleSearch = onOpenSubtitleSearch,
                onOpenAddNasSubtitle = onOpenAddNasSubtitle,
                onOpenAddLocalSubtitle = onOpenAddLocalSubtitle,
                onSubtitleControlHoverChanged = onSubtitleControlHoverChanged,
                onSettingsMenuHoverChanged = onSettingsMenuHoverChanged,
                onRequestDeleteSubtitle = onRequestDeleteSubtitle,
                lastVolume = lastVolume,
                onLastVolumeChange = onLastVolumeChange
            )
        }
    }
}