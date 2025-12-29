package com.jankinwu.fntv.client.utils

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import co.touchlab.kermit.Logger
import com.jthemedetecor.OsThemeDetector
import org.jetbrains.skiko.hostOs
import java.util.function.Consumer

@Composable
actual fun isSystemInDarkMode(): Boolean {
    val composeDarkMode = isSystemInDarkTheme()
    val isSystemInDarkTheme = remember { mutableStateOf(composeDarkMode) }

    // Sync with Compose's native dark theme state
    LaunchedEffect(composeDarkMode) {
        isSystemInDarkTheme.value = composeDarkMode
    }

    // Use OsThemeDetector only on non-macOS platforms.
    // MacOS has JNA callback issues with jthemedetector, and Compose's native detection is reliable enough.
    if (!hostOs.isMacOS) {
        DisposableEffect(Unit) {
            val listener = Consumer<Boolean> {
                isSystemInDarkTheme.value = it
            }
            var detector: OsThemeDetector? = null
            try {
                detector = OsThemeDetector.getDetector()
                detector.registerListener(listener)
            } catch (e: Throwable) {
                Logger.withTag("DarkThemeMode").e("Failed to register dark theme listener", e)
            }
            onDispose {
                try {
                    detector?.removeListener(listener)
                } catch (e: Throwable) {
                    // Ignore errors during disposal
                }
            }
        }
    }

    return isSystemInDarkTheme.value
}