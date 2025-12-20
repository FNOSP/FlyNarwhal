package com.jankinwu.fntv.client

import androidx.compose.foundation.window.WindowDraggableArea
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.snapshotFlow
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.platform.LocalDensity
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
import com.jankinwu.fntv.client.data.store.AppSettingsStore
import com.jankinwu.fntv.client.manager.LoginStateManager
import com.jankinwu.fntv.client.manager.PreferencesManager
import com.jankinwu.fntv.client.manager.ProxyManager
import com.jankinwu.fntv.client.player.CustomVlcEmbeddedMediampPlayerSurface
import com.jankinwu.fntv.client.player.CustomVlcMediampPlayer
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
import kotlinx.coroutines.FlowPreview
import kotlinx.coroutines.flow.debounce
import org.jetbrains.compose.resources.painterResource
import org.koin.compose.KoinApplication
import org.koin.compose.viewmodel.koinViewModel
import com.jankinwu.fntv.client.player.rememberCustomMediampPlayer
import java.awt.Dimension
import java.awt.Frame
import java.io.File
import java.awt.event.WindowStateListener
import kotlin.math.roundToInt

@OptIn(FlowPreview::class)
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
            val player = rememberCustomMediampPlayer(
                mode = CustomVlcMediampPlayer.VlcRenderMode.EMBEDDED
            )
            val userInfoViewModel: UserInfoViewModel = koinViewModel()
            val userInfoState by userInfoViewModel.uiState.collectAsState()
            LaunchedEffect(Unit) {
                val baseWidth = 1280
                val baseHeight = 720
                window.minimumSize = Dimension(baseWidth, baseHeight)
//                window.size = Dimension(baseWidth, baseHeight)
            }

            // 监听窗口位置变化并自动保存
            LaunchedEffect(state) {
                snapshotFlow { state.position to state.size }
                    .debounce(500)
                    .collect { (position, size) ->
                        if (state.placement != WindowPlacement.Fullscreen && state.placement != WindowPlacement.Maximized) {
                            AppSettingsStore.windowWidth = size.width.value
                            AppSettingsStore.windowHeight = size.height.value
                            if (position is WindowPosition.Absolute) {
                                AppSettingsStore.windowX = position.x.value
                                AppSettingsStore.windowY = position.y.value
                            }
                        }
                    }
            }

            CompositionLocalProvider(
                LocalPlayerManager provides playerManager,
                LocalMediaPlayer provides player,
                LocalFrameWindowScope provides this@Window,
                LocalWindowState provides state
            ) {
                WindowFrame(
                    onCloseRequest = {
                        if (state.placement != WindowPlacement.Fullscreen && state.placement != WindowPlacement.Maximized) {
                            AppSettingsStore.windowWidth = state.size.width.value
                            AppSettingsStore.windowHeight = state.size.height.value
                            val position = state.position
                            if (position is WindowPosition.Absolute) {
                                AppSettingsStore.windowX = position.x.value
                                AppSettingsStore.windowY = position.y.value
                            }
                        }
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
                    if (playerManager.playerState.isVisible) {
                        DesktopPlayerWindows(
                            mediaTitle = playerManager.playerState.mediaTitle,
                            subhead = playerManager.playerState.subhead,
                            isEpisode = playerManager.playerState.isEpisode,
                            onBack = { playerManager.hidePlayer() },
                            mediaPlayer = player,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun DesktopPlayerWindows(
    mediaTitle: String,
    subhead: String,
    isEpisode: Boolean,
    onBack: () -> Unit,
    mediaPlayer: org.openani.mediamp.MediampPlayer,
) {
    // Two-window player: a video window for VLC (heavyweight) and a transparent UI window on top.
    val savedX = AppSettingsStore.playerWindowX
    val savedY = AppSettingsStore.playerWindowY
    val position = if (!savedX.isNaN() && !savedY.isNaN()) {
        WindowPosition(savedX.dp, savedY.dp)
    } else {
        WindowPosition(Alignment.Center)
    }

    val windowState = rememberWindowState(
        position = position,
        size = DpSize(AppSettingsStore.playerWindowWidth.dp, AppSettingsStore.playerWindowHeight.dp)
    )

    var videoFrame by remember { mutableStateOf<Frame?>(null) }
    var isVideoIconified by remember { mutableStateOf(false) }

    Window(
        onCloseRequest = onBack,
        state = windowState,
        title = mediaTitle,
        undecorated = true,
        resizable = true
    ) {
        val frame = (LocalFrameWindowScope.current.window as? Frame)
        SideEffect {
            if (videoFrame !== frame) {
                videoFrame = frame
            }
        }

        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
        ) {
            val vlcPlayer = mediaPlayer as? CustomVlcMediampPlayer
            if (vlcPlayer != null && vlcPlayer.mode == CustomVlcMediampPlayer.VlcRenderMode.EMBEDDED) {
                // Render VLC directly inside its own window to avoid mixing with Compose layers.
                CustomVlcEmbeddedMediampPlayerSurface(
                    mediampPlayer = vlcPlayer,
                    modifier = Modifier.fillMaxSize()
                )
            }
        }
    }

    DisposableEffect(videoFrame) {
        val frame = videoFrame
        if (frame == null) {
            return@DisposableEffect onDispose { }
        }

        fun updateIconifiedState() {
            isVideoIconified = (frame.extendedState and Frame.ICONIFIED) != 0
        }

        updateIconifiedState()
        val listener = WindowStateListener { updateIconifiedState() }
        frame.addWindowStateListener(listener)
        onDispose {
            frame.removeWindowStateListener(listener)
        }
    }

    Window(
        visible = !isVideoIconified,
        onCloseRequest = onBack,
        state = windowState,
        title = "",
        transparent = true,
        undecorated = true,
        resizable = true,
        alwaysOnTop = true
    ) {
        // UI window renders only Compose overlay (no video) and shares the same WindowState with the video window.
        PlayerOverlay(
            mediaTitle = mediaTitle,
            subhead = subhead,
            isEpisode = isEpisode,
            onBack = onBack,
            mediaPlayer = mediaPlayer,
            manageHostWindow = false,
            showVideoLayer = false,
            backgroundColor = Color.Transparent,
            draggableArea = { content ->
                SharedWindowDraggableArea(windowState = windowState, content = content)
            }
        )
    }
}

@Composable
private fun SharedWindowDraggableArea(
    windowState: WindowState,
    content: @Composable () -> Unit
) {
    // Dragging this area updates the shared WindowState so both windows move together.
    val awtWindow = LocalFrameWindowScope.current.window
    val density = LocalDensity.current

    Box(
        modifier = Modifier.pointerInput(awtWindow) {
            var startLocation = IntOffset.Zero
            var totalDrag = Offset.Zero
            detectDragGestures(
                onDragStart = {
                    val p = awtWindow.location
                    startLocation = IntOffset(p.x, p.y)
                    totalDrag = Offset.Zero
                },
                onDragEnd = { },
                onDragCancel = { }
            ) { change, dragAmount ->
                change.consume()
                totalDrag += dragAmount
                val newX = startLocation.x + totalDrag.x.roundToInt()
                val newY = startLocation.y + totalDrag.y.roundToInt()
                with(density) {
                    windowState.position = WindowPosition(newX.toDp(), newY.toDp())
                }
            }
        }
    ) {
        content()
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
    val windowX = AppSettingsStore.windowX
    val windowY = AppSettingsStore.windowY
    val position = if (!windowX.isNaN() && !windowY.isNaN()) {
        WindowPosition(windowX.dp, windowY.dp)
    } else {
        WindowPosition(Alignment.Center)
    }
    val state = rememberWindowState(
        position = position,
//        size = DpSize.Unspecified
        size = DpSize(AppSettingsStore.windowWidth.dp, AppSettingsStore.windowHeight.dp)
    )
    val title = "飞牛影视"
    val icon = painterResource(Res.drawable.icon)
    return Triple(state, title, icon)
}
