package com.jankinwu.fntv.client.window

import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.FrameWindowScope
import androidx.compose.ui.window.WindowState
import com.jankinwu.fntv.client.AppTheme
import com.jankinwu.fntv.client.RefreshManager
import com.jankinwu.fntv.client.ui.component.common.ComponentNavigator
import com.jankinwu.fntv.client.ui.providable.LocalPlayerManager
import com.jankinwu.fntv.client.ui.providable.LocalStore
import com.jankinwu.fntv.client.viewmodel.MediaDbListViewModel
import io.github.composefluent.component.NavigationDisplayMode
import io.github.composefluent.gallery.jna.windows.structure.isWindows10OrLater
import io.github.composefluent.gallery.jna.windows.structure.isWindows11OrLater
import org.koin.compose.viewmodel.koinViewModel
import org.jetbrains.skiko.hostOs

@Composable
fun FrameWindowScope.WindowFrame(
    onCloseRequest: () -> Unit,
    icon: Painter? = null,
    title: String = "",
    state: WindowState,
    navigator: ComponentNavigator,
    backButtonVisible: Boolean = true,
    backButtonEnabled: Boolean = false,
    backButtonClick: () -> Unit = {},
    captionBarHeight: Dp = 48.dp,
    content: @Composable (windowInset: WindowInsets, captionBarInset: WindowInsets) -> Unit
) {
    val supportBackdrop = hostOs.isWindows && isWindows11OrLater()
    val refreshManager = remember { RefreshManager() }
    var isRefreshing by remember { mutableStateOf(false) }
    var isAlwaysOnTop by remember { mutableStateOf(false) }

    LaunchedEffect(isAlwaysOnTop) {
        window.isAlwaysOnTop = isAlwaysOnTop
        window.requestFocus()
        window.rootPane.requestFocusInWindow()
    }

    AppTheme(
        !supportBackdrop,
        state,
        refreshManager
    ) {
        val playerManager = LocalPlayerManager.current
        val mediaDbListViewModel: MediaDbListViewModel = koinViewModel()
        val isCollapsed = LocalStore.current.navigationDisplayMode == NavigationDisplayMode.LeftCollapsed
        when {
            hostOs.isWindows && isWindows10OrLater() -> {

                WindowsWindowFrame(
                    onCloseRequest = onCloseRequest,
                    icon = if (isCollapsed) null else icon,
                    title = if (isCollapsed) "" else title,
                    content = content,
                    state = state,
                    navigator = navigator,
                    backButtonVisible = backButtonVisible && !isCollapsed,
                    backButtonEnabled = backButtonEnabled,
                    backButtonClick = backButtonClick,
                    isAlwaysOnTop = isAlwaysOnTop,
                    onToggleAlwaysOnTop = {
                        isAlwaysOnTop = !isAlwaysOnTop
                        if (playerManager.playerState.isVisible) {
                            playerManager.requestKeyFocus()
                        }
                    },
                    onRefreshClick = {
                        refreshManager.requestRefresh {
                            mediaDbListViewModel.loadData()
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
                    navigator = navigator,
                    content = content,
                    backButtonVisible = backButtonVisible && !isCollapsed,
                    backButtonEnabled = backButtonEnabled,
                    onBackButtonClick = backButtonClick,
                    captionBarHeight = captionBarHeight,
                    icon = if (isCollapsed) null else icon,
                    title = if (isCollapsed) "" else title,
                    state = state,
                    isAlwaysOnTop = isAlwaysOnTop,
                    onToggleAlwaysOnTop = {
                        isAlwaysOnTop = !isAlwaysOnTop
                        if (playerManager.playerState.isVisible) {
                            playerManager.requestKeyFocus()
                        }
                    },
                    onRefreshClick = {
                        refreshManager.requestRefresh {
                            mediaDbListViewModel.loadData()
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
