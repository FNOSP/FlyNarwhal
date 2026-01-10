package com.jankinwu.fntv.client.window

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.FrameWindowScope
import androidx.compose.ui.window.WindowPlacement
import androidx.compose.ui.window.WindowState
import com.jankinwu.fntv.client.icons.Pin
import com.jankinwu.fntv.client.icons.PinFill
import com.jankinwu.fntv.client.icons.RefreshCircle
import com.jankinwu.fntv.client.ui.component.common.HasNewVersionTag
import com.jankinwu.fntv.client.ui.providable.LocalPlayerManager
import io.github.composefluent.FluentTheme
import io.github.composefluent.component.Icon
import io.github.composefluent.component.Text
import kotlinx.coroutines.launch
import org.jetbrains.skiko.disableTitleBar

@Composable
fun FrameWindowScope.MacOSWindowFrame(
    state: WindowState,
    backButtonVisible: Boolean,
    backButtonEnabled: Boolean,
    title: String,
    icon: Painter?,
    captionBarHeight: Dp,
    onBackButtonClick: () -> Unit,
    isAlwaysOnTop: Boolean = false,
    onToggleAlwaysOnTop: () -> Unit = {},
    onRefreshClick: (() -> Unit)? = null,
    content: @Composable (windowInset: WindowInsets, captionBarInset: WindowInsets) -> Unit
) {
    val windowInset by remember(state) {
        derivedStateOf {
            if (state.placement != WindowPlacement.Fullscreen) {
                WindowInsets(top = captionBarHeight)
            } else {
                WindowInsets(0)
            }
        }
    }
    LaunchedEffect(window, captionBarHeight) {
        window.findSkiaLayer()?.disableTitleBar(captionBarHeight.value)
    }
    val playerManager = LocalPlayerManager.current
    val playerVisible = playerManager.playerState.isVisible
    val uiVisible = playerManager.playerState.isUiVisible
    val showTrafficLights = !playerVisible || uiVisible

    LaunchedEffect(showTrafficLights) {
        com.jankinwu.fntv.client.utils.MacOSTrafficLightUtils.setTrafficLightButtonsVisible(window, showTrafficLights)
    }

    //TODO Get real macOS caption bar width.
    Box {
        val contentInset = WindowInsets(left = 80.dp)
        content(windowInset, contentInset)
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .windowInsetsPadding(contentInset)
                .fillMaxWidth()
                .height(captionBarHeight)
                .clickable(
                    interactionSource = remember { MutableInteractionSource() },
                    indication = null,
                    onClick = {}
                )
        ) {
//                AnimatedContent(
//                    targetState = backButtonVisible,
//                    transitionSpec = {
//                        ContentTransform(
//                            targetContentEnter = expandHorizontally(),
//                            initialContentExit = shrinkHorizontally(),
//                            sizeTransform = SizeTransform { _, _ ->
//                                tween(
//                                    FluentDuration.ShortDuration,
//                                    easing = FluentEasing.FastInvokeEasing
//                                )
//                            }
//                        )
//                    }
//                ) {
//                    if (it) {
//                        NavigationDefaults.BackButton(
//                            onClick = onBackButtonClick,
//                            disabled = !backButtonEnabled,
//                        )
//                    } else {
//                        Spacer(modifier = Modifier.width(2.dp).height(36.dp))
//                    }
//                }
                if (!playerVisible) {
                    if (icon != null) {
                        Image(
                            painter = icon,
                            contentDescription = null,
                            modifier = Modifier.padding(start = 6.dp).size(16.dp)
                        )
                    }
                    if (title.isNotEmpty()) {
                        Text(
                            text = title,
                            style = FluentTheme.typography.caption,
                            modifier = Modifier.padding(start = 16.dp)
                        )
                    }

                    Icon(
                        imageVector = if (isAlwaysOnTop) PinFill else Pin,
                        contentDescription = "Always On Top",
                        modifier = Modifier
                            .padding(start = 6.dp)
                            .size(16.dp)
                            .clickable { onToggleAlwaysOnTop() }
                    )

                    // 添加刷新按钮
                    if (onRefreshClick != null) {
                        val rotation = remember { Animatable(0f) }
                        val coroutineScope = rememberCoroutineScope()
                        Icon(
                            imageVector = RefreshCircle,
                            contentDescription = "Refresh",
                            modifier = Modifier
                                .padding(start = 6.dp)
                                .size(16.dp)
                                .clickable {
                                    // 启动旋转动画
                                    coroutineScope.launch {
                                        rotation.animateTo(
                                            targetValue = 360f,
                                            animationSpec = tween(durationMillis = 1000)
                                        )
                                        // 重置旋转角度
                                        rotation.snapTo(0f)
                                    }
                                    // 执行刷新逻辑
                                    onRefreshClick()
                                }
                                .graphicsLayer {
                                    rotationZ = rotation.value
                                }
                        )
                    }
                    HasNewVersionTag()
                    Spacer(modifier = Modifier.weight(1f))
                }
        }

        window.rootPane.apply {
            rootPane.putClientProperty("apple.awt.fullWindowContent", true)
            rootPane.putClientProperty("apple.awt.transparentTitleBar", true)
            rootPane.putClientProperty("apple.awt.windowTitleVisible", false)
        }
    }
}
