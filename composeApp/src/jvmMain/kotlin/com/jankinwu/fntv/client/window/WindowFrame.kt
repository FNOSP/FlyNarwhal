package com.jankinwu.fntv.client.window

import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.FrameWindowScope
import androidx.compose.ui.window.WindowState
import com.jankinwu.fntv.client.AppTheme
import com.jankinwu.fntv.client.LocalStore
import com.jankinwu.fntv.client.RefreshManager
import io.github.composefluent.component.NavigationDisplayMode
import io.github.composefluent.gallery.jna.windows.structure.isWindows10OrLater
import io.github.composefluent.gallery.jna.windows.structure.isWindows11OrLater
import org.jetbrains.skiko.hostOs

@Composable
fun FrameWindowScope.WindowFrame(
    onCloseRequest: () -> Unit,
    icon: Painter? = null,
    title: String = "",
    state: WindowState,
    backButtonVisible: Boolean = true,
    backButtonEnabled: Boolean = false,
    backButtonClick: () -> Unit = {},
    captionBarHeight: Dp = 48.dp,
    content: @Composable (windowInset: WindowInsets, captionBarInset: WindowInsets) -> Unit
) {
    val supportBackdrop = hostOs.isWindows && isWindows11OrLater()
    val refreshManager = remember { RefreshManager() }
    var isRefreshing by remember { mutableStateOf(false) }
    AppTheme(
        !supportBackdrop,
        state,
        refreshManager
    ) {
        val isCollapsed = LocalStore.current.navigationDisplayMode == NavigationDisplayMode.LeftCollapsed
        when {
            hostOs.isWindows && isWindows10OrLater() -> {

                WindowsWindowFrame(
                    onCloseRequest = onCloseRequest,
                    icon = if (isCollapsed) null else icon,
                    title = if (isCollapsed) "" else title,
                    content = content,
                    state = state,
                    backButtonVisible = backButtonVisible && !isCollapsed,
                    backButtonEnabled = backButtonEnabled,
                    backButtonClick = backButtonClick,
                    onRefreshClick = {
                        // 执行刷新操作
                        refreshManager.requestRefresh {
                            // 这里可以添加全局刷新逻辑（如果需要）
//                            println("执行全局刷新")
                        }
                    },
                    onRefreshAnimationStart = {
                        isRefreshing = true
                    },
                    onRefreshAnimationEnd = {
                        isRefreshing = false
                    },
                    captionBarHeight = captionBarHeight
                )
            }

            hostOs.isMacOS -> {
                MacOSWindowFrame(
                    content = content,
                    backButtonVisible = backButtonVisible && !isCollapsed,
                    backButtonEnabled = backButtonEnabled,
                    onBackButtonClick = backButtonClick,
                    captionBarHeight = captionBarHeight,
                    icon = if (isCollapsed) null else icon,
                    title = if (isCollapsed) "" else title,
                    state = state,
                    onRefreshClick = {
                        // 执行刷新操作
                        refreshManager.requestRefresh {
                            // 这里可以添加全局刷新逻辑（如果需要）
//                            println("执行全局刷新")
                        }
                    }
                )
            }

            else -> {
                content(WindowInsets(0), WindowInsets(0))
            }
        }
    }
}