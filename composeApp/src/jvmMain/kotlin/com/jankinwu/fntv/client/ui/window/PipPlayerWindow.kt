package com.jankinwu.fntv.client.ui.window

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.Icon
import androidx.compose.material.IconButton
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.snapshotFlow
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.WindowPosition
import androidx.compose.ui.window.rememberWindowState
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.input.pointer.PointerIcon
import androidx.compose.ui.input.pointer.pointerHoverIcon
import com.jankinwu.fntv.client.data.store.PlayingSettingsStore
import com.jankinwu.fntv.client.icons.PlayCircle
import com.jankinwu.fntv.client.manager.PlayerResourceManager
import com.jankinwu.fntv.client.ui.providable.LocalMediaPlayer
import io.github.alexzhirkevich.compottie.animateLottieCompositionAsState
import io.github.alexzhirkevich.compottie.rememberLottieComposition
import io.github.alexzhirkevich.compottie.rememberLottiePainter
import kotlinx.coroutines.flow.debounce
import org.openani.mediamp.PlaybackState
import org.openani.mediamp.compose.MediampPlayerSurface
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
    val savedData = remember { PlayingSettingsStore.getPipWindowData() }

    val windowState = rememberWindowState(
        position = if (savedData != null) WindowPosition(savedData.x.dp, savedData.y.dp) else WindowPosition.Aligned(Alignment.BottomEnd),
        width = if (savedData != null) savedData.width.dp else 320.dp,
        height = if (savedData != null) savedData.height.dp else 180.dp
    )

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
        transparent = false,
        title = "PiP Player"
    ) {
        var isHovered by remember { mutableStateOf(false) }
        val density = LocalDensity.current
        var dragOffset by remember { mutableStateOf<Point?>(null) }

        LaunchedEffect(Unit) {
            window.background = java.awt.Color(0, 0, 0)
        }

        Box(
            modifier = Modifier
                .fillMaxSize()
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
                    .pointerInput(Unit) {
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
                                if (windowState.position !is WindowPosition.Absolute) {
                                    val location = window.location
                                    windowState.position = with(density) {
                                        WindowPosition(location.x.toDp(), location.y.toDp())
                                    }
                                }
                            }
                        )
                    }
            )

            // Play Button when paused
            if (playbackState == PlaybackState.PAUSED) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(Color.Black.copy(alpha = 0.3f))
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

            // Top Right: Close Button
            if (isHovered) {
                IconButton(
                    onClick = onClose,
                    modifier = Modifier
                        .pointerHoverIcon(PointerIcon.Hand)
                        .align(Alignment.TopEnd)
                        .offset(x = 6.dp, y = (-6).dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Close,
                        contentDescription = "Close",
                        tint = Color.White
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

                LaunchedEffect(isHovered) {
                    if (isHovered) {
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
                            .clickable { onExitPip() }
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
