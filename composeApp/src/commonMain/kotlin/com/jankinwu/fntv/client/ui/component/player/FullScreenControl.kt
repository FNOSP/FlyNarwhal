package com.jankinwu.fntv.client.ui.component.player

import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.PointerEventType
import androidx.compose.ui.input.pointer.onPointerEvent
import androidx.compose.ui.unit.dp
import com.jankinwu.fntv.client.icons.ExitFullScreen
import com.jankinwu.fntv.client.icons.FullScreen
import com.jankinwu.fntv.client.manager.PlayerResourceManager
import io.github.alexzhirkevich.compottie.animateLottieCompositionAsState
import io.github.alexzhirkevich.compottie.rememberLottieComposition
import io.github.alexzhirkevich.compottie.rememberLottiePainter
import org.jetbrains.compose.resources.ExperimentalResourceApi

@OptIn(ExperimentalResourceApi::class, ExperimentalComposeUiApi::class)
@Composable
fun FullScreenControl(
    isFullScreen: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val fullScreenSpec = PlayerResourceManager.fullScreenSpec
    val quitFullScreenSpec = PlayerResourceManager.quitFullScreenSpec

    val currentSpec = if (isFullScreen) quitFullScreenSpec else fullScreenSpec
    val composition = if (currentSpec != null) {
        val c by rememberLottieComposition { currentSpec }
        c
    } else {
        null
    }

    var isPlaying by remember { mutableStateOf(false) }

    // 重置播放状态，当切换全屏状态时
    LaunchedEffect(isFullScreen) {
        isPlaying = false
    }

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
            painter = rememberLottiePainter(
                composition = composition,
                progress = { progress }
            ),
            contentDescription = if (isFullScreen) "退出全屏" else "全屏",
            modifier = modifier
                .size(26.dp)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = onClick
                )
                .onPointerEvent(PointerEventType.Enter) {
                    isPlaying = true
                }
                .onPointerEvent(PointerEventType.Exit) {
                    // isPlaying = false
                }
        )
    } else {
        Icon(
            imageVector = if (isFullScreen) ExitFullScreen else FullScreen,
            contentDescription = if (isFullScreen) "退出全屏" else "全屏",
            tint = Color.White,
            modifier = modifier
                .size(26.dp)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = onClick
                )
        )
    }
}
