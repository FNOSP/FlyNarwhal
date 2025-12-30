package com.jankinwu.fntv.client.ui.window

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsHoveredAsState
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.Icon
import androidx.compose.material.IconButton
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.BiasAlignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerHoverIcon
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.WindowPosition
import androidx.compose.ui.window.rememberWindowState
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.network.fnOfficialClient
import com.jankinwu.fntv.client.data.store.PlayingSettingsStore
import com.jankinwu.fntv.client.icons.Back10S
import com.jankinwu.fntv.client.icons.Forward10S
import com.jankinwu.fntv.client.icons.PlayCircle
import com.jankinwu.fntv.client.manager.PlayerResourceManager
import com.jankinwu.fntv.client.ui.component.common.ImgLoadingProgressRing
import com.jankinwu.fntv.client.ui.component.player.SubtitleOverlay
import com.jankinwu.fntv.client.ui.component.player.VideoPlayerProgressBar
import com.jankinwu.fntv.client.ui.component.player.VolumeControl
import com.jankinwu.fntv.client.ui.providable.LocalMediaPlayer
import com.jankinwu.fntv.client.ui.providable.LocalPlayerManager
import com.jankinwu.fntv.client.utils.ExternalSubtitleUtil
import com.jankinwu.fntv.client.utils.HlsSubtitleUtil
import com.jankinwu.fntv.client.utils.SubtitleCue
import com.jankinwu.fntv.client.utils.calculateOptimalPlayerWindowSize
import com.jankinwu.fntv.client.utils.callPlayRecord
import com.jankinwu.fntv.client.utils.rememberSmoothVideoTime
import com.jankinwu.fntv.client.viewmodel.PlayRecordViewModel
import com.jankinwu.fntv.client.viewmodel.PlayerViewModel
import com.jankinwu.fntv.client.window.findSkiaLayer
import fntv_client_multiplatform.composeapp.generated.resources.Res
import fntv_client_multiplatform.composeapp.generated.resources.icon
import io.github.alexzhirkevich.compottie.animateLottieCompositionAsState
import io.github.alexzhirkevich.compottie.rememberLottieComposition
import io.github.alexzhirkevich.compottie.rememberLottiePainter
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.debounce
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.jetbrains.compose.resources.painterResource
import org.koin.compose.viewmodel.koinViewModel
import org.openani.mediamp.PlaybackState
import org.openani.mediamp.compose.MediampPlayerSurface
import org.openani.mediamp.features.AudioLevelController
import java.awt.MouseInfo
import java.awt.Point

@OptIn(ExperimentalComposeUiApi::class, kotlinx.coroutines.FlowPreview::class)
@Composable
fun PipPlayerWindow(
    onClose: () -> Unit,
    onExitPip: () -> Unit
) {
    val mediaPlayer = LocalMediaPlayer.current
    val playbackState by mediaPlayer.playbackState.collectAsState()
    val playerViewModel: PlayerViewModel = koinViewModel()
    val playRecordViewModel: PlayRecordViewModel = koinViewModel()
    val playingInfoCache by playerViewModel.playingInfoCache.collectAsState()
    val subtitleSettings by playerViewModel.subtitleSettings.collectAsState()
    val savedData = remember { PlayingSettingsStore.getPipWindowData() }

    val logger = remember { Logger.withTag("PipPlayerWindow") }
    val rewindInteractionSource = remember { MutableInteractionSource() }
    val forwardInteractionSource = remember { MutableInteractionSource() }

    // 上一次播放状态
    var lastPlayState by remember { mutableStateOf<PlaybackState?>(null) }

    var isLoading by remember { mutableStateOf(false) }

    LaunchedEffect(playbackState) {
        if (playbackState == PlaybackState.PLAYING || playbackState == PlaybackState.PAUSED) {
            isLoading = false
        }
    }

    LaunchedEffect(isLoading) {
        if (isLoading) {
            delay(2000)
            if (isLoading) {
                isLoading = false
            }
        }
    }

    // 当播放状态变为暂停或播放时，调用playRecord接口
    LaunchedEffect(playbackState) {
        if (playbackState == PlaybackState.PAUSED && lastPlayState == PlaybackState.PLAYING) {
            // 调用playRecord接口
            callPlayRecord(
                ts = (mediaPlayer.currentPositionMillis.value / 1000).toInt(),
                playingInfoCache = playingInfoCache,
                playRecordViewModel = playRecordViewModel,
                onSuccess = {
                    logger.i("PIP暂停时调用playRecord成功")
                },
                onError = {
                    logger.i("PIP暂停时调用playRecord失败：缓存为空")
                },
            )
        } else if (playbackState == PlaybackState.PLAYING && lastPlayState == PlaybackState.PAUSED) {
            // 从暂停切换到播放时也调用playRecord接口
            callPlayRecord(
                ts = (mediaPlayer.currentPositionMillis.value / 1000).toInt(),
                playingInfoCache = playingInfoCache,
                playRecordViewModel = playRecordViewModel,
                onSuccess = {
                    logger.i("PIP恢复播放时调用playRecord成功")
                },
                onError = {
                    logger.i("PIP恢复播放时调用playRecord失败：缓存为空")
                },
            )
        }
        lastPlayState = playbackState
    }

    // 每隔15秒调用一次playRecord接口
    LaunchedEffect(Unit) {
        while (isActive) {
            delay(15000) // 每15秒

            // 调用playRecord接口
            callPlayRecord(
                ts = (mediaPlayer.currentPositionMillis.value / 1000).toInt(),
                playingInfoCache = playingInfoCache,
                playRecordViewModel = playRecordViewModel,
                onSuccess = {
                    logger.i("PIP每隔15s调用playRecord成功")
                },
                onError = {
                    logger.i("PIP每隔15s调用playRecord失败：缓存为空")
                }
            )
        }
    }

    val audioLevelController = remember(mediaPlayer) { mediaPlayer.features[AudioLevelController] }
    val volume by audioLevelController?.volume?.collectAsState() ?: remember {
        mutableFloatStateOf(
            1f
        )
    }
    var isVolumeControlHovered by remember { mutableStateOf(false) }

    val hlsSubtitleUtil = remember(playingInfoCache) {
        val playLink = playingInfoCache?.playLink
        val subtitle = playingInfoCache?.currentSubtitleStream
        if (!playLink.isNullOrBlank() && playLink.contains(".m3u8") && subtitle != null && subtitle.isExternal == 0) {
            HlsSubtitleUtil(fnOfficialClient, playLink, subtitle)
        } else {
            null
        }
    }

    val externalSubtitleUtil = remember(playingInfoCache) {
        val subtitle = playingInfoCache?.currentSubtitleStream
        if (subtitle != null && subtitle.isExternal == 1 && subtitle.format in listOf(
                "srt",
                "ass",
                "vtt"
            )
        ) {
            ExternalSubtitleUtil(fnOfficialClient, subtitle)
        } else {
            null
        }
    }

    LaunchedEffect(hlsSubtitleUtil, externalSubtitleUtil) {
        hlsSubtitleUtil?.initialize(mediaPlayer.getCurrentPositionMillis())
        externalSubtitleUtil?.initialize()
    }

    var subtitleCues by remember { mutableStateOf<List<SubtitleCue>>(emptyList()) }
    val currentRenderTime by rememberSmoothVideoTime(mediaPlayer)

    LaunchedEffect(hlsSubtitleUtil, externalSubtitleUtil, mediaPlayer, subtitleSettings) {
        if (hlsSubtitleUtil != null) {
            // Loop 1: Fetch loop
            launch(kotlinx.coroutines.Dispatchers.IO) {
                while (isActive) {
                    val currentPos = mediaPlayer.getCurrentPositionMillis()
                    hlsSubtitleUtil.update(currentPos)
                    delay(2000)
                }
            }
            // Loop 2: List update loop
            launch {
                while (isActive) {
                    val currentPos = mediaPlayer.getCurrentPositionMillis()
                    val adjustedPos = currentPos - (subtitleSettings.offsetSeconds * 1000).toLong()
                    val newCues = hlsSubtitleUtil.getCurrentSubtitle(adjustedPos)
                    if (subtitleCues != newCues) {
                        subtitleCues = newCues
                    }
                    delay(16)
                }
            }
        } else if (externalSubtitleUtil != null) {
            launch {
                while (isActive) {
                    val currentPos = mediaPlayer.getCurrentPositionMillis()
                    val adjustedPos = currentPos - (subtitleSettings.offsetSeconds * 1000).toLong()
                    val newCues = externalSubtitleUtil.getCurrentSubtitle(adjustedPos)
                    if (subtitleCues != newCues) {
                        subtitleCues = newCues
                    }
                    delay(16)
                }
            }
        } else {
            subtitleCues = emptyList()
        }
    }

    val windowState = rememberWindowState(
        position = if (savedData != null) WindowPosition(
            savedData.x.dp,
            savedData.y.dp
        ) else WindowPosition.Aligned(Alignment.BottomEnd),
        width = if (savedData != null) savedData.width.dp else 320.dp,
        height = if (savedData != null) savedData.height.dp else 180.dp
    )

    // Dynamic Resize based on Video
    LaunchedEffect(playingInfoCache?.currentVideoStream) {
        // 延迟一点时间确保窗口状态已稳定
        delay(100)
        val videoStream = playingInfoCache?.currentVideoStream
        if (videoStream != null) {
            val currentWidth = windowState.size.width.value
            val currentHeight = windowState.size.height.value

            // 确保有有效值
            val baseWidth = if (!currentWidth.isNaN() && currentWidth > 0f) currentWidth else 320f
            val baseHeight =
                if (!currentHeight.isNaN() && currentHeight > 0f) currentHeight else 180f

            val optimalSize = calculateOptimalPlayerWindowSize(
                videoStream,
                baseWidth,
                baseHeight,
                "AUTO",
                isPipMode = true
            )

            if (optimalSize != null) {
                windowState.size = optimalSize
            }
        }
    }

    // Auto-save position
    LaunchedEffect(windowState) {
        snapshotFlow { windowState.position to windowState.size }
            .debounce(500)
            .collect { (pos, size) ->
                if (pos is WindowPosition.Absolute) {
                    PlayingSettingsStore.savePipWindowData(
                        pos.x.value.toInt(),
                        pos.y.value.toInt(),
                        size.width.value.toInt(),
                        size.height.value.toInt()
                    )
                }
            }
    }

    Window(
        onCloseRequest = onClose,
        state = windowState,
        undecorated = true,
        alwaysOnTop = true,
        resizable = true,
        transparent = true,
        title = "PiP Player",
        icon = painterResource(Res.drawable.icon)
    ) {
        var isHovered by remember { mutableStateOf(false) }
        val density = LocalDensity.current
        var dragOffset by remember { mutableStateOf<Point?>(null) }

        LaunchedEffect(window) {
            window.findSkiaLayer()?.transparency = true
            window.background = java.awt.Color(0, 0, 0, 0)
            window.contentPane.background = java.awt.Color(0, 0, 0, 0)
        }

        val dragModifier = Modifier.pointerInput(Unit) {
            detectDragGestures(
                onDragStart = {
                    val mouse = MouseInfo.getPointerInfo()?.location
                    if (mouse != null) {
                        val location = window.location
                        dragOffset = Point(mouse.x - location.x, mouse.y - location.y)
                    }
                },
                onDragEnd = {
                    dragOffset = null
                    val location = window.location
                    windowState.position = with(density) {
                        WindowPosition(location.x.toDp(), location.y.toDp())
                    }
                },
                onDragCancel = {
                    dragOffset = null
                },
                onDrag = { change, _ ->
                    change.consume()
                    val offset = dragOffset ?: return@detectDragGestures
                    val mouse = MouseInfo.getPointerInfo()?.location ?: return@detectDragGestures
                    window.setLocation(mouse.x - offset.x, mouse.y - offset.y)
                    val location = window.location
                    windowState.position = with(density) {
                        WindowPosition(location.x.toDp(), location.y.toDp())
                    }
                }
            )
        }

        Box(
            modifier = Modifier
                .fillMaxSize()
                .clip(RoundedCornerShape(12.dp))
                .background(Color.Black)
                .onPointerEvent(PointerEventType.Enter) { isHovered = true }
                .onPointerEvent(PointerEventType.Exit) { isHovered = false }
        ) {
            // Video Surface
            MediampPlayerSurface(
                mediampPlayer = mediaPlayer,
                modifier = Modifier
                    .fillMaxSize()
                    .pointerHoverIcon(PointerIcon.Hand)
                    .pointerInput(Unit) {
                        detectTapGestures(
                            onTap = {
                                if (mediaPlayer.getCurrentPlaybackState() == PlaybackState.PLAYING) {
                                    mediaPlayer.pause()
                                } else {
                                    mediaPlayer.resume()
                                }
                            }
                        )
                    }
                    .then(dragModifier)
            )

            // Subtitles
            if (subtitleCues.isNotEmpty()) {
                BoxWithConstraints(
                    modifier = Modifier.fillMaxSize()
                ) {
                    val playerScreenSize =
                        remember { PlayingSettingsStore.getLastPlayerScreenSize() }
                    val fontScaleRatio =
                        if (playerScreenSize != null && playerScreenSize.width > 0) {
                            maxWidth.value / playerScreenSize.width
                        } else {
                            maxWidth.value / 1280f
                        }

                    SubtitleOverlay(
                        subtitleCues = subtitleCues,
                        currentRenderTime = currentRenderTime - (subtitleSettings.offsetSeconds * 1000).toLong(),
                        maxWidth = maxWidth,
                        maxHeight = maxHeight,
                        currentPosition = mediaPlayer.getCurrentPositionMillis() - (subtitleSettings.offsetSeconds * 1000).toLong(),
                        settings = subtitleSettings,
                        fontScaleRatio = fontScaleRatio
                    )
                }
            }

            if (playbackState == PlaybackState.READY || playbackState == PlaybackState.PAUSED_BUFFERING || isLoading) {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    ImgLoadingProgressRing(modifier = Modifier.size(32.dp))
                }
            }

            // Play Button when paused
            if (playbackState == PlaybackState.PAUSED) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .pointerHoverIcon(PointerIcon.Hand)
                        .background(Color.Black.copy(alpha = 0.3f))
                        .then(dragModifier)
                        .clickable { mediaPlayer.resume() },
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = PlayCircle,
                        contentDescription = "Play",
                        tint = Color.White.copy(alpha = 0.8f),
                        modifier = Modifier.size(48.dp)
                    )
                }
            }

            // Progress Bar
            if (isHovered) {
                // Skip Backward Button
                val isRewindHovered by rewindInteractionSource.collectIsHoveredAsState()
                val isRewindPressed by rewindInteractionSource.collectIsPressedAsState()
                Box(
                    modifier = Modifier
                        .align(BiasAlignment(horizontalBias = -0.5f, verticalBias = 0f))
                        .size(40.dp)
                        .background(
                            color = Color.Black.copy(
                                alpha = when {
                                    isRewindPressed -> 0.8f
                                    isRewindHovered -> 0.6f
                                    else -> 0.4f
                                }
                            ),
                            shape = CircleShape
                        )
                        .pointerHoverIcon(PointerIcon.Hand)
                        .clickable(
                            interactionSource = rewindInteractionSource,
                            indication = null,
                            onClick = {
                                mediaPlayer.skip(-10_000)
                                callPlayRecord(
                                    ts = (mediaPlayer.getCurrentPositionMillis() / 1000).toInt(),
                                    playingInfoCache = playingInfoCache,
                                    playRecordViewModel = playRecordViewModel,
                                    onSuccess = {
                                        logger.i("PIP快退时调用playRecord成功")
                                    },
                                    onError = {
                                        logger.i("PIP快退时调用playRecord失败：缓存为空")
                                    },
                                )
                            }
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Back10S,
                        contentDescription = "Rewind 10s",
                        tint = Color.White,
                        modifier = Modifier.size(24.dp)
                    )
                }

                // Skip Forward Button
                val isForwardHovered by forwardInteractionSource.collectIsHoveredAsState()
                val isForwardPressed by forwardInteractionSource.collectIsPressedAsState()
                Box(
                    modifier = Modifier
                        .align(BiasAlignment(horizontalBias = 0.5f, verticalBias = 0f))
                        .size(40.dp)
                        .background(
                            color = Color.Black.copy(
                                alpha = when {
                                    isForwardPressed -> 0.8f
                                    isForwardHovered -> 0.6f
                                    else -> 0.4f
                                }
                            ),
                            shape = CircleShape
                        )
                        .pointerHoverIcon(PointerIcon.Hand)
                        .clickable(
                            interactionSource = forwardInteractionSource,
                            indication = null,
                            onClick = {
                                mediaPlayer.skip(10_000)
                                callPlayRecord(
                                    ts = (mediaPlayer.getCurrentPositionMillis() / 1000).toInt(),
                                    playingInfoCache = playingInfoCache,
                                    playRecordViewModel = playRecordViewModel,
                                    onSuccess = {
                                        logger.i("PIP快进时调用playRecord成功")
                                    },
                                    onError = {
                                        logger.i("PIP快进时调用playRecord失败：缓存为空")
                                    },
                                )
                            }
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        imageVector = Forward10S,
                        contentDescription = "Forward 10s",
                        tint = Color.White,
                        modifier = Modifier.size(24.dp)
                    )
                }

                val totalDuration = LocalPlayerManager.current.playerState.duration
                VideoPlayerProgressBar(
                    player = mediaPlayer,
                    totalDuration = totalDuration,
                    onSeek = { ratio ->
                        isLoading = true
                        val seekPosition = (ratio * totalDuration).toLong()
                        mediaPlayer.seekTo(seekPosition)
                        callPlayRecord(
                            ts = (seekPosition / 1000).toInt(),
                            playingInfoCache = playingInfoCache,
                            playRecordViewModel = playRecordViewModel,
                            onSuccess = {
                                logger.i("PIP Seek时调用playRecord成功")
                            },
                            onError = {
                                logger.i("PIP Seek时调用playRecord失败：缓存为空")
                            },
                        )
                    },
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .offset(y = (-40).dp)
                        .padding(horizontal = 12.dp)
                        .pointerHoverIcon(PointerIcon.Hand)
                        .fillMaxWidth()
                )
            }

            // Top Right: Close Button
            if (isHovered) {
                IconButton(
                    onClick = onClose,
                    modifier = Modifier
                        .pointerHoverIcon(PointerIcon.Hand)
                        .align(Alignment.TopEnd)
                        .offset(x = 7.dp, y = (-7).dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Close",
                        tint = Color.White
                    )
                }
            }

            // Bottom Left: Volume Control
            if (isHovered || isVolumeControlHovered) {
                Box(
                    modifier = Modifier
                        .align(Alignment.BottomStart)
                        .offset(y = 5.dp, x = (-5).dp)
//                        .padding(8.dp)
                ) {
                    VolumeControl(
                        volume = volume,
                        onVolumeChange = {
                            audioLevelController?.setVolume(it)
                            PlayingSettingsStore.saveVolume(it)
                        },
                        onHoverStateChanged = { isVolumeControlHovered = it },
                        modifier = Modifier.size(50.dp)
                    )
                }
            }

            // Bottom Right: Exit PiP Button
            val pipSpec = PlayerResourceManager.quitPipSpec
            if (pipSpec != null) {
                val composition by rememberLottieComposition { pipSpec }
                var isPlaying by remember { mutableStateOf(false) }
                val progress by animateLottieCompositionAsState(
                    composition = composition,
                    iterations = 1,
                    isPlaying = isPlaying
                )
                var isExitBtnHovered by remember { mutableStateOf(false) }

                LaunchedEffect(isExitBtnHovered) {
                    if (isExitBtnHovered) {
                        isPlaying = true
                    }
                }

                LaunchedEffect(progress) {
                    if (progress == 1f) {
                        isPlaying = false
                    }
                }

                if (isHovered || (progress > 0f && progress < 1f)) {
                    Box(
                        modifier = Modifier
                            .align(Alignment.BottomEnd)
                            .padding(8.dp)
                            .size(26.dp)
                            .pointerHoverIcon(PointerIcon.Hand)
                            .onPointerEvent(PointerEventType.Enter) { isExitBtnHovered = true }
                            .onPointerEvent(PointerEventType.Exit) { isExitBtnHovered = false }
                            .clickable(
                                interactionSource = remember { MutableInteractionSource() },
                                indication = null,
                            ) { onExitPip() }
                    ) {
                        Image(
                            painter = rememberLottiePainter(composition, progress = { progress }),
                            contentDescription = "Exit PiP",
                            modifier = Modifier.fillMaxSize(),
                            colorFilter = ColorFilter.tint(Color.White)
                        )
                    }
                }
            }
        }
    }
}
