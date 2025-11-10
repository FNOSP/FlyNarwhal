package com.jankinwu.fntv.client

import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.painter.BrushPainter
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.platform.Font
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.FrameWindowScope
import androidx.compose.ui.window.WindowState
import com.jankinwu.fntv.client.data.store.Store
import com.jankinwu.fntv.client.utils.isSystemInDarkMode
import io.github.composefluent.ExperimentalFluentApi
import io.github.composefluent.FluentTheme
import io.github.composefluent.LocalContentColor
import io.github.composefluent.Typography
import io.github.composefluent.background.Mica
import io.github.composefluent.darkColors
import io.github.composefluent.lightColors
import org.jetbrains.skiko.hostOs

val LocalStore = compositionLocalOf<Store> { error("Not provided") }

val defaultVariableFamily = FontFamily(
    if (hostOs.isWindows) {
        Font("Microsoft YaHei")
    } else if (hostOs.isMacOS) {
        Font("PingFang SC")
    } else {
        Font("font/SourceHanSansSC-VF.otf")
    }
)

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

    LaunchedEffect(systemDarkMode) {
        store.darkMode = systemDarkMode
    }
    LaunchedEffect(state.size.width, state.size.height) {
        store.updateWindowWidth(state.size.width)
        store.updateWindowHeight(state.size.height)
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

internal val LocalTypography = staticCompositionLocalOf {
    Typography(
        caption = TextStyle(
            fontWeight = FontWeight.Normal,
            fontSize = 12.sp, lineHeight = 16.sp,
            fontFamily = defaultVariableFamily
        ),
        body = TextStyle(
            fontWeight = FontWeight.Normal,
            fontSize = 14.sp, lineHeight = 20.sp,
            fontFamily = defaultVariableFamily
        ),
        bodyStrong = TextStyle(
            fontWeight = FontWeight.SemiBold,
            fontSize = 14.sp, lineHeight = 20.sp,
            fontFamily = defaultVariableFamily
        ),
        bodyLarge = TextStyle(
            fontWeight = FontWeight.Normal,
            fontSize = 18.sp, lineHeight = 24.sp,
            fontFamily = defaultVariableFamily
        ),
        subtitle = TextStyle(
            fontWeight = FontWeight.SemiBold,
            fontSize = 20.sp, lineHeight = 28.sp,
            fontFamily = defaultVariableFamily
        ),
        title = TextStyle(
            fontWeight = FontWeight.SemiBold,
            fontSize = 28.sp, lineHeight = 36.sp,
            fontFamily = defaultVariableFamily
        ),
        titleLarge = TextStyle(
            fontWeight = FontWeight.SemiBold,
            fontSize = 40.sp, lineHeight = 52.sp,
            fontFamily = defaultVariableFamily
        ),
        display = TextStyle(
            fontWeight = FontWeight.SemiBold,
            fontSize = 68.sp, lineHeight = 92.sp,
            fontFamily = defaultVariableFamily
        )
    )
}


val LocalFrameWindowScope = staticCompositionLocalOf<FrameWindowScope> {
    error("FrameWindowScope not provided")
}