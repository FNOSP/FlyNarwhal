package com.jankinwu.fntv.client

import androidx.compose.foundation.window.WindowDraggableArea
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Window
import androidx.compose.ui.window.WindowPlacement
import androidx.compose.ui.window.WindowPosition
import androidx.compose.ui.window.WindowState
import androidx.compose.ui.window.application
import androidx.compose.ui.window.rememberWindowState
import co.touchlab.kermit.Logger
import com.jankinwu.fntv.client.data.network.apiModule
import com.jankinwu.fntv.client.manager.LoginStateManager
import com.jankinwu.fntv.client.manager.PreferencesManager
import com.jankinwu.fntv.client.manager.ProxyManager
import com.jankinwu.fntv.client.ui.component.common.rememberComponentNavigator
import com.jankinwu.fntv.client.ui.providable.LocalFrameWindowScope
import com.jankinwu.fntv.client.ui.providable.LocalMediaPlayer
import com.jankinwu.fntv.client.ui.providable.LocalPlayerManager
import com.jankinwu.fntv.client.ui.providable.LocalWindowState
import com.jankinwu.fntv.client.ui.screen.LoginScreen
import com.jankinwu.fntv.client.ui.screen.PlayerManager
import com.jankinwu.fntv.client.ui.screen.PlayerOverlay
import com.jankinwu.fntv.client.utils.ConsoleLogWriter
import com.jankinwu.fntv.client.utils.ExecutableDirectoryDetector
import com.jankinwu.fntv.client.utils.FileLogWriter
import com.jankinwu.fntv.client.viewmodel.UiState
import com.jankinwu.fntv.client.viewmodel.UserInfoViewModel
import com.jankinwu.fntv.client.viewmodel.viewModelModule
import com.jankinwu.fntv.client.window.WindowFrame
import fntv_client_multiplatform.composeapp.generated.resources.Res
import fntv_client_multiplatform.composeapp.generated.resources.icon
import org.jetbrains.compose.resources.painterResource
import org.koin.compose.KoinApplication
import org.koin.compose.koinInject
import org.openani.mediamp.compose.rememberMediampPlayer
import java.awt.Dimension
import java.io.File

fun main() = application {
    val logDir = initializeLoggingDirectory()
    Logger.setLogWriters(ConsoleLogWriter(), FileLogWriter(logDir))
    Logger.withTag("main").i { "Application started. Logs directory: ${logDir.absolutePath}" }

    DisposableEffect(Unit) {
        ProxyManager.start()
        onDispose {
            ProxyManager.stop()
        }
    }

    val (state, title, icon) = createWindowConfiguration()

    // 加载登录信息到缓存
    PreferencesManager.getInstance().loadAllLoginInfo()

    KoinApplication(application = {
        modules(viewModelModule, apiModule)
    }) {
        Window(
            onCloseRequest = ::exitApplication,
            state = state,
            title = title,
            icon = icon
        ) {
            val navigator = rememberComponentNavigator()
            val playerManager = remember { PlayerManager() }
            val player = rememberMediampPlayer()
            val userInfoViewModel: UserInfoViewModel = koinInject()
            val userInfoState by userInfoViewModel.uiState.collectAsState()
            LaunchedEffect(Unit) {
                val baseWidth = 1280
                val baseHeight = 720
                window.minimumSize = Dimension(baseWidth, baseHeight)
//                window.size = Dimension(baseWidth, baseHeight)
            }

            CompositionLocalProvider(
                LocalPlayerManager provides playerManager,
                LocalMediaPlayer provides player,
                LocalFrameWindowScope provides this@Window,
                LocalWindowState provides state
            ) {
                WindowFrame(
                    onCloseRequest = {
                        player.close() // 关闭播放器
                        exitApplication() // 退出应用
                    },
                    icon = icon,
                    title = title,
                    state = state,
                    backButtonEnabled = navigator.canNavigateUp,
                    backButtonClick = { navigator.navigateUp() },
                    backButtonVisible = false
                ) { windowInset, contentInset ->
                    // 使用LoginStateManagement来管理登录状态
                    val isLoggedIn by LoginStateManager.isLoggedIn.collectAsState()

                    // 校验cookie是否有效
                    LaunchedEffect(Unit) {
                        if (isLoggedIn) {
                            userInfoViewModel.loadUserInfo()
                        }
                        if (userInfoState is UiState.Error) {
                            LoginStateManager.updateLoginStatus(false)
                        }
                    }

                    // 只有在未登录状态下才显示登录界面
                    if (!isLoggedIn) {
                        LoginScreen(navigator)
                    } else {
                        App(
                            windowInset = windowInset,
                            contentInset = contentInset,
                            navigator = navigator,
                            title = title,
                            icon = icon
                        )
                    }
                    // 显示播放器覆盖层
                    if (playerManager.playerState.isVisible && state.placement != WindowPlacement.Fullscreen) {
                        WindowDraggableArea {
                            PlayerOverlay(
                                mediaTitle = playerManager.playerState.mediaTitle,
                                subhead = playerManager.playerState.subhead,
                                isEpisode = playerManager.playerState.isEpisode,
                                onBack = { playerManager.hidePlayer() },
                                mediaPlayer = player
                            )
                        }
                    } else if (playerManager.playerState.isVisible && state.placement == WindowPlacement.Fullscreen) {
                        PlayerOverlay(
                            mediaTitle = playerManager.playerState.mediaTitle,
                            subhead = playerManager.playerState.subhead,
                            isEpisode = playerManager.playerState.isEpisode,
                            onBack = { playerManager.hidePlayer() },
                            mediaPlayer = player
                        )
                    }
                }
            }
        }
    }
}

/**
 * 初始化日志目录
 * 根据应用程序运行模式（开发模式或打包模式）确定日志目录位置
 */
private fun initializeLoggingDirectory(): File {
    val userDirStr = System.getProperty("user.dir")
    val userDirFile = File(userDirStr)
    
    // Check if we are running in development mode (via Gradle/IDE)
    // We assume dev mode if build.gradle.kts exists in user.dir or user.dir/composeApp
    val isDev = System.getProperty("compose.application.resources.dir") == null ||
            File(userDirFile, "build.gradle.kts").exists()

    val logDir = if (isDev) {
        // Dev mode: try to find project root to place logs there
        if (File(userDirFile.parentFile, "settings.gradle.kts").exists()) {
            File(userDirFile.parentFile, "logs")
        } else {
            File(userDirFile, "logs")
        }
    } else {
        // Packaged mode: use app dir / logs
        val platform = currentPlatformDesktop()
        when (platform) {
            is Platform.Linux -> {
                val userHome = System.getProperty("user.home")
                File(userHome, ".local/share/fn-media/logs")
            }
            is Platform.MacOS -> {
                val userHome = System.getProperty("user.home")
                File(userHome, "Library/Logs/fn-media")
            }
            is Platform.Windows -> {
                val appDir = ExecutableDirectoryDetector.INSTANCE.getExecutableDirectory()
                File(appDir, "logs")
            }
        }
    }

    if (!logDir.exists()) {
        logDir.mkdirs()
    }
    
    return logDir
}

/**
 * 创建窗口配置
 */
@Composable
private fun createWindowConfiguration(): Triple<WindowState, String, Painter> {
    val state = rememberWindowState(
        position = WindowPosition(Alignment.Center),
//        size = DpSize.Unspecified
        size = DpSize(1280.dp, 720.dp)
    )
    val title = "飞牛影视"
    val icon = painterResource(Res.drawable.icon)
    return Triple(state, title, icon)
}