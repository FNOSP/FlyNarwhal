package com.jankinwu.fntv.client

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.painter.BrushPainter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalWindowInfo
import androidx.compose.ui.window.WindowState
import com.jankinwu.fntv.client.data.store.AppSettingsStore
import com.jankinwu.fntv.client.data.store.Store
import com.jankinwu.fntv.client.data.store.UserInfoMemoryCache
import com.jankinwu.fntv.client.manager.LoginStateManager
import com.jankinwu.fntv.client.ui.providable.LocalPlayerManager
import com.jankinwu.fntv.client.ui.providable.LocalRefreshState
import com.jankinwu.fntv.client.ui.providable.LocalStore
import com.jankinwu.fntv.client.ui.providable.LocalTypography
import com.jankinwu.fntv.client.utils.isSystemInDarkMode
import io.github.composefluent.ExperimentalFluentApi
import io.github.composefluent.FluentTheme
import io.github.composefluent.LocalContentColor
import io.github.composefluent.background.Mica
import io.github.composefluent.darkColors
import io.github.composefluent.lightColors

@OptIn(ExperimentalFluentApi::class)
@Composable
fun AppTheme(
    displayMicaLayer: Boolean = true,
    state: WindowState,
    refreshManager: RefreshManager = remember { RefreshManager() },
    content: @Composable () -> Unit
) {
    val systemDarkMode = isSystemInDarkMode()

    val store = remember {
        Store(
            systemDarkMode = systemDarkMode,
            enabledAcrylicPopup = true,
            compactMode = true,
            windowWidth = state.size.width,
            windowHeight = state.size.height,
        )
    }
    val isLoggedIn by LoginStateManager.isLoggedIn.collectAsState()
    val userInfo by UserInfoMemoryCache.userInfo.collectAsState()
    val guid = userInfo?.guid.orEmpty()
    val playerManager = LocalPlayerManager.current
    val playerVisible = playerManager.playerState.isVisible
    LaunchedEffect(isLoggedIn, guid) {
        if (isLoggedIn && guid.isNotBlank()) {
            store.reloadUserScopedSettings()
        }
    }
    LaunchedEffect(systemDarkMode, store.isFollowingSystemTheme, AppSettingsStore.darkMode, isLoggedIn, playerVisible) {
        if (!isLoggedIn) {
            store.darkMode = true
        } else {
            if (playerVisible) {
                store.darkMode = true
            } else {
                if (store.isFollowingSystemTheme) {
                    store.darkMode = systemDarkMode
                } else {
                    store.darkMode = AppSettingsStore.darkMode
                }
            }
        }
    }
    val windowInfo = LocalWindowInfo.current
    val density = LocalDensity.current
    val containerSize = windowInfo.containerSize
    val containerWidth = with(density) { containerSize.width.toDp() }
    val containerHeight = with(density) { containerSize.height.toDp() }
    val effectiveWidth = if (containerSize.width > 0) containerWidth else state.size.width
    val effectiveHeight = if (containerSize.height > 0) containerHeight else state.size.height
    LaunchedEffect(effectiveWidth, effectiveHeight) {
        if (effectiveWidth.value > 0f) {
            store.updateWindowWidth(effectiveWidth)
        }
        if (effectiveHeight.value > 0f) {
            store.updateWindowHeight(effectiveHeight)
        }
    }
    CompositionLocalProvider(
        LocalStore provides store,
        LocalRefreshState provides refreshManager.refreshState // 提供刷新状态
    ) {
        FluentTheme(
            colors = if (store.darkMode) darkColors() else lightColors(),
            useAcrylicPopup = store.enabledAcrylicPopup,
            compactMode = store.compactMode,
            typography = LocalTypography.current
        ) {
            if (displayMicaLayer) {
                val gradient = if (store.darkMode) {
                    listOf(
                        Color(0xff282C51),
                        Color(0xff2A344A),
                    )
                } else {
                    listOf(
                        Color(0xffB1D0ED),
                        Color(0xffDAE3EC),
                    )
                }

                Mica(
                    background = {
                        Image(
                            painter = BrushPainter(Brush.linearGradient(gradient)),
                            contentDescription = null,
                            contentScale = ContentScale.FillBounds
                        )
                    },
                    modifier = Modifier.fillMaxSize()
                ) {
                    content()
                }
            } else {
                CompositionLocalProvider(
                    LocalContentColor provides FluentTheme.colors.text.text.primary,
                    content = content
                )
            }
        }
    }
}
