package com.jankinwu.fntv.client.data.store

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import coil3.network.NetworkHeaders
import io.github.composefluent.component.NavigationDisplayMode

class Store(
    systemDarkMode: Boolean,
    enabledAcrylicPopup: Boolean,
    compactMode: Boolean,
    windowWidth: Dp,
    windowHeight: Dp,
) {
    var darkMode by mutableStateOf(systemDarkMode)

    var isFollowingSystemTheme by mutableStateOf(AppSettingsStore.isFollowingSystemTheme)

    var enabledAcrylicPopup by mutableStateOf(enabledAcrylicPopup)

    var compactMode by mutableStateOf(compactMode)

    private var navigationDisplayModeState by mutableStateOf(
        resolveNavigationDisplayMode(AppSettingsStore.navigationDisplayMode)
    )

    var navigationDisplayMode: NavigationDisplayMode
        get() = navigationDisplayModeState
        set(value) {
            navigationDisplayModeState = value
            AppSettingsStore.navigationDisplayMode = value.name
        }

    fun reloadUserScopedSettings() {
        isFollowingSystemTheme = AppSettingsStore.isFollowingSystemTheme
        navigationDisplayModeState = resolveNavigationDisplayMode(AppSettingsStore.navigationDisplayMode)
    }

    // 缩放因子，用于调整组件大小
    var scaleFactor by mutableFloatStateOf((windowWidth / 1280.dp))

    var proxyInitialized by mutableStateOf(false)

    val fnImgHeaders: NetworkHeaders
        get() = NetworkHeaders.Builder()
            .set("cookie", AccountDataCache.cookieState)
            .build()

    var windowWidthState by mutableStateOf(windowWidth)

    var windowHeightState by mutableStateOf(windowHeight)
    
    fun updateWindowWidth(newWidth: Dp) {
        val windowScaleFactor = (newWidth / 1280.dp)
        scaleFactor =
            if (windowScaleFactor == 1f) 1f else (1f + (windowScaleFactor - 1f) * 0.3f).coerceIn(
                1f,
                1.5f
            )
        windowWidthState = newWidth
    }

    fun updateWindowHeight(newHeight: Dp) {
        windowHeightState = newHeight
    }

    fun updateProxyInitialized(state: Boolean) {
        proxyInitialized = state
    }

    private fun resolveNavigationDisplayMode(rawValue: String): NavigationDisplayMode {
        return NavigationDisplayMode.entries.firstOrNull { it.name == rawValue } ?: NavigationDisplayMode.Left
    }
}
